# Application-level encryption at rest

Last updated: 2026-08-04

This document is the operational truth for Emakola's application-level field
encryption. Disk and backup encryption remain required, but they do not replace
this control because a database export otherwise contains usable secrets.

## Implemented expand phase

The current release protects the following fields with encrypted shadow
columns:

| Plaintext compatibility column | Encrypted shadow | Read behavior |
|---|---|---|
| `users.totp_secret` | `users.totp_secret_encrypted` | Authenticate ciphertext; use compatibility value if absent or stale during rollout |
| `outbound_webhooks.secret` | `outbound_webhooks.secret_encrypted` | Authenticate ciphertext; use compatibility value if absent or stale during rollout |
| `device_tokens.token` | `device_tokens.token_encrypted` | Authenticate ciphertext; use compatibility value if absent or stale during rollout |

`device_tokens.token_blind_index` is a keyed HMAC-SHA256 equality index using a
separate keyring. The existing plaintext unique constraint remains authoritative
during this expand phase. The blind index must not be used as the sole identity
until the later contract release accounts for lookup-key rotation.

New application writes dual-write both representations. Runtime consumers
authenticate the encrypted shadow first and fail closed on an unknown key,
invalid envelope, wrong field context, or failed authentication tag. They never
fall back after cryptographic authentication fails. During the expand rollout,
an old node can legitimately rotate or clear a value without knowing about its
shadow. If the old and authenticated representations disagree, the compatibility
column remains authoritative until the post-rollout reconciliation task repairs
the shadow. The contract release removes that compatibility path.

The release RPC backfill runs outside migration transactions in bounded batches
and is safe to rerun because it selects only rows with missing protected values.
Compare-and-swap updates prevent stale selections from overwriting concurrent
writes. The reconciliation task scans with bounded keyset pages, repairs
old-node writes, and stops rather than overwriting any shadow that fails
authentication.

## Format and key configuration

Ciphertexts use AES-256-GCM with a fresh 96-bit nonce and a 128-bit tag:

```text
emkenc.v1.<key-id>.<base64url-nonce>.<base64url-ciphertext>.<base64url-tag>
```

The version, key id, logical field name, and row UUID are authenticated as
additional data. A ciphertext copied to another column or another record will
therefore fail authentication. Blind indexes omit the row UUID because they
must support equality lookup and use this form:

```text
emkidx.v1.<key-id>.<base64url-hmac-sha256>
```

Production fails at boot when any required variable is missing or malformed:

```text
FIELD_ENCRYPTION_ACTIVE_KEY_ID=2026_08
FIELD_ENCRYPTION_KEYS={"2026_08":"<base64 32-byte key>"}
FIELD_BLIND_INDEX_ACTIVE_KEY_ID=lookup_2026_08
FIELD_BLIND_INDEX_KEYS={"lookup_2026_08":"<different base64 32-byte key>"}
```

Store these variables in the production secret manager, separately from the
database and its backups. Do not put them in release configuration files,
database tables, logs, tickets, or source control. Security engineering owns
key generation and retirement; the on-call SRE owns rollout execution and
verification. Two-person review is required before an old key is removed.

## Rolling-deploy runbook

1. Generate independent random 32-byte encryption and blind-index keys. Add all
   four environment variables to every production runtime before deploying.
2. Deploy this expand release. The schema migration only adds nullable shadow
   columns; a separate no-transaction migration creates the device blind-index
   index with PostgreSQL's concurrent algorithm. Neither migration performs a
   row-by-row backfill or holds DDL locks for that work. Old nodes can continue
   to use the untouched compatibility columns while new nodes dual-write and
   prefer ciphertext.
3. Once the migrations are complete and a new release node is running, backfill
   existing values through the release RPC entrypoint:

   ```sh
   bin/emakola rpc 'Emakola.Release.backfill_field_encryption(500)'
   ```

   Run it again; it must report zero rows for every table. The batches execute
   outside the migration transaction so updates commit incrementally.
