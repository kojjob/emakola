# LAUNCH TODO — Setups Between Here and a Real Launch

> **State (2026-07-15):** https://makola.io is **LIVE** on the full main
> branch (v37, deployed 2026-07-14; migrations 72→107) — still on **dummy
> provider keys** (verified today: PAYSTACK_*, RESEND_API_KEY, SMS_API_KEY,
> WHATSAPP_* are all placeholders; STORE_SUBDOMAIN_BASE is already set). The
> database is NOT empty: besides the seeded demo stores, **five real merchant
> signups** exist (eunix-ventures, savero-fashion, taliored-by-two,
> bediides-outlet, dave-elec) — any purge must never touch them. This file
> tracks every remaining setup, in order.
> How-tos: `docs/PROVIDER_SETUP.md` (credentials, illustrated) ·
> `docs/DEPLOYMENT.md` (infra mechanics).
>
> **SEO roadmap** (built through Phase 5, ship-dark): remaining tasks in
> `docs/SEO_ROADMAP_FOLLOWUPS.md`; plain-English step-by-step how-tos (activation
> switches, backlinks/social, custom domains) in `docs/SEO_PLAYBOOK.md`.

---

## 🚀 Launch-critical — do in this order

- [ ] **1. Submit the 7 WhatsApp templates to Meta TODAY** — approval takes
      1–3 days and gates nothing else, so start it first. Exact names,
      `{{n}}` parameter order, and copy-paste bodies: `PROVIDER_SETUP.md` §4c (includes `supply_connection_update`).
- [ ] **2. Paystack** — account (country: **Ghana**) → test keys → webhook URL
      `https://emakola.fly.dev/webhooks/paystack` → enable the Mobile Money
      channel. (§1)
- [ ] **3. Resend** — API key; add + DNS-verify the sending domain for real
      delivery (sandbox only mails yourself). (§2)
- [ ] **4. Arkesel SMS** — request Sender ID `Emakola` (NCA approval <1 day)
      → API key → top up credits. The channel speaks Arkesel v2 natively:
      set `SMS_PROVIDER=arkesel` (api-key header + payload + endpoint all
      handled; `SMS_API_URL` becomes optional). Then ONE real test send to
      confirm credits/sender-ID. (§3)
