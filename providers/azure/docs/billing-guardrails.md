# Billing Guardrails for the Azure Free-Trial Run

This is a proposed configuration only. It does not create a budget, alert,
resource, or billing change.

## Recommended budget

- Scope: the dedicated test subscription if available; otherwise the isolated
  resource group after it is created.
- Amount: **USD 25** for the short-lived experiment.
- Time grain: monthly.
- Notifications: the operator's billing email and an explicitly approved
  operational recipient.
- Thresholds: 50%, 80%, and 100% of the budget.

The amount is intentionally much lower than the USD 200 trial credit. It is an
early-warning threshold, not a spending cap. Azure budgets notify when actual
or forecast cost crosses a threshold; they do not stop deployments, suspend
resources, or prevent all charges.

## Free-account behavior

The Azure Free Account spending limit is separate from a budget. The spending
limit protects the trial credit and normally disables the subscription when
the credit is exhausted or expires. It must not be removed or converted to
pay-as-you-go for this experiment. Free-service quantities can still be
exceeded, and some marketplace or external charges may not be covered by the
credit.

## Operational procedure

1. Before any resource creation, confirm the trial credit, expiration date,
   spending-limit state, and billing notification recipient in the portal.
2. Create the budget only after explicit cloud-operation approval.
3. Treat a 50% notification as a pause-and-review event and an 80% notification
   as a teardown trigger unless the operator explicitly approves continuation.
4. At 100%, stop testing and tear down the resource group; do not upgrade the
   subscription to recover service.
5. Preserve sanitized alert evidence without storing subscription IDs or
   billing identifiers in the repository.

## Status

The budget was created and verified after explicit operator approval:

- Name: `orq003-azure-ephemeral`
- Amount: USD 25 monthly
- Period: 2026-07-01 through 2026-08-31 UTC
- Notifications: actual cost thresholds at 50%, 80%, and 100%
- Recipients: subscription `Owner` role contacts

No subscription ID, tenant ID, email address, or credential is stored here.