4. After all old nodes and old release-command processes have drained, reconcile
   any writes they made during the rollout:

   ```sh
   bin/emakola rpc 'Emakola.Release.reconcile_field_encryption(500)'
   ```

   Run it again; it must report zero reconciled rows for every table. Then
   verify that no eligible rows lack shadows:

   ```sql
   SELECT count(*) FROM users
   WHERE totp_secret IS NOT NULL AND totp_secret_encrypted IS NULL;

   SELECT count(*) FROM outbound_webhooks
   WHERE secret IS NOT NULL AND secret_encrypted IS NULL;

   SELECT count(*) FROM device_tokens
   WHERE token IS NOT NULL
     AND (token_encrypted IS NULL OR token_blind_index IS NULL);
   ```

   Every count must be zero. Treat decryption/authentication failures from
   workers or TOTP verification as a stop condition.
5. A later contract release must stop plaintext writes, move device equality
   and upsert behavior to the blind-index design, remove the old plaintext
   uniqueness dependency, and wipe/drop the three compatibility columns. That
   contract migration is intentionally not part of this release: combining it
   with the expand migration would break old nodes during a rolling deploy.

Until step 5 is deployed, these three legacy columns remain plaintext copies.
Do not describe the expand phase as plaintext removal.

## Encryption-key rotation

1. Add a new encryption key id and value to `FIELD_ENCRYPTION_KEYS` while
   retaining every old key. Change `FIELD_ENCRYPTION_ACTIVE_KEY_ID` to the new
   id and deploy it to every node.
2. After old nodes drain, run the release reconciliation RPC until it reports
   zero rows, then run:

   ```sh
   bin/emakola rpc 'Emakola.Release.reconcile_field_encryption(500)'
   bin/emakola rpc 'Emakola.Release.rotate_field_encryption(500)'
   ```

   The task decrypts with the envelope key id and writes a fresh envelope with
   the active key. It also rebuilds device blind indexes with their active key.
   It reports row counts only and does not log plaintext or key material.
3. Run the rotation task again, then run reconciliation again. Both must report
   zero rows for every table. This final reconciliation is defense in depth for
   a write that raced key rotation; compare-and-swap updates already prevent a
   stale selected value from overwriting that write. Verify there are no
   envelopes carrying the retiring key id and no decryption errors.
4. Remove the retired encryption key only after the verification and backup
   retention policy no longer requires it. A backup containing old ciphertext
   is unrecoverable without its old key, so archive retired keys according to
   the disaster-recovery retention policy rather than deleting them early.

Blind-index rotation changes equality values. While the plaintext compatibility
constraint remains, the task safely rebuilds them. After the contract release,
lookup-key rotation will require a dedicated dual-index procedure; do not rotate
or retire the blind-index key ad hoc.

## Exact residual scope

This production-safe tranche does **not** claim full database field coverage.
The following known sensitive persisted fields remain protected only by the
database volume/backup layer and require separate expand/backfill/contract work:

- extension-owned OAuth identity columns
  `merchant_identities.access_token` and `merchant_identities.refresh_token`;
- `store_payout_accounts.payout_destination` and `subaccount_code`;
- `suppliers.payment_details`;
- `partner_credit_offers.creditor_subaccount_code`;
- `payment_splits.subaccount_code`;
- `payouts.recipient_code`, `transfer_code`, `transfer_reference`, and
  `gateway_response` (the queried `transfer_reference` needs a blind index);
- `payments.gateway_response` pending payload classification;
- `store_verifications.id_number`, `id_document_key`, and `business_doc_key`;
- the broader customer, merchant, address, order, shipment, message, and audit
  PII inventory.

Provider credentials such as Paystack, Hubtel, WhatsApp, SMS, Firebase, S3, and
OAuth client secrets are runtime secret-manager values rather than database
fields. Their rotation follows the provider runbooks and does not use this
field-encryption format.
