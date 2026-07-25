"""Deterministic document identities shared by processor and sink."""

from __future__ import annotations


def order_id(correlation_id: str) -> str:
    return f"order:{correlation_id}"


def outbox_id(correlation_id: str) -> str:
    return f"notification:{correlation_id}"


def notification_id(correlation_id: str) -> str:
    return f"notification:{correlation_id}"


def order_documents(payload: dict, correlation_id: str, generated_order_id: str) -> tuple[dict, dict]:
    order = {
        "id": order_id(correlation_id),
        "correlationId": correlation_id,
        "orderId": generated_order_id,
        "item": payload["item"],
        "quantity": payload["quantity"],
        "kind": "order",
    }
    outbox = {
        "id": outbox_id(correlation_id),
        "correlationId": correlation_id,
        "kind": "notification-outbox",
        "status": "pending",
        "attemptCount": 0,
    }
    return order, outbox
