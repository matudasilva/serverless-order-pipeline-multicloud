#!/usr/bin/env python3
"""Run only the HTTP layer of the provider-neutral Order Pipeline v1 contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from models import Case, ConformanceError, validate_response

PROVIDERS = {"aws", "gcp", "azure"}


def load_cases(path: Path) -> list[Case]:
    try:
        source = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ConformanceError("cases file must be valid JSON") from exc
    if not isinstance(source, list):
        raise ConformanceError("cases file must contain a list")
    cases = []
    for item in source:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str) or item.get("expected") not in {"accepted", "invalid"}:
            raise ConformanceError("each case needs name and expected")
        if ("body" in item) == ("raw" in item):
            raise ConformanceError("each case needs exactly one of body or raw")
        cases.append(Case(name=item["name"], expected=item["expected"], body=item.get("body"), raw=item.get("raw")))
    return cases


def endpoint(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise argparse.ArgumentTypeError("endpoint must be an absolute http(s) URL")
    return value


def sanitized_endpoint(value: str) -> str:
    parsed = urlparse(value)
    digest = hashlib.sha256(parsed.netloc.encode()).hexdigest()[:12]
    return f"{parsed.scheme}://host-{digest}{parsed.path or '/'}"


def request_json(target: str, body: bytes, timeout: float) -> tuple[int, Any]:
    request = Request(target, data=body, method="POST", headers={"Content-Type": "application/json"})
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))
    except (URLError, TimeoutError) as exc:
        raise TimeoutError("HTTP request failed or timed out") from exc


def run_cases(provider: str, target: str, timeout: float, cases: list[Case], client: Callable[[str, bytes, float], tuple[int, Any]] = request_json) -> dict[str, Any]:
    if provider not in PROVIDERS:
        raise ConformanceError(f"unknown provider: {provider}")
    results = []
    for case in cases:
        body = case.raw.encode() if case.raw is not None else json.dumps(case.body).encode()
        try:
            status, response = client(target, body, timeout)
            validate_response(case, status, response)
            results.append({"name": case.name, "status": "passed", "httpStatus": status})
        except (ConformanceError, TimeoutError, ValueError) as exc:
            results.append({"name": case.name, "status": "failed", "reason": str(exc) or type(exc).__name__})
    overall = "passed" if all(result["status"] == "passed" for result in results) else "failed"
    return {"provider": provider, "contract": "order-pipeline-v1", "timestamp": datetime.now(timezone.utc).isoformat(), "endpoint": sanitized_endpoint(target), "http": {"status": overall, "cases": results}, "persistence": {"status": "not_executed"}, "notification": {"status": "not_executed"}, "dlq": {"status": "not_executed"}}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", required=True, choices=sorted(PROVIDERS))
    parser.add_argument("--endpoint", type=endpoint)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--cases", type=Path, default=Path(__file__).with_name("cases.json"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--list", action="store_true", dest="list_cases")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    try:
        cases = load_cases(args.cases)
        if args.list_cases:
            print("\n".join(case.name for case in cases))
            return 0
        if not args.endpoint:
            parser.error("--endpoint is required unless --list is used")
        if args.timeout <= 0:
            parser.error("--timeout must be positive")
        if args.dry_run:
            print(json.dumps({"provider": args.provider, "endpoint": sanitized_endpoint(args.endpoint), "cases": [case.name for case in cases]}))
            return 0
        evidence = run_cases(args.provider, args.endpoint, args.timeout, cases)
        rendered = json.dumps(evidence, indent=2) + "\n"
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered, encoding="utf-8")
        else:
            print(rendered, end="")
        return 0 if evidence["http"]["status"] == "passed" else 1
    except ConformanceError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
