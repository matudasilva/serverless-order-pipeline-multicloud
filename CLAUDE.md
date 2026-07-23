# CLAUDE.md

Guidance for coding agents working in this repository.

## Language convention

Conversation with the architect (the user) can happen in Spanish or
English — respond in whichever language the architect uses.

However, ALL produced artifacts — framework records, docs, README,
diagram labels, code, code comments, and commit messages — are ALWAYS
written in English, regardless of the conversation's language.

This mirrors the English-only repository-content rule in the active
Framework constitution. Keep this file consistent with
`.framework/constitution/mission.md` and
`.framework/constitution/tech-stack.md`.

## Process

This project follows AI Together Framework V3 in hybrid mode. Consult
`.framework/constitution/` for the mission, constraints, and roadmap, and
use the Framework workflow for substantial changes. Agents never run
`terraform apply` or `terraform destroy`; ambiguous or material
architectural decisions require the architect's direction.