- [ ] **5. WhatsApp credentials** — permanent **System User** token (the
      API-Setup page token expires in 24 h — don't ship it) + Phone Number ID.
      (§4a–4b)
- [ ] **6. Replace the dummy secrets** — one command with real values
      (template in `PROVIDER_SETUP.md` §7):
      `fly secrets set RESEND_API_KEY=… PAYSTACK_SECRET_KEY=… PAYSTACK_PUBLIC_KEY=… SMS_API_KEY=… WHATSAPP_API_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=… --app emakola`
- [x] **7. Decide store data: seed vs organic** — DECIDED (seeded 2026-06-11,
      and organic signups arrived on their own). Cleanup is now step 7b:
- [ ] **7b. Purge the demo/test stores** — `Emakola.Stores.DemoPurge` (PR #329)
      deletes a store's whole graph via runtime FK-closure, one transaction,
      images through Ash so bucket files get cleaned. Confirmed purge list:
      `kente-kingdom`, `accra-fresh`, `tiny-stitches` (all seeded orders and
      payments live here), `claude-test-store`, `subdomain-smoke-test`
      (ownerless). ⚠️ `savero` belongs to kojo@pricelysis.com — owner's call.
      Flow: deploy → `bin/emakola rpc "Emakola.Stores.DemoPurge.preview(...)"`
      → fresh volume snapshot → `execute(...)`. Also delete the three demo
      `users` rows (kwame@/adjoa@/efua@ — the `Password123!` accounts).
- [ ] **8. Smoke test with real keys** (`PROVIDER_SETUP.md` §8) —
      `/api/health` → register → onboard → test order (Paystack test card
      `4084 0840 8408 4081`) → order SMS + email arrive → product image
      upload (proves Tigris) → WhatsApp send once Meta approves.
- [ ] **9. Verify the revenue rails end-to-end** (the Phase-0 success metric;
      revenue engine shipped #206–#213). Sequence matters: in `/admin/payouts`
      **save MoMo payout details first** so `SubaccountCreationWorker` creates a
      verified Paystack subaccount — only then does a normal order split (merchant
      net to subaccount, **2%** fee kept in the platform account). With no verified
      subaccount the order falls back to `:none` (100% held, no fee). Then on
      `/platform/finance` approve a payout and confirm the Paystack **Transfer**
      fires (same `/webhooks/paystack` URL also receives `transfer.success/failed`).
      ⚠️ Paystack holds a **new subaccount's first payout** until it's verified in
      the Paystack dashboard.

## 🔑 Social login activation (optional, post-launch OK)

The OAuth stack is fully built and ships dark; the hijack guard (email
confirmation add-on, PR pending) is armed. To activate a provider, set its
secrets — the sign-in buttons appear automatically, nothing else to deploy:

- **Google**: `fly secrets set GOOGLE_CLIENT_ID=… GOOGLE_CLIENT_SECRET=… --app emakola`
  (console.cloud.google.com → OAuth client; authorized redirect
  `https://makola.io/oauth/merchant/google/callback` and
  `…/oauth/customer/google/callback`)
- **Facebook**: `FACEBOOK_CLIENT_ID` + `FACEBOOK_CLIENT_SECRET` (Meta app;
  same callback pattern with `facebook`). Endpoints/scopes in merchant.ex
  should be sanity-checked against the Meta app config during setup.
- **Apple**: `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`,
  `APPLE_PRIVATE_KEY_PATH` (needs the .p8 key ON DISK in the image — extra
  release plumbing; defer unless demanded).
- Redirect base derives from PHX_HOST automatically (`https://<host>/oauth`).

## 🌐 Before opening to the public

- [x] **Custom domain** — DONE 2026-06-20: makola.io is PHX_HOST, www + wss
      verified, STORE_SUBDOMAIN_BASE set. Original steps kept for reference:
      Cloudflare DNS (A/AAAA + `www` + `*` wildcard for
      merchant subdomains; **DNS-only/grey cloud first**) → `fly certs add
      emakola.com` and `'*.emakola.com'` → wait for **Ready** →
      `fly secrets set PHX_HOST=emakola.com` → optionally flip Cloudflare to
      Proxied. (§9)
- [ ] **Paystack live cutover** — after business verification. The code is
      mode-agnostic (no `sk_test` conditionals anywhere), and the webhook
      HMAC derives from the secret key, so the swap below re-keys signature
      verification by itself. In order:
      1. Live-mode dashboard: enable the **Mobile Money** channel and set the
         webhook URL to `https://makola.io/webhooks/paystack`. (The test-mode
         registration points at `emakola.fly.dev`, which still routes to the
         same app — but live should name the real host.)
      2. One command so both keys flip together (machines restart on set):
         `fly secrets set PAYSTACK_SECRET_KEY=sk_live_… PAYSTACK_PUBLIC_KEY=pk_live_…`
      3. ⚠️ **Test-mode subaccounts do not exist in live mode**, and
         `SubaccountCreationWorker` is an idempotent no-op once a code is
         saved — it will NOT self-heal after the swap. Check for poisoned rows:
         `SELECT store_id, subaccount_code FROM store_payout_accounts
         WHERE subaccount_code IS NOT NULL;`
         For each row: set `subaccount_code = NULL,
         verification_status = 'unverified'`, then have the merchant re-save
         their payout details at `/admin/payouts` — that enqueues the worker,
         which re-creates the subaccount under the live keys. Transfer
         recipients need nothing: they are built per-payout from the saved
         MoMo number. Just don't approve any payout row created pre-swap.
      4. Live smoke, in order: 1-cedi MoMo order on a real store →
         `charge.success` arrives (`fly logs`) → payment `:succeeded` and the
         split rows settle → `/admin/earnings` shows the accrual → approve a
         payout in `/platform/finance` → `transfer.success` → money on the
         phone. (Reminder from the smoke section above: Paystack holds a new
         subaccount's **first** payout until it's verified in the dashboard.)
      5. Rollback = swap the test keys back with the same command. Rows
         cleared in step 3 stay cleared; the worker recreates codes under
         whichever mode is active.
- [ ] **Purge demo credentials** — superseded by step **7b** above
      (`Emakola.Stores.DemoPurge`, PR #329).
- [ ] **Rotate Postgres credentials** — `fly postgres attach` echoes the DB
      password into terminal output; rotate if those transcripts are ever
      shared.
- [x] **GitHub branch protection** — repo Settings → Branches → `main` →
      ☑ *Require branches to be up to date before merging*. Five separate
      stranded-PR/semantic-merge incidents this cycle; one checkbox kills
      the whole class. *(Verified enabled 2026-08-05 via the API: `strict:
      true` + required check `Test`, now reported by the CI umbrella job.
      Cost: every merge invalidates other open PRs for a ~15-min re-run —
      merge stacked work in quick succession.)*
- [ ] **Click the PDF export once in prod** — ChromicPDF/Chromium ships in
      the image (on-demand spawn) but the `:pdf` tests are excluded from CI;
      verify the real button works.
- [ ] **Hubtel (optional second gateway)** — set `HUBTEL_CLIENT_ID`,
      `HUBTEL_CLIENT_SECRET` **and** `HUBTEL_WEBHOOK_ALLOWLIST` together
      (the webhook is IP-allowlisted and fails closed) — or leave all unset.
- [ ] **Monitoring** — Sentry is fully wired ship-dark (dep + Finch transport +
      LoggerHandler for crashes/error-level logs). Activate with
      `fly secrets set SENTRY_DSN=… --app emakola` (project DSN from sentry.io);
      unset = inert. Until then `fly logs` is the only window.
- [ ] **Verify `conn.remote_ip` reflects the real client IP behind the Fly
      proxy** — mobile API pre-auth rate limits key on it (10/min sign-in
      per IP). If it's the edge IP, all mobile clients share one bucket.

## 📱 Mobile push (FCM) — enables real-device delivery (PR #134)

The push pipeline (DeviceToken → Oban worker → FCM HTTP v1) is built and
mock-tested. It stays in **LogPush** (logs only, never sends) until two
secrets are set; `FCM_SERVICE_ACCOUNT_JSON` is the master switch
(`config/runtime.exs:204`, `lib/emakola/application.ex:46`). Full delivery
also needs a real device token, which only the Phase 1 Flutter client mints
— so Stage A below is verifiable now; Stage B waits on the app.

- [ ] **Create the Firebase project** — console.firebase.google.com →
      Add project (use a **work** Google account; this key can push to every
      user). The generated **Project ID** (e.g. `emakola-prod-a1b2c`, may
      carry a random suffix) is `FCM_PROJECT_ID`. Confirm **Cloud Messaging
      API (V1)** is Enabled (Project settings → Cloud Messaging); ignore the
      deprecated Legacy API.
- [ ] **Generate the service-account key** — Project settings → Service
      accounts → **Generate new private key** → downloads a JSON file with
      FCM-send perms baked in (no IAM fiddling). That whole file is
      `FCM_SERVICE_ACCOUNT_JSON`. ⚠️ Credential-grade — gitignore it; to
      revoke, delete the key in that tab and regenerate.
- [ ] **Set both secrets** — flatten the JSON to one line with `jq`
      (preserves the `private_key`'s `\n` escapes; a hand-edit mangles them
      and crashes boot via `Jason.decode!`):
      `fly secrets set FCM_PROJECT_ID=emakola-prod-a1b2c FCM_SERVICE_ACCOUNT_JSON="$(jq -c . path/to/service-account.json)" --app emakola`
      (set both together — `runtime.exs` does `System.fetch_env!("FCM_PROJECT_ID")` and boot fails fast if the JSON is present but the id is missing.)
- [ ] **Stage A — verify the credential now (no phone needed):** with the
      vars set, `iex -S mix` → `Goth.fetch(Emakola.Goth)` → `{:ok, %Goth.Token{}}`
      proves the OAuth2 handshake works. This isolates *your* job (valid
      creds) from Phase 1's (a real device token).
- [ ] **Stage B — end-to-end delivery (gated on Phase 1):** once the Flutter
      app registers an FCM token via `POST /api/v1/device_tokens`, placing an
      order fires `PushNotificationWorker` → `FcmPush` → the device. This is
      the deferred Phase 0 exit criterion.
- [ ] **iOS only, later:** FCM can't reach Apple's APNs alone — create an
      **APNs auth key (.p8)** in the Apple Developer account and upload it in
      the same Cloud Messaging tab. Not needed for the backend secrets above
      or for Android; a Phase 1 iOS prerequisite.

## 🧰 Engineering backlog (post-launch, rough priority)

- [ ] **Regenerate Ash resource snapshots** — `mix ash.codegen` is unusable
      (stale `priv/resource_snapshots/`); every migration is hand-written
      until one deliberate regeneration session fixes it.
- [ ] **Decommission the legacy User/Organisation auth path** — dead since
      the registration fix (#108); `resolve_user`'s `current_store: nil`
      stub is a trap.
- [x] **Cart re-architecture before scaling past 1 machine** — DONE:
      carts moved from node-local ETS to Postgres (`cart_items`);
      `fly scale count N` is now safe.
- [ ] **Design system sub-project 3** — DesignTokens/FontLoader across all
      14 themes; remaining ~17 admin pages join the consistency-test
      `@swept` list opportunistically.
- [ ] **Seed digital-downloads demo data** — feature works but has no demo
      data (same invisibility dropshipping had pre-Tiny-Stitches).
- [ ] **Low-stock duplicate-alert race** — pre-existing; concurrent
      checkouts can double-send the low-stock SMS.
- [ ] **Stripe merchant billing** — dormant scaffolding today (no SDK, no
      webhook route, no env reads — deliberately NOT in the setup guide).
      When subscription billing becomes a real feature: SDK + route +
      `STRIPE_*` secrets + its own PROVIDER_SETUP section.
- [ ] **Requester-side supply-invite throttle** (N/day per requesting store)
      before real SMS keys go live — hostile invites currently consume the
      victim store's SMS rate bucket.
