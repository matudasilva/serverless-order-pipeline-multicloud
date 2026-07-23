# CLAUDE.md

Guidance for coding agents working in this repository.

## Language convention

Conversation with the architect (the user) can happen in Spanish or
English — respond in whichever language the architect uses.

However, ALL produced artifacts — specs, plans, tasks, docs, README,
diagram labels, code, code comments, and commit messages — are ALWAYS
written in English, regardless of the conversation's language.

This mirrors the English-only rule for repository content set in
`specs/constitution.md` §1 and §3; this file operationalizes it for the
agent. Keep both consistent if either changes.

## Process

This project follows strict Spec-Driven Development. See
`specs/constitution.md` for the full rules — in particular: no
infrastructure code before `spec.md` and `plan.md` are approved, no
`terraform apply` by the agent, and STOP-and-ask on any ambiguous
instruction.
