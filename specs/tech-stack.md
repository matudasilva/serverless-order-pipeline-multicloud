# Technology Stack

> Single source of truth for stack versions and pins, referenced by
> `specs/constitution.md` §2. The `required_version` and provider version
> constraints declared here must match what `envs/dev/providers.tf` and
> the CI workflow actually declare. Constraints (cost, deferred apply,
> least privilege) live in the constitution, not here.

## Stack

| Component | Version / value | Notes |
|---|---|---|
| Terraform | `>= 1.9` | Consistent pin across `providers.tf` and CI. |
| AWS provider (`hashicorp/aws`) | `~> 5.x` | May be refined in a feature's plan if a narrower range is justified. |
| Archive provider (`hashicorp/archive`) | `~> 2.x` | Packages Lambda source into deployment zips (see `core-pipeline`'s plan, ADR-5). |
| Cloud | AWS, region `us-east-1` | Single region; no multi-region parameterization. |
| Lambda runtime | Python 3.12 | Upgraded from the original exercise's 3.9. |
| CI | GitHub Actions | Scope: `fmt -check` + `validate` only (see constitution §3, "CI"). |
