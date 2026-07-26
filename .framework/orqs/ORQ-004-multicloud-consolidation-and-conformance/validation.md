# Validation — ORQ-004

## Executed checks

- `terraform fmt -check` passed for AWS, GCP bootstrap, GCP workload, and Azure.
- `terraform init -backend=false` and `terraform validate` passed for all four
  Terraform roots. Provider installation/reuse required registry network access;
  no backend or cloud resource was accessed.
- `python -m compileall -q providers/aws/src providers/gcp/src providers/azure/src tests/conformance` passed.
- `python -m pytest providers/azure/tests tests/conformance/tests -q` passed: 13 tests.
- Python YAML parsing accepted `.github/workflows/terraform.yml`.
- Internal Markdown link check passed.
- Local secret-pattern scan returned no credential, private-key, subscription,
  tenant, or storage-key value.
- `git diff --check` passed.

## Findings

- The local pytest environment emitted a third-party `pytest-asyncio`
  deprecation warning; all tests passed.
- Azure provides Excalidraw and PNG architecture assets but no SVG, unlike AWS
  and GCP. This remains a diagram-convention decision, not a broken reference.
