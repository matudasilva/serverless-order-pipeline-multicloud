locals {
  tags = {
    project     = "serverless-order-pipeline-multicloud"
    provider    = "azure"
    environment = "dev"
    lifecycle   = "ephemeral-free-trial"
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

locals {
  storage_host_name = substr(replace("${var.name_prefix}host", "-", ""), 0, 24)
  deployment_containers = {
    ingress   = "deployment-ingress"
    processor = "deployment-processor"
    notifier  = "deployment-notifier"
  }
}

resource "azapi_resource" "storage_host" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = local.storage_host_name
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location
  body = {
    kind = "StorageV2"
    sku  = { name = "Standard_LRS" }
    properties = {
      allowBlobPublicAccess       = false
      allowCrossTenantReplication = false
      minimumTlsVersion           = "TLS1_2"
      supportsHttpsTrafficOnly    = true
    }
    tags = local.tags
  }
  response_export_values = ["*"]
}

resource "azapi_resource" "blob_service" {
  type                   = "Microsoft.Storage/storageAccounts/blobServices@2022-09-01"
  name                   = "default"
  parent_id              = azapi_resource.storage_host.id
  body                   = { properties = {} }
  response_export_values = ["*"]
}

resource "azapi_resource" "deployment" {
  for_each  = local.deployment_containers
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01"
  name      = each.value
  parent_id = azapi_resource.blob_service.id
  body = {
    properties = { publicAccess = "None" }
  }
  response_export_values = ["*"]
}

data "archive_file" "function_package" {
  for_each    = toset(["ingress", "processor", "notifier"])
  type        = "zip"
  output_path = "${path.module}/.terraform/${each.key}.zip"

  source {
    content  = file("${path.module}/../../src/${each.key}/function_app.py")
    filename = "function_app.py"
  }

  source {
    content  = file("${path.module}/../../src/${each.key}/host.json")
    filename = "host.json"
  }

  source {
    content  = file("${path.module}/../../src/${each.key}/requirements.txt")
    filename = "requirements.txt"
  }

  source {
    content  = file("${path.module}/../../src/common/__init__.py")
    filename = "common/__init__.py"
  }

  source {
    content  = file("${path.module}/../../src/common/contract.py")
    filename = "common/contract.py"
  }

  source {
    content  = file("${path.module}/../../src/common/idempotency.py")
    filename = "common/idempotency.py"
  }
}

resource "azurerm_servicebus_namespace" "this" {
  name                = "${var.name_prefix}sb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
  tags                = local.tags
}

resource "azurerm_servicebus_queue" "this" {
  for_each                             = toset(["orders", "notifications", "notification-failures"])
  name                                 = each.key
  namespace_id                         = azurerm_servicebus_namespace.this.id
  max_delivery_count                   = 5
  lock_duration                        = "PT1M"
  dead_lettering_on_message_expiration = true
}

/*
resource "azapi_resource" "storage_messaging" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = local.storage_messaging_name
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location
  body = {
    kind = "StorageV2"
    sku  = { name = "Standard_LRS" }
    properties = {
      allowBlobPublicAccess       = false
      allowCrossTenantReplication = false
      minimumTlsVersion           = "TLS1_2"
      supportsHttpsTrafficOnly    = true
    }
    tags = local.tags
  }
  response_export_values = ["*"]
}

resource "azapi_resource" "storage_queue" {
  for_each = {
    orders                = "orders"
    orders_poison         = "orders-poison"
    notifications         = "order-notifications"
    notification_failures = "notification-failures"
  }
  type                   = "Microsoft.Storage/storageAccounts/queueServices/queues@2022-09-01"
  name                   = "default/${each.value}"
  parent_id              = azapi_resource.storage_messaging.id
  body                   = { properties = {} }
  response_export_values = ["*"]
}
*/

resource "azurerm_log_analytics_workspace" "this" {
  name                         = "${var.name_prefix}-logs"
  location                     = azurerm_resource_group.this.location
  resource_group_name          = azurerm_resource_group.this.name
  sku                          = "PerGB2018"
  retention_in_days            = var.log_retention_days
  local_authentication_enabled = false
  tags                         = local.tags
}

resource "azurerm_application_insights" "this" {
  name                 = "${var.name_prefix}-insights"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  application_type     = "web"
  workspace_id         = azurerm_log_analytics_workspace.this.id
  retention_in_days    = var.log_retention_days
  daily_data_cap_in_gb = var.diagnostic_daily_cap_gb
  tags                 = local.tags
}

resource "azurerm_cosmosdb_account" "this" {
  name                = "${var.name_prefix}-cosmos"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  free_tier_enabled   = true
  geo_location {
    location          = azurerm_resource_group.this.location
    failover_priority = 0
    zone_redundant    = false
  }
  consistency_policy {
    consistency_level = "Session"
  }
  tags = local.tags
}

resource "azurerm_cosmosdb_sql_database" "this" {
  name                = "orders"
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                = "orders"
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/correlationId"]
}

resource "azurerm_cosmosdb_sql_container" "notifications" {
  name                = "notifications"
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/correlationId"]
}

resource "azurerm_cosmosdb_sql_container" "leases" {
  name                = "leases"
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/id"]
}

resource "azurerm_service_plan" "flex" {
  for_each            = toset(["ingress", "processor", "notifier"])
  name                = "${var.name_prefix}-${each.key}-flex"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  for_each                    = azurerm_service_plan.flex
  name                        = "${var.name_prefix}-${each.key}"
  resource_group_name         = azurerm_resource_group.this.name
  location                    = azurerm_resource_group.this.location
  service_plan_id             = each.value.id
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "https://${local.storage_host_name}.blob.core.windows.net/${local.deployment_containers[each.key]}"
  storage_authentication_type = "SystemAssignedIdentity"
  runtime_name                = "python"
  runtime_version             = "3.11"
  maximum_instance_count      = 40
  instance_memory_in_mb       = 2048
  app_settings = {
    AzureWebJobsStorage__accountName               = local.storage_host_name
    AzureWebJobsStorage__credential                = "managedidentity"
    SERVICEBUS_CONNECTION__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
    SERVICEBUS_CONNECTION__credential              = "managedidentity"
    COSMOS_ACCOUNT_URI                             = azurerm_cosmosdb_account.this.endpoint
    COSMOS_DATABASE_NAME                           = azurerm_cosmosdb_sql_database.this.name
    COSMOS_CONNECTION__accountEndpoint             = azurerm_cosmosdb_account.this.endpoint
    COSMOS_CONNECTION__credential                  = "managedidentity"
    APPLICATIONINSIGHTS_CONNECTION_STRING          = azurerm_application_insights.this.connection_string
    APPINSIGHTS_SAMPLING_PERCENTAGE                = "25"
  }
  site_config {}
  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    # AzureRM injects the legacy host-storage value with an empty key, while
    # Core Tools owns the deployment-storage value used by Flex publication.
    # Neither value is a repository-managed application setting.
    ignore_changes = [
      app_settings["AzureWebJobsStorage"],
      app_settings["DEPLOYMENT_STORAGE_CONNECTION_STRING"],
    ]
  }

  depends_on = [
    azapi_resource.storage_host,
    azapi_resource.deployment,
    azurerm_servicebus_namespace.this,
    azurerm_servicebus_queue.this,
  ]
  tags = local.tags
}

