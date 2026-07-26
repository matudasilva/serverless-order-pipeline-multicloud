# Implementation — ORQ-004

## Completed work

- Reconciled README and Constitution provider status, repository structure,
  non-goals, target terminology, and Azure roadmap state.
- Added non-mutating GCP CI validation for bootstrap and workload roots, plus
  provider and contract path filters.
- Added ADR 0001 for current local state and future isolated remote backends.
- Added evidence-based multicloud comparison documentation.
- Added the local-only HTTP conformance runner, canonical cases, tests, ignored
  evidence directory, and CI test job.
- Added ADR 0002. The architect selected explicit AWS partial conformance;
  AWS infrastructure and runtime behavior remain unchanged.
- Corrected the Azure preflight runtime record from Python 3.12 to Python 3.11
  to match Terraform.

## Deliberate exclusions

No cloud operations, real endpoint requests, Terraform plans, backend changes,
AWS ingress changes, or state migrations were performed.
