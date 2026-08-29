# Persisted sensitive-data inventory

**Reviewed:** 2026-08-04
**Scope:** Ash/PostgreSQL resources and authentication-extension tables.

This is the implementation inventory for application-level encryption. It is
not a claim that the listed values are encrypted today. PostgreSQL volume and
backup encryption protect lost media, but a database read, SQL injection, or
over-privileged database account can still see application plaintext.

`sensitive? true` and `public? false` are useful defence-in-depth: they keep
values out of normal Ash inspection and public field projections. They do not
change the database representation.

## Priority A — encrypt first

| Table/resource | Fields | Why | Migration constraint |
|---|---|---|---|
| `users` / `Accounts.User` | `totp_secret` | Reversible MFA seed permits generation of valid staff codes | Encrypt directly; rows are loaded by user id, so no index is needed |
| `merchant_identities` / `Accounts.MerchantIdentity` | `access_token`, `refresh_token` | Live third-party OAuth credentials | Extension-owned fields; verify custom Ash type compatibility before backfill |
| `outbound_webhooks` / `Webhooks.OutboundWebhook` | `secret` | HMAC signing credential | Encrypt directly; worker loads by webhook id |
| `device_tokens` / `Notifications.DeviceToken` | `token` | Durable FCM delivery credential | Equality/upsert uses the token; add a keyed HMAC blind-index column before encrypting |
| `store_payout_accounts` / `Stores.StorePayoutAccount` | `payout_destination`, `subaccount_code` | MoMo/bank destination and gateway account identifier | Encrypt map and code; reads are by `store_id` |
| `suppliers` / `Suppliers.Supplier` | `payment_details` | Free-form MoMo/bank instructions | Normalise keys before encryption so validation/redaction is deterministic |
| `partner_credit_offers` / `Suppliers.PartnerCreditOffer` | `creditor_subaccount_code` | Settlement destination | Encrypt directly; not used as an identity |
| `payment_splits` / `Payments.PaymentSplit` | `subaccount_code` | Settlement destination copied into the financial ledger | Encrypt directly; confirm reporting never filters on plaintext |
| `payouts` / `Payments.Payout` | `recipient_code`, `transfer_code`, `transfer_reference`, `gateway_response` | Transfer identifiers and raw provider data | `transfer_reference` is queried for webhook reconciliation; add a keyed HMAC blind index |
| `payments` / `Payments.Payment` | `gateway_response`; review `gateway_reference`, `split_code`, `metadata` | Provider data can contain payer/contact details and gateway identifiers | Keep searchable references as keyed blind indexes if encrypted |
| `store_verifications` / `Stores.StoreVerification` | `id_number`, `id_document_key`, `business_doc_key` | Government ID and private-object locators | Encrypt directly; reviewers load by store/id |

## Priority B — PII minimisation, retention, then encryption

| Data set | Representative fields | Recommendation |
|---|---|---|
| Account and customer identity | user/merchant/customer/invite/subscriber emails; merchant/customer/supplier phones | Define lookup needs first. Use normalised keyed blind indexes for login/search fields, ciphertext for display values, and retention/deletion rules |
| Delivery and address data | customer addresses; order `shipping_address`/`billing_address`; susu `delivery_address`; delivery-proof `sent_to` | Encrypt snapshots and structured addresses; retain only for the statutory/support window |
| Store and supplier contact data | store contact/address fields; supplier contact details | Storefront contact fields are intentionally publishable; encrypt only non-public operational copies and clearly label the exception |
| Notification history | `email_logs.to`, `subject`, `error`, `metadata`; notification metadata | Prefer data minimisation and short retention; do not persist message bodies |
| Security/session/audit telemetry | IP addresses, user agents, identifiers, `changes`/`metadata` maps | Apply purpose-specific schemas, payload allowlists, and retention. Encrypt identifiers that must remain reversible; otherwise pseudonymise with keyed HMAC |
| Webhook delivery history | `payload`, `response_body`, `error` | Redact at write time, cap retention, then encrypt the remaining diagnostic data |

## Already one-way or deliberately public

- Password hashes, phone-OTP hashes, platform-invite token hashes, and delivery
  proof code hashes should remain one-way hashes; do not make them decryptable.
- Ash authentication token tables contain JTIs, subjects, purposes, and expiry
  metadata rather than account passwords. Keep them access-restricted and prune
  expired rows.
- Pay-link, susu, and sales-share codes are bearer-style public links by design.
  Maintain high entropy and expiry/revocation where supported. If lookup secrecy
  is required later, use a keyed blind index rather than deterministic plaintext.
- Storefront contact fields are intentionally published by the merchant. That is
  a product contract, not a reason to expose the same PII in logs or unrelated
  resource projections.

## Required encryption design before a migration

1. Use authenticated encryption (AES-256-GCM or an equivalent audited primitive)
   with versioned ciphertext containing a key identifier.
2. Keep keys in the deployment secret manager, separate from database backups.
   Document emergency revocation and access ownership.
3. For equality lookups, store a separate keyed-HMAC blind index. Never use an
   unsalted plain hash for low-entropy phone numbers, emails, or account codes.
4. Roll out dual-read/new-write first, backfill in bounded batches, verify counts,
   then remove plaintext columns in a later deploy. Every step must be reversible.
5. Rotation must support old-key reads and new-key writes until a monitored
   re-encryption job completes. Test backup restore with the required key set.
6. Redact before persistence: encryption is not a licence to store unrestricted
   provider payloads, message content, or secrets in audit metadata.

No encryption dependency was added during this hardening pass. Selecting one is
a separate architecture decision because blind indexing, Ash type support,
rotation, and zero-downtime backfill must be proven together.