locals {
  function_names = toset(["ingress", "processor", "notifier"])
  function_principals = {
    for name, app in azurerm_function_app_flex_consumption.this : name => app.identity[0].principal_id
  }
}

resource "azurerm_role_assignment" "host_blob" {
  for_each             = local.function_names
  scope                = azapi_resource.storage_host.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = local.function_principals[each.key]
}

resource "azurerm_role_assignment" "host_queue" {
  for_each             = local.function_names
  scope                = azapi_resource.storage_host.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = local.function_principals[each.key]
}

resource "azurerm_role_assignment" "host_table" {
  for_each             = local.function_names
  scope                = azapi_resource.storage_host.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = local.function_principals[each.key]
}

resource "azurerm_role_assignment" "deployment_blob" {
  for_each             = local.function_names
  scope                = azapi_resource.deployment[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.function_principals[each.key]
}

resource "azurerm_role_assignment" "ingress_queue_sender" {
  scope                = azurerm_servicebus_queue.this["orders"].id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = local.function_principals["ingress"]
}

resource "azurerm_role_assignment" "processor_queue_reader" {
  scope                = azurerm_servicebus_queue.this["orders"].id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = local.function_principals["processor"]
}

resource "azurerm_role_assignment" "notifier_queue_sender" {
  scope                = azurerm_servicebus_queue.this["notifications"].id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = local.function_principals["notifier"]
}

resource "azurerm_role_assignment" "notifier_queue_reader" {
  scope                = azurerm_servicebus_queue.this["notifications"].id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = local.function_principals["notifier"]
}

resource "azurerm_role_assignment" "notifier_failure_sender" {
  scope                = azurerm_servicebus_queue.this["notification-failures"].id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = local.function_principals["notifier"]
}

resource "azapi_resource" "cosmos_metadata" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-05-15"
  name      = "11111111-1111-1111-1111-111111111111"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleName         = "${var.name_prefix}-cosmos-metadata"
      type             = "CustomRole"
      assignableScopes = [azurerm_cosmosdb_account.this.id]
      permissions      = [{ dataActions = ["Microsoft.DocumentDB/databaseAccounts/readMetadata"] }]
    }
  }
}

