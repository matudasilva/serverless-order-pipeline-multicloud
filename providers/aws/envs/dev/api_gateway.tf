resource "aws_api_gateway_rest_api" "poc_api" {
  name = "POC-API"
}

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  parent_id   = aws_api_gateway_rest_api.poc_api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "post_orders" {
  rest_api_id   = aws_api_gateway_rest_api.poc_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}

data "aws_iam_policy_document" "api_gateway_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_gateway_sqs" {
  name               = "poc-api-gateway-sqs-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume.json
}

data "aws_iam_policy_document" "api_gateway_sqs" {
  statement {
    sid       = "SendToPocQueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.poc_queue.arn]
  }
}

resource "aws_iam_role_policy" "api_gateway_sqs" {
  name   = "poc-api-gateway-sqs-policy"
  role   = aws_iam_role.api_gateway_sqs.id
  policy = data.aws_iam_policy_document.api_gateway_sqs.json
}

resource "aws_api_gateway_integration" "post_orders" {
  rest_api_id             = aws_api_gateway_rest_api.poc_api.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.post_orders.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  credentials             = aws_iam_role.api_gateway_sqs.arn
  uri                     = "arn:aws:apigateway:us-east-1:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.poc_queue.name}"
  passthrough_behavior    = "NEVER"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_method_response" "post_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "post_orders_400" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = "400"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "post_orders_500" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = "500"

  response_models = {
    "application/json" = "Empty"
  }
}

# ADR-8: the 200 response parses SQS's raw XML into JSON instead of
# passing it through, and — because 200 is now explicitly mapped — 400
# and 500 must be explicitly mapped too, or SQS errors would silently
# surface as 200 with an XML error body.
resource "aws_api_gateway_integration_response" "post_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = aws_api_gateway_method_response.post_orders_200.status_code

  selection_pattern = "2\\d{2}"

  response_templates = {
    "application/json" = <<-EOT
      {
        "messageId": "$util.parseXml($input.body).SendMessageResponse.SendMessageResult.MessageId",
        "status": "queued"
      }
    EOT
  }

  depends_on = [aws_api_gateway_integration.post_orders]
}

resource "aws_api_gateway_integration_response" "post_orders_400" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = aws_api_gateway_method_response.post_orders_400.status_code

  selection_pattern = "4\\d{2}"

  response_templates = {
    "application/json" = <<-EOT
      {
        "status": "error",
        "message": "The request could not be queued. Check the request body and try again."
      }
    EOT
  }

  depends_on = [aws_api_gateway_integration.post_orders]
}

resource "aws_api_gateway_integration_response" "post_orders_500" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.post_orders.http_method
  status_code = aws_api_gateway_method_response.post_orders_500.status_code

  selection_pattern = "5\\d{2}"

  response_templates = {
    "application/json" = <<-EOT
      {
        "status": "error",
        "message": "An unexpected error occurred while queueing the request."
      }
    EOT
  }

  depends_on = [aws_api_gateway_integration.post_orders]
}

resource "aws_api_gateway_deployment" "poc_api" {
  rest_api_id = aws_api_gateway_rest_api.poc_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.post_orders.id,
      aws_api_gateway_integration.post_orders.id,
      aws_iam_role_policy.api_gateway_sqs.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "/aws/apigateway/POC-API/dev-access-logs"
  retention_in_days = 14
}

# aws_api_gateway_account is account-scoped, not API-scoped: it sets the
# single IAM role API Gateway uses account-wide to write access/execution
# logs to CloudWatch. Confirmed via `aws apigateway get-account` that no
# cloudwatchRoleArn is currently set for this account, so applying this
# has no existing configuration to collide with.
data "aws_iam_policy_document" "api_gateway_cloudwatch_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name               = "poc-api-gateway-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_cloudwatch_assume.json
}

# Resource: "*" here is a forced exception to this project's least-
# privilege rule (#4), not a choice — AWS validates this account-level
# role at UpdateAccount time and rejects any policy scoped below
# Resource: "*" for these CloudWatch Logs actions, since the service
# must be able to create/write log groups dynamically for any API in
# the account. Confirmed by a real `terraform apply` failure with the
# log-group-scoped policy this project originally shipped. See ADR-10
# in plan.md.
data "aws_iam_policy_document" "api_gateway_cloudwatch" {
  statement {
    sid    = "WriteApiGatewayLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name   = "poc-api-gateway-cloudwatch-policy"
  role   = aws_iam_role.api_gateway_cloudwatch.id
  policy = data.aws_iam_policy_document.api_gateway_cloudwatch.json
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.poc_api.id
  deployment_id = aws_api_gateway_deployment.poc_api.id
  stage_name    = "dev"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  depends_on = [aws_api_gateway_account.this]
}
