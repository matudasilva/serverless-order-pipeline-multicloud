import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT))

from models import Case, ConformanceError, validate_response
from runner import endpoint, load_cases, run_cases, sanitized_endpoint


def test_cases_match_contract_names():
    assert [case.name for case in load_cases(ROOT / "cases.json")] == ["valid-minimal", "valid-typical", "invalid-missing-item", "invalid-blank-item", "invalid-quantity-zero", "invalid-quantity-type", "invalid-json"]


def test_response_validation_rejects_queued_error():
    with pytest.raises(ConformanceError):
        validate_response(Case("bad", "invalid", raw="{"), 400, {"status": "queued"})


def test_timeout_is_recorded():
    result = run_cases("gcp", "https://example.invalid/orders", 1, [Case("ok", "accepted", body={})], lambda *_: (_ for _ in ()).throw(TimeoutError()))
    assert result["http"]["status"] == "failed"
    assert result["http"]["cases"][0]["reason"]


def test_sanitizes_endpoint_and_rejects_invalid_endpoint():
    assert "secret.example" not in sanitized_endpoint("https://secret.example/orders")
    with pytest.raises(Exception):
        endpoint("not-a-url")


def test_unknown_provider_is_rejected():
    with pytest.raises(ConformanceError):
        run_cases("unknown", "https://example.invalid/orders", 1, [])


def test_malformed_cases_are_rejected(tmp_path):
    path = tmp_path / "cases.json"
    path.write_text(json.dumps([{"name": "bad", "expected": "invalid", "raw": "{", "body": {}}]))
    with pytest.raises(ConformanceError):
        load_cases(path)
