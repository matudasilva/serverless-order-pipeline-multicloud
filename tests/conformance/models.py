"""Types and response assertions for portable HTTP conformance."""

from dataclasses import dataclass
from typing import Any


class ConformanceError(ValueError):
    """Raised when a case, endpoint, or HTTP response is invalid."""


@dataclass(frozen=True)
class Case:
    name: str
    expected: str
    body: Any = None
    raw: str | None = None


def validate_response(case: Case, status: int, payload: Any) -> None:
    if not isinstance(payload, dict):
        raise ConformanceError("response body must be a JSON object")
    if case.expected == "accepted":
        if status != 202 or payload.get("status") != "queued" or not isinstance(payload.get("messageId"), str) or not payload["messageId"].strip():
            raise ConformanceError("accepted case requires 202, queued status, and a non-empty messageId")
        return
    if case.expected == "invalid":
        if status != 400 or payload.get("status") != "error" or payload.get("status") == "queued":
            raise ConformanceError("invalid case requires 400 and error status")
        return
    raise ConformanceError(f"unknown expected result: {case.expected}")