resource "azapi_resource" "cosmos_processor" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-05-15"
  name      = "22222222-2222-2222-2222-222222222222"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleName         = "${var.name_prefix}-cosmos-processor"
      type             = "CustomRole"
      assignableScopes = [replace(replace(azurerm_cosmosdb_sql_container.orders.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")]
      permissions = [{ dataActions = [
        "Microsoft.DocumentDB/databaseAccounts/readMetadata",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*",
      ] }]
    }
  }
}

resource "azapi_resource" "cosmos_notifier_orders" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-05-15"
  name      = "33333333-3333-3333-3333-333333333333"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleName         = "${var.name_prefix}-cosmos-notifier-orders"
      type             = "CustomRole"
      assignableScopes = [replace(replace(azurerm_cosmosdb_sql_container.orders.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")]
      permissions = [{ dataActions = [
        "Microsoft.DocumentDB/databaseAccounts/readMetadata",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/replace",
      ] }]
    }
  }
}

resource "azapi_resource" "cosmos_notifier_leases" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-05-15"
  name      = "44444444-4444-4444-4444-444444444444"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleName         = "${var.name_prefix}-cosmos-notifier-leases"
      type             = "CustomRole"
      assignableScopes = [replace(replace(azurerm_cosmosdb_sql_container.leases.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")]
      permissions = [{ dataActions = [
        "Microsoft.DocumentDB/databaseAccounts/readMetadata",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/create",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/replace",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/delete",
      ] }]
    }
  }
}

resource "azapi_resource" "cosmos_notifier_notifications" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-05-15"
  name      = "55555555-5555-5555-5555-555555555555"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleName         = "${var.name_prefix}-cosmos-notifications"
      type             = "CustomRole"
      assignableScopes = [replace(replace(azurerm_cosmosdb_sql_container.notifications.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")]
      permissions = [{ dataActions = [
        "Microsoft.DocumentDB/databaseAccounts/readMetadata",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/create",
        "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read",
      ] }]
    }
  }
}

resource "azapi_resource" "cosmos_metadata_assignment" {
  for_each  = local.function_names
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-05-15"
  name      = each.key == "ingress" ? "66666666-6666-6666-6666-666666666661" : each.key == "processor" ? "66666666-6666-6666-6666-666666666662" : "66666666-6666-6666-6666-666666666663"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleDefinitionId = azapi_resource.cosmos_metadata.id
      principalId      = local.function_principals[each.key]
      scope            = azurerm_cosmosdb_account.this.id
    }
  }
}

resource "azapi_resource" "cosmos_processor_assignment" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-05-15"
  name      = "77777777-7777-7777-7777-777777777777"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleDefinitionId = azapi_resource.cosmos_processor.id
      principalId      = local.function_principals["processor"]
      scope            = replace(replace(azurerm_cosmosdb_sql_container.orders.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")
    }
  }
}

resource "azapi_resource" "cosmos_notifier_orders_assignment" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-05-15"
  name      = "88888888-8888-8888-8888-888888888881"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleDefinitionId = azapi_resource.cosmos_notifier_orders.id
      principalId      = local.function_principals["notifier"]
      scope            = replace(replace(azurerm_cosmosdb_sql_container.orders.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")
    }
  }
}

resource "azapi_resource" "cosmos_notifier_leases_assignment" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-05-15"
  name      = "88888888-8888-8888-8888-888888888882"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleDefinitionId = azapi_resource.cosmos_notifier_leases.id
      principalId      = local.function_principals["notifier"]
      scope            = replace(replace(azurerm_cosmosdb_sql_container.leases.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")
    }
  }
}

resource "azapi_resource" "cosmos_notifier_notifications_assignment" {
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-05-15"
  name      = "88888888-8888-8888-8888-888888888883"
  parent_id = azurerm_cosmosdb_account.this.id
  body = {
    properties = {
      roleDefinitionId = azapi_resource.cosmos_notifier_notifications.id
      principalId      = local.function_principals["notifier"]
      scope            = replace(replace(azurerm_cosmosdb_sql_container.notifications.id, "/sqlDatabases/", "/dbs/"), "/containers/", "/colls/")
    }
  }
}
