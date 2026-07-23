---
name: spec-feature
description: Generates the Spec-Driven Development spec/plan/tasks cycle (specs/features/<name>/spec.md, plan.md, tasks.md) for a feature of the serverless-order-pipeline-aws project. Use when starting a new feature from the roadmap (e.g. "spec-feature core-pipeline").
---

# spec-feature

Generates the three SDD artifacts (`spec.md`, `plan.md`, `tasks.md`) for a
feature, in `specs/features/<name>/`. This project follows strict SDD:
**no infrastructure code is written until the architect (the user)
explicitly approves each of these three files.**

## How to invoke it

`args` is the feature name in kebab-case (e.g. `core-pipeline`,
`api-ingestion`, `diagrams`). If no name is given, ask the user which
roadmap feature this corresponds to.

## Procedure

1. **Load project context** before writing anything:
   - Read `specs/constitution.md` (mission, conventions) if it exists.
   - Read `specs/tech-stack.md` if it exists, for the exact version pins
     (Terraform, `hashicorp/aws` provider, runtime) `plan.md` must stay
     consistent with.
   - Read `specs/roadmap.md` if it exists, to locate this feature's entry
     and its high-level description.
   - If `specs/features/<name>/` already exists with non-empty files,
     warn the user and confirm before overwriting (don't clobber existing
     work without permission).

2. **Gather the feature's requirements.** The high-level description
   usually comes from the roadmap or from the user's instructions in the
   current conversation. If information needed to write verifiable
   acceptance criteria or architecture decisions is missing (e.g. it's
   unclear which AWS resources are involved, or there's a non-trivial
   design ambiguity) — **STOP and ask the user**, per the project's
   non-negotiable rule #8 ("if an instruction is ambiguous, STOP and
   ask"). Do not improvise architecture decisions.

3. **Generate `spec.md`** from
   `.claude/skills/spec-feature/templates/spec.md.template`: opens with a
   "Review summary" (≤10 lines: decisions needing approval, deviations
   from the baseline, key risks), then what and why, scope (in/out),
   functional requirements, verifiable acceptance criteria (avoid vague
   criteria — they must be checkable via `terraform plan`, inspecting a
   file, etc.).

4. **Generate `plan.md`** from
   `.claude/skills/spec-feature/templates/plan.md.template`: opens with a
   "Review summary" (same ≤10-line format as `spec.md`), then technical
   approach, a short list of files and their responsibilities (not an
   exhaustive resource-attribute table — the code is the source of truth
   for attributes; only call out non-obvious resources or naming
   decisions), ADRs with a single-line "Alternatives considered" each
   (mandatory to document any IAM least-privilege decision as an ADR, see
   rule #4), new variables/configuration, how it's validated (always
   `fmt` + `validate` + `plan`, never `apply` — note any manual-apply
   caveats, e.g. a resource that stays pending until a human completes a
   step Terraform can't), risks.

5. **Generate `tasks.md`** from
   `.claude/skills/spec-feature/templates/tasks.md.template`: checklist of
   atomic tasks (one per commit), each with its Definition of Done, plus a
   final section validating the complete feature.

6. **Report and STOP.** When done, summarize in 3-5 lines what was
   generated and explicitly request the architect's approval before any
   agent starts writing Terraform or Python code for this feature. Do not
   move to the `implement` phase without that explicit OK.

## Conventions to follow in generated content

- All content — spec/plan/tasks prose, diagram labels, code, code
  comments — is written in English (constitution §1/§3); commit messages
  are also in English, Conventional Commits format (rule #7).
- IAM: never propose `Resource: "*"`; always scope ARNs to the feature's
  resources (rule #4).
- `terraform apply` never appears as a task for the agent to run (rule
  #2) — at most, a task to "leave commands ready for the architect to
  apply manually".
- File names and structure: `envs/dev/` for the stack, `modules/` only
  when there's real, clear reuse — if the plan proposes a module, it must
  justify why inline resources in `envs/dev/` aren't enough.
- Keep `spec.md` and `plan.md` skimmable: the Review summary block is the
  only mandatory reading for a quick pass; move exhaustive detail (e.g.
  full resource-attribute tables) out of `plan.md` in favor of pointing
  at the code.
