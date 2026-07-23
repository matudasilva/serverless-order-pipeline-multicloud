# Spec: diagrams

> Status: Approved and implemented.

## Review summary

- **Decisions needing approval**: shared style guide (palette, arrow
  convention, gate vs. automated-step coloring) proposed in `plan.md` —
  it's a new design choice with no prior precedent in this repo, flag if
  a different look is wanted.
- **Deviations from the baseline/original exercise**: none — this feature
  didn't exist in the original exercise; it's new documentation.
- **Key risks**: PNG/SVG export and README embedding are explicitly out
  of scope here (that's Phase 5's job per `specs/roadmap.md`) — this
  feature only produces the two `.excalidraw` source files.

## What

Two Excalidraw diagrams, in a single consistent visual style, documenting
this portfolio: (1) the solution architecture, and (2) the SDD +
Terraform workflow used to build it.

## Why

A reviewer should be able to understand the pipeline's shape and the
process that produced it without reading all of `specs/`. Diagrams are
called out explicitly in the project's success criterion ("see the
diagram without additional tools").

## Scope

- In scope:
  - `docs/diagrams/architecture.excalidraw` — solution architecture.
  - `docs/diagrams/sdd-terraform-workflow.excalidraw` — SDD + Terraform
    workflow with AI assistance.
  - A shared style guide (documented in `plan.md`) both diagrams follow:
    same color palette, font, and arrow convention.
  - Validating both files are well-formed Excalidraw JSON (openable in
    excalidraw.com / the VS Code Excalidraw extension).
- Out of scope:
  - PNG/SVG export and embedding either diagram in the README — that's
    Phase 5's job per `specs/roadmap.md`.
  - Any change to `envs/dev/` or `src/lambdas/` — this feature is
    documentation-only.

## Functional requirements

1. `architecture.excalidraw` shows, left to right:
   `Client → API Gateway → SQS → Lambda 1 → DynamoDB → Streams → Lambda 2
   → SNS → Email`, visually grouped into four layers — ingestion,
   processing, persistence, notification — with each arrow labeled by
   the event/action it represents (e.g. `POST /orders`, `SendMessage`,
   `PutItem`, `INSERT stream event`, `Publish`, `Email`).
2. `architecture.excalidraw` includes a legend noting the region
   (`us-east-1`) and a one-line least-privilege IAM note.
3. `sdd-terraform-workflow.excalidraw` shows two swimlanes, "Architect
   (human)" and "Coding agent (AI)", containing: the one-time setup
   (Constitution → Roadmap), the per-feature cycle (specify → plan →
   tasks → approval gate → implement → validate → review gate →
   replanning → next feature), and — visually separated from the agent
   loop — the manual `terraform apply` → verification → `destroy` steps.
4. `sdd-terraform-workflow.excalidraw` visually distinguishes human
   approval gates from automated agent steps, with a legend explaining
   the distinction.
5. Both diagrams use the same palette, font, and arrow style (documented
   in `plan.md`'s style guide) — no ad hoc color choices per diagram.

## Acceptance criteria (verifiable)

- [ ] Both `.excalidraw` files parse as valid JSON.
- [ ] Both files have the top-level structure Excalidraw expects:
      `type: "excalidraw"`, a `version`, an `elements` array, and an
      `appState` object.
- [ ] `architecture.excalidraw` contains labeled elements for all 8
      pipeline components listed in FR1, grouped into 4 visually distinct
      layer zones, and a legend text block with the region and IAM note.
- [ ] `sdd-terraform-workflow.excalidraw` contains 2 swimlane containers,
      the one-time setup steps, the full per-feature cycle (including at
      least one diamond/decision element for the approval gates), the
      manual `apply`/verify/`destroy` steps visually separated from the
      agent loop, and a legend distinguishing human gates from automated
      steps.
- [ ] Both files use identical hex values for equivalent semantic colors
      (per `plan.md`'s style guide) and the same `fontFamily` — no
      per-diagram deviation.
- [ ] Both files open without errors in excalidraw.com (or the VS Code
      Excalidraw extension) when manually checked.

## Open questions

None.
