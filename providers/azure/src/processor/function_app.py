"""Private Service Bus processor."""

from __future__ import annotations

import json
import os
from uuid import uuid4

import azure.functions as func
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from azure.cosmos.exceptions import CosmosHttpResponseError

from common.idempotency import order_documents

app = func.FunctionApp()


def _container():
    client = CosmosClient(os.environ["COSMOS_ACCOUNT_URI"], credential=DefaultAzureCredential())
    return client.get_database_client(os.environ["COSMOS_DATABASE_NAME"]).get_container_client("orders")


@app.service_bus_queue_trigger(arg_name="message", queue_name="orders", connection="SERVICEBUS_CONNECTION")
def process(message: func.ServiceBusMessage) -> None:
    envelope = json.loads(message.get_body().decode("utf-8"))
    correlation_id = envelope["correlationId"]
    order, outbox = order_documents(envelope["order"], correlation_id, str(uuid4()))
    container = _container()
    try:
        container.execute_item_batch(
            batch_operations=[
                ("create", (order,)),
                ("create", (outbox,)),
            ],
            partition_key=correlation_id,
        )
    except Exception as exc:
        if not isinstance(exc, CosmosHttpResponseError) or exc.status_code != 409:
            raise
        existing = container.read_item(item=order["id"], partition_key=correlation_id)
        if existing.get("correlationId") != correlation_id:
            raise
