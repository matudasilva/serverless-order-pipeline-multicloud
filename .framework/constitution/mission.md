**Authorship:** Codex (GPT-5) through reverse engineering of the AWS baseline, repository, and adoption plan validated by Matías.
**Date:** 2026-07-23
**Version:** v1.0

# Mission — Serverless Order Pipeline Multicloud

## What it is

An educational and portfolio project that implements and compares the same serverless order pipeline on AWS, GCP, and Azure. AWS is the functional baseline; later implementations must preserve the shared logical flow while selecting native services that are equivalent by architectural responsibility.

## Who it is for

- Matías, the project architect responsible for decisions and manual cloud operations.
- Portfolio reviewers who want to compare the decisions, limitations, and trade-offs of an equivalent serverless pipeline across cloud providers.

## Why it exists

The project turns a completed AWS lab into an auditable multicloud comparison. It preserves the AWS baseline evidence and avoids assuming that similarly named services have the same responsibilities, semantics, or operating costs.

## Scope

**Includes:**

- A shared flow: HTTP ingress, decoupled messaging, serverless processing, NoSQL persistence, a post-persistence event, second processing, and notification.
- The AWS baseline implementation isolated under `providers/aws/`.
- Later design, implementation, and validation of GCP and Azure variants using Terraform and native services with equivalent responsibilities.
- Shared functional contracts, comparative documentation, observability, error handling, and dead-letter behavior.
- AI Together Framework V3 as the active governance system, with the repository as the canonical source and Notion as supplementary narrative planning.

**Excludes:**

- Converting the original AWS repository into a monorepo or modifying it.
- Agents running `terraform apply` or `terraform destroy`.
- Creating or modifying cloud resources without a manual operation by Matías.
- Implementing GCP or Azure before completing their explicit design and review.
- Storing credentials, secrets, or `terraform.tfvars` files in the repository.
