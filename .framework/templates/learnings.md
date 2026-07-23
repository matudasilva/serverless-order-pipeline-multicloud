# learnings.md — template

Repository-level learning source (V3 draft §14.2, level 1). Each entry is written by `fw-replan`
when an ORQ closes. Do not manually edit the cross-repository digest (it is a generated artifact;
see `framework/local-tools/fw_learnings_digest.py`), but an operator may edit this entry list to
correct or confirm `scope_confirmed`.

```yaml
- date: YYYY-MM-DD
  orq: ORQ-NN
  category: process        # process | technical | governance | tooling
  summary: "A short, concrete description of the learning."
  evidence: .framework/orqs/ORQ-NN/validation.md
  scope_proposed: project-only        # project-only | framework-candidate
  scope_confidence: medium            # low | medium | high
  scope_rationale: >
    Why fw-replan proposed this scope: recurrence, affected layer, invariant collision, or
    severity.
  scope_confirmed: null                # null until the operator confirms in batch
  authored_by:
    - agent: "Claude (model)"
      role: replan
```

## Fields

- `date` — date the originating ORQ closed.
- `orq` — ORQ identifier (`ORQ-NN`).
- `category` — one of `process`, `technical`, `governance`, or `tooling`.
- `summary` — a concrete sentence, not a generic one ("the design review without a reviewer
  distinct from the author missed X", not "improve the review process").
- `evidence` — path to the evidence artifact, normally `validation.md` from the source ORQ.
- `scope_proposed` / `scope_confidence` / `scope_rationale` — an assisted `fw-replan` proposal
  (V3 draft §14.5), never automatic.
- `scope_confirmed` — `null` until explicit operator confirmation; then `project-only` or
  `framework-candidate`. Only confirmed `framework-candidate` entries enter the cross-repository
  digest (V3 draft §14.2, level 2).
- `authored_by` — structured attribution populated by the Skill that generates the entry, not
  manually.
