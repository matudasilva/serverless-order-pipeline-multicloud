"""Provider-neutral Order Pipeline v1 validation helpers."""

from __future__ import annotations

import json
from typing import Any


class ContractError(ValueError):
    """Raised when an HTTP body does not satisfy contract v1."""


def parse_order(raw: str | bytes) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as exc:
        raise ContractError("body must be valid JSON") from exc
    if not isinstance(value, dict):
        raise ContractError("body must be a JSON object")
    item = value.get("item")
    quantity = value.get("quantity")
    if not isinstance(item, str) or not item.strip():
        raise ContractError("item must be a non-empty string")
    if len(item.strip()) > 256:
        raise ContractError("item must be at most 256 characters")
    if isinstance(quantity, bool) or not isinstance(quantity, int) or quantity <= 0:
        raise ContractError("quantity must be a positive integer")
    return value
