# GCP Validation Record

## Scope

The development workload was deployed manually from the split Terraform
stacks under `envs/dev/bootstrap/` and `envs/dev/workload/`. Sensitive project,
billing, email, and image identifiers remain in ignored local configuration.

## Evidence

- Bootstrap plan: no changes after API, Artifact Registry, Firestore, service
  account, IAM, and budget setup.
- Workload plan: no changes after Cloud Run, Pub/Sub, DLQ, and Eventarc setup.
- Ingress accepted a valid JSON order with HTTP `202` and returned a message ID.
- Processor returned HTTP `204` to the Pub/Sub push subscription and created an
  order document in Firestore Native.
- Eventarc trigger used Firestore direct events with
  `application/protobuf` and `document` path-pattern matching.
- Notifier published a notification containing `orderId` and `eventId` to the
  notifications inspection subscription.
- Orders DLQ inspection subscription was empty after the successful test.
- Artifact Registry contained the three private runtime images; service
  accounts had no user-managed keys.
- Budget alerts and the Monitoring email notification channel were visible in
  the console.

## Operational boundary

Terraform `apply` and `destroy` remain manual architect operations. The
development environment should be torn down when it is not being tested to
avoid unnecessary charges.
