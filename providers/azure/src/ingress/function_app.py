"""Public v1 HTTP ingress for Azure Functions."""

from __future__ import annotations

import json
import os
from uuid import uuid4

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

from common.contract import ContractError, parse_order

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


def _send(body: str) -> None:
    client = ServiceBusClient(
        fully_qualified_namespace=os.environ["SERVICEBUS_CONNECTION__fullyQualifiedNamespace"],
        credential=DefaultAzureCredential(),
    )
    with client:
        with client.get_queue_sender("orders") as sender:
            sender.send_messages(ServiceBusMessage(body))


@app.route(route="orders", methods=["POST"])
def orders(req: func.HttpRequest) -> func.HttpResponse:
    try:
        payload = parse_order(req.get_body())
    except ContractError as exc:
        return func.HttpResponse(
            json.dumps({"status": "error", "message": str(exc)}),
            status_code=400,
            mimetype="application/json",
        )

    correlation_id = str(uuid4())
    body = json.dumps({"correlationId": correlation_id, "order": payload})
    try:
        _send(body)
    except Exception:
        return func.HttpResponse(
            json.dumps({"status": "error", "message": "message could not be queued"}),
            status_code=503,
            mimetype="application/json",
        )
    return func.HttpResponse(
        json.dumps({"status": "queued", "messageId": correlation_id}),
        status_code=202,
        mimetype="application/json",
    )
