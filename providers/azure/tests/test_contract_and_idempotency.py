import json
import sys
from pathlib import Path

import pytest

SRC = Path(__file__).parents[1] / "src"
sys.path.insert(0, str(SRC))

from common.contract import ContractError, parse_order  # noqa: E402
from common.idempotency import notification_id, order_documents, order_id, outbox_id  # noqa: E402


@pytest.mark.parametrize(
    "body",
    [
        {"quantity": 1},
        {"item": "   ", "quantity": 1},
        {"item": "widget", "quantity": 0},
        {"item": "widget", "quantity": "3"},
    ],
)
def test_invalid_contract_payloads(body):
    with pytest.raises(ContractError):
        parse_order(json.dumps(body))


def test_valid_payload_preserves_additional_fields():
    payload = parse_order('{"item":"widget","quantity":3,"note":"kept"}')
    assert payload == {"item": "widget", "quantity": 3, "note": "kept"}


def test_document_ids_are_deterministic_and_same_partition():
    order, outbox = order_documents({"item": "widget", "quantity": 1}, "corr-1", "ord-1")
    assert order["id"] == order_id("corr-1")
    assert outbox["id"] == outbox_id("corr-1")
    assert order["correlationId"] == outbox["correlationId"] == "corr-1"
    assert notification_id("corr-1") == "notification:corr-1"


def test_invalid_json_is_rejected():
    with pytest.raises(ContractError):
        parse_order('{"item":')
