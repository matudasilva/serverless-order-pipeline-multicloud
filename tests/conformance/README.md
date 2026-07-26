# HTTP Conformance Runner

The runner exercises only the HTTP acceptance layer of Order Pipeline v1. It
does not prove persistence, notification, or DLQ/retry behavior; its evidence
marks those layers as `not_executed`.

List canonical cases without an endpoint:

```bash
python tests/conformance/runner.py --provider gcp --list
```

Inspect a sanitized run without sending requests:

```bash
python tests/conformance/runner.py --provider azure --endpoint https://example.invalid/orders --dry-run
```

Live execution is manual and never runs in CI. Evidence sanitizes the host and
never stores headers or environment variables. Write local evidence outside Git
or under an ignored `tests/conformance/evidence/` directory.
