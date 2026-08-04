# Codebase Remediation Plan

This plan turns the August 2026 codebase review into independently deployable,
reviewable changes. Security and financial correctness come first; broad UI
modernisation follows only after the production safety gates are in place.

## Working rules

- Each workstream is developed in its own Git worktree and committed separately.
- Never stash, reset, delete, or overwrite work that predates this remediation.
- Merchant-facing writes must use an authenticated actor and explicit tenant/store
  scope. `authorize?: false` is reserved for reviewed system boundaries.
- Every security or financial fix includes an adversarial or replay test.
- Migrations must be reversible, backfillable, and safe for rolling deployment.
- Generated assets and dependency caches are not committed.

## Phase 1 — Tenant and financial integrity

### Tenant isolation

- Replace unscoped category mutations with store-scoped actions.
- Validate that category parents belong to the same store.
- Add crafted cross-tenant delete, update, and relationship tests.
- Audit merchant-facing handlers that combine user-supplied IDs with
  `authorize?: false`, then establish an enforceable allowlist/guard.

### Refund reconciliation

- Define full- and partial-refund behavior for each order/fulfillment state.
- Reconcile payment and order state idempotently when a refund webhook arrives.
- Prevent a fully refunded, unfulfilled order from continuing fulfillment.
- Cover duplicate and concurrent webhook delivery.

## Phase 2 — Privacy and browser security

### PII and secrets

- Centralize phone/email masking and safe provider-error logging.
- Remove message bodies, full recipients, tokens, and provider payloads from logs.
- Classify sensitive persisted fields and remove public projections where unsafe.
- Encrypt authentication and financial secrets with a versioned, rotatable format;
  backfill existing rows without downtime.

### Content Security Policy

- Remove inline scripts and event-handler attributes from templates.
- Move platform sidebar behavior into the supported JavaScript bundle.
- Add browser console/CSP regression coverage for platform pages.

## Phase 3 — Delivery and production gates

### CI

- Restore meaningful Credo checks with narrowly documented exceptions.
- Build assets in CI and run Playwright against a seeded application.
- Measure and enforce a non-regressing coverage baseline.
- Run PDF rendering separately instead of excluding it globally.
- Keep Dialyzer PLTs reliably keyed to resolved OTP, Elixir, and dependency versions.

### Observability

- Either expose the metrics endpoint configured in `fly.toml` or remove the stale
  scrape configuration until an exporter exists.
- Configure structured, redacted production logs and verify Sentry delivery.
- Instrument HTTP, payment, webhook, Oban, and queue-health signals with alerts.

### Multi-node behavior

- Broadcast storefront cache invalidations through Phoenix PubSub.
- Use a shared rate-limit backend before horizontally scaling.
- Document and test the current single-node constraint and the scale-out path.

## Phase 4 — Maintainability and Phoenix 1.8 alignment

- Split `SupplyNetworkLive` into cohesive workflow surfaces and service modules.
- Remove compile-connected customer action/resource cycles.
- Migrate route groups to `Layouts.app`, `to_form/2`, `<.form>`, `<.input>`, and
  LiveView streams.
- Replace daisyUI usage with project-native Tailwind components, then remove the
  plugin after usage reaches zero.
- Self-host fonts and keep JavaScript/CSS within the supported application bundles.
- Replace the generated README and synchronize security, monitoring, deployment,
  and environment-variable documentation with executable configuration.

## Completion gates

- Cross-tenant mutation tests pass for every remediated surface.
- Refund replay/concurrency tests pass and order/fulfillment state remains coherent.
- Log-capture tests prove that representative PII and secrets never appear.
- CSP browser tests report no violations on public, merchant, and platform pages.
- Formatting, compilation, Credo, Sobelow, dependency audit, Dialyzer, unit tests,
  asset build, Playwright, coverage, and PDF smoke checks pass.
- The integration worktree is clean, and no unrelated branch or worktree is changed.
