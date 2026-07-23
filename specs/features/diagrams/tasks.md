# Tasks: diagrams

> Status: Approved and implemented.
> Depends on: `plan.md` of this feature (approved).
> Each task should result in an atomic commit (Conventional Commits, in
> English).

- [ ] T1 — Author `docs/diagrams/architecture.excalidraw`
  - **Definition of done**: valid Excalidraw JSON file containing the 4
    layer zones, 8 labeled pipeline components, labeled arrows, and the
    legend (region + IAM note), per `spec.md` FR1-FR2 and the style guide
    in `plan.md`. Parses with `python3 -m json.tool`.
- [ ] T2 — Author `docs/diagrams/sdd-terraform-workflow.excalidraw`
  - **Definition of done**: valid Excalidraw JSON file containing the 2
    swimlanes, one-time setup, full per-feature cycle with an approval
    gate diamond, the manual apply/verify/destroy sequence visually
    separated from the agent loop, and the gates-vs-automated legend, per
    `spec.md` FR3-FR4 and the style guide in `plan.md`. Parses with
    `python3 -m json.tool`.
- [ ] T3 — Manual open check (architect)
  - **Definition of done**: the architect opens both files in
    excalidraw.com (or the VS Code Excalidraw extension) and confirms
    they render without errors — this step can't be scripted from the
    agent's environment. Report back here (or just confirm in chat) so
    this task can be checked off.

## Feature final validation

- [ ] Both `.excalidraw` files parse as valid JSON.
- [ ] Both files share identical hex values for equivalent semantic
      colors and no per-element `fontFamily` override (style guide
      compliance, checked by inspection).
- [ ] Results summary presented to the architect for approval (STOP —
      wait for explicit OK before Phase 5).
