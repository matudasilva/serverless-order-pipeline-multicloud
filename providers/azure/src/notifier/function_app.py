"""Cosmos Change Feed notifier, reconciler, and logical notification sink."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone

import azure.functions as func
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

app = func.FunctionApp()


def _database():
    client = CosmosClient(os.environ["COSMOS_ACCOUNT_URI"], credential=DefaultAzureCredential())
    return client.get_database_client(os.environ["COSMOS_DATABASE_NAME"])


def _send(name: str, body: str) -> None:
    client = ServiceBusClient(
        fully_qualified_namespace=os.environ["SERVICEBUS_CONNECTION__fullyQualifiedNamespace"],
        credential=DefaultAzureCredential(),
    )
    with client:
        with client.get_queue_sender(name) as sender:
            sender.send_messages(ServiceBusMessage(body))


def _record_failure(orders, current: dict, error: Exception) -> None:
    attempts = int(current.get("attemptCount", 0)) + 1
    current["attemptCount"] = attempts
    current["status"] = "failed" if attempts >= 5 else "pending"
    current["lastError"] = type(error).__name__
    if attempts >= 5:
        _send("notification-failures", json.dumps({
            "correlationId": current["correlationId"],
            "attemptCount": attempts,
        }))
    orders.replace_item(item=current["id"], body=current, etag=current.get("_etag"))


def _publish_outbox(document: dict) -> None:
    correlation_id = document["correlationId"]
    orders = _database().get_container_client("orders")
    current = orders.read_item(item=document["id"], partition_key=correlation_id)
    if current.get("status") not in {"pending", "dispatching"}:
        return
    current["status"] = "dispatching"
    current["leaseExpiresAt"] = datetime.now(timezone.utc).timestamp() + 120
    leased = orders.replace_item(item=current["id"], body=current, etag=current.get("_etag"))
    try:
        _send("notifications", json.dumps({"correlationId": correlation_id}))
    except Exception as exc:
        _record_failure(orders, leased, exc)
        return
    leased["status"] = "published"
    orders.replace_item(item=leased["id"], body=leased, etag=leased.get("_etag"))


@app.cosmos_db_trigger(
    arg_name="documents",
    container_name="orders",
    database_name="orders",
    lease_container_name="leases",
    create_lease_container_if_not_exists=False,
    connection="COSMOS_CONNECTION",
)
def change_feed(documents: func.DocumentList) -> None:
    for document in documents:
        value = document.to_dict()
        if value.get("kind") == "notification-outbox" and value.get("status") == "pending":
            _publish_outbox(value)


@app.timer_trigger(schedule="0 */2 * * * *", arg_name="timer", run_on_startup=False)
def reconcile(timer: func.TimerRequest) -> None:
    query = "SELECT * FROM c WHERE c.kind = 'notification-outbox'"
    for document in _database().get_container_client("orders").query_items(query=query, enable_cross_partition_query=True):
        if document.get("status") == "pending" or (
            document.get("status") == "dispatching"
            and float(document.get("leaseExpiresAt", 0)) < datetime.now(timezone.utc).timestamp()
        ):
            _publish_outbox(document)


@app.service_bus_queue_trigger(arg_name="message", queue_name="notifications", connection="SERVICEBUS_CONNECTION")
def notification_sink(message: func.ServiceBusMessage) -> None:
    value = json.loads(message.get_body().decode("utf-8"))
    correlation_id = value["correlationId"]
    notifications = _database().get_container_client("notifications")
    record = {"id": f"notification:{correlation_id}", "correlationId": correlation_id, "kind": "notification"}
    try:
        notifications.create_item(record)
    except Exception as exc:
        if getattr(exc, "status_code", None) != 409:
            raise
