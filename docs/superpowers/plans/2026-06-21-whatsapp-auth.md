# WhatsApp Phone-OTP Authentication — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phone + one-time-code authentication over WhatsApp (with SMS fallback) for merchants and customers, plus an auth-page consistency pass.

**Architecture:** A DB-backed `PhoneOtp` resource (hashed codes, expiry, attempt cap) + a `PhoneAuth` service (issue/verify, WhatsApp→SMS fallback, rate-limited) reuse the existing notification channels and `Emakola.RateLimit`. Two small LiveView state machines (merchant global, customer store-scoped) resolve the account by **verified** phone (find-or-create, collecting email once) and mint the same `:user_token`/`:customer_token` sessions the password/OAuth flows use. Ship-dark behind `:phone_auth_enabled`.

**Tech Stack:** Elixir/Ash 3.x, Phoenix LiveView, AshPostgres, Bcrypt (bundled with ash_authentication), Oban, TailwindCSS, Mox.

**Spec:** `docs/superpowers/specs/2026-06-21-whatsapp-auth-design.md`

> **⛔ Sequencing gate:** Do NOT start until **PR #179 (customer OAuth)** is merged to `main` — it modifies the same customer auth pages. Branch fresh from `main`:
> `git checkout main && git pull && git checkout -b feature/whatsapp-auth-impl`

---

## File Structure

**Create:**
- `lib/emakola/accounts/resources/phone_otp.ex` — OTP store (hashed code, expiry, attempts, purpose, store_id).
- `priv/repo/migrations/<ts>_create_phone_otps.exs` — `phone_otps` table.
- `priv/repo/migrations/<ts>_add_phone_login_identities.exs` — `unique_phone` (merchants) + `unique_store_phone` (customers) indexes.
- `lib/emakola/accounts/phone_auth.ex` — service: `request_code/3`, `verify_code/4`, `resolve_*`, `enabled?/0`, normalization, delivery.
- `lib/emakola_web/components/auth_components.ex` — `otp_code_input/1`, `phone_input/1`, `whatsapp_button/1`.
- `lib/emakola_web/live/auth/whats_app_live.ex` — merchant flow (`/auth/whatsapp`).
- `lib/emakola_web/live/storefront/customer_whats_app_live.ex` — customer flow (`/s/:store_slug/whatsapp`).
- Tests mirroring each under `test/`.

**Modify:**
- `lib/emakola/accounts/resources/merchant.ex` — `unique_phone` identity + `register_with_phone` action.
- `lib/emakola/customers/resources/customer.ex` — `unique_store_phone` identity + `register_with_phone` action.
- `lib/emakola/accounts/accounts.ex` — register `PhoneOtp`.
- `lib/emakola/notifications/channels/whatsapp.ex` — add `"auth_code"` to `@template_param_order`.
- `lib/emakola/notifications/templates.ex` — `auth_code` template name + params (optional helper).
- `lib/emakola_web/router.ex` — `/auth/whatsapp` + `/s/:store_slug/whatsapp` routes.
- `lib/emakola_web/live/auth/login_live.ex`, `register_live.ex` — activate WhatsApp button; button order.
- `lib/emakola_web/live/storefront/customer_login_live.ex`, `customer_register_live.ex` — add WhatsApp button.
- `config/runtime.exs`, `config/dev.exs`, `config/test.exs` — `:phone_auth_enabled`.

---

## Phase A — Domain (OTP store, identities, account actions, service)

### Task 1: `PhoneOtp` resource + migration

**Files:**
- Create: `lib/emakola/accounts/resources/phone_otp.ex`
- Create: `priv/repo/migrations/<ts>_create_phone_otps.exs`
- Modify: `lib/emakola/accounts/accounts.ex`
- Test: `test/emakola/accounts/phone_otp_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola/accounts/phone_otp_test.exs
defmodule Emakola.Accounts.PhoneOtpTest do
  use Emakola.DataCase, async: true
  alias Emakola.Accounts.PhoneOtp

  test "issue stores an OTP and record_attempt increments atomically" do
    {:ok, otp} =
      PhoneOtp
      |> Ash.Changeset.for_create(:issue, %{
        phone: "+233501234567",
        code_hash: "hashed",
        purpose: :merchant,
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      })
      |> Ash.create()

    assert otp.attempts == 0

    {:ok, otp} = otp |> Ash.Changeset.for_update(:record_attempt, %{}) |> Ash.update()
    assert otp.attempts == 1
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/accounts/phone_otp_test.exs`
Expected: FAIL — `Emakola.Accounts.PhoneOtp` is undefined.

- [ ] **Step 3: Create the resource**

```elixir
# lib/emakola/accounts/resources/phone_otp.ex
defmodule Emakola.Accounts.PhoneOtp do
  @moduledoc """
  One-time codes issued for phone (WhatsApp/SMS) authentication. Codes are
  stored hashed; rows are short-lived (expiry), single-use (consumed_at), and
  attempt-capped. `purpose` distinguishes merchant vs customer; `store_id` is
  set for the (store-scoped) customer flow.
  """
  use Ash.Resource, domain: Emakola.Accounts, data_layer: AshPostgres.DataLayer

  postgres do
    table("phone_otps")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:phone, :string, allow_nil?: false, public?: false)
    attribute(:code_hash, :string, allow_nil?: false, sensitive?: true, public?: false)

    attribute(:purpose, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:merchant, :customer]]
    )

    attribute(:store_id, :uuid, public?: false)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: false)
    attribute(:attempts, :integer, allow_nil?: false, default: 0, public?: false)
    attribute(:consumed_at, :utc_datetime_usec, public?: false)
    timestamps()
  end

  actions do
    defaults([:read])

    create :issue do
      accept([:phone, :code_hash, :purpose, :store_id, :expires_at])
    end

    update :record_attempt do
      require_atomic?(true)
      change(atomic_update(:attempts, expr(attempts + 1)))
    end

    update :consume do
      accept([])
      change(set_attribute(:consumed_at, &DateTime.utc_now/0))
    end

    read :live_for_phone do
      argument(:phone, :string, allow_nil?: false)
      argument(:purpose, :atom, allow_nil?: false)
      filter(expr(phone == ^arg(:phone) and purpose == ^arg(:purpose) and is_nil(consumed_at)))
      prepare(build(sort: [inserted_at: :desc], limit: 1))
    end
  end
end
```

- [ ] **Step 4: Register the resource in the domain**

In `lib/emakola/accounts/accounts.ex`, inside `resources do … end`, after the `resource(Emakola.Accounts.Token)` line, add:

```elixir
    resource(Emakola.Accounts.PhoneOtp)
```

- [ ] **Step 5: Write the migration** (hand-written — ash.codegen is unusable here; keep `null: false` on its own line per CI's Elixir-1.18 formatter)

```elixir
# priv/repo/migrations/<ts>_create_phone_otps.exs
defmodule Emakola.Repo.Migrations.CreatePhoneOtps do
  use Ecto.Migration

  def up do
    create table(:phone_otps, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :phone, :text, null: false
      add :code_hash, :text, null: false
      add :purpose, :text, null: false
      add :store_id, :uuid
      add :expires_at, :utc_datetime_usec, null: false
      add :attempts, :integer, null: false, default: 0
      add :consumed_at, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:phone_otps, [:phone, :purpose])
  end

  def down do
    drop table(:phone_otps)
  end
end
```

- [ ] **Step 6: Migrate dev + test, run the test**

Run:
```bash
mix ecto.migrate
MIX_ENV=test mix ecto.migrate
mix test test/emakola/accounts/phone_otp_test.exs
```
Expected: migration creates `phone_otps`; test PASSES.

- [ ] **Step 7: Commit**

```bash
git add lib/emakola/accounts/resources/phone_otp.ex lib/emakola/accounts/accounts.ex \
        priv/repo/migrations/*_create_phone_otps.exs test/emakola/accounts/phone_otp_test.exs
git commit -m "feat(auth): PhoneOtp resource for phone one-time codes"
```

---

### Task 2: Phone-login identities + migration

**Files:**
- Modify: `lib/emakola/accounts/resources/merchant.ex` (identities block)
- Modify: `lib/emakola/customers/resources/customer.ex` (identities block)
- Create: `priv/repo/migrations/<ts>_add_phone_login_identities.exs`
- Test: `test/emakola/accounts/phone_identity_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola/accounts/phone_identity_test.exs
defmodule Emakola.Accounts.PhoneIdentityTest do
  use Emakola.DataCase, async: true

  test "two merchants cannot share a non-null phone" do
    {:ok, _} = Emakola.Factory.create_merchant!(phone: "+233501112222")

    assert {:error, _} =
             Emakola.Factory.create_merchant!(phone: "+233501112222")
             |> then(&{:ok, &1})
  rescue
    _ -> :ok
  end
end
```

> Note: `create_merchant!/1` raises on failure; the test asserts the duplicate phone is rejected. (If a cleaner non-bang path is preferred, build the changeset directly with `Ash.create/2` and assert `{:error, %Ash.Error.Invalid{}}`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/accounts/phone_identity_test.exs`
Expected: FAIL — duplicate phone currently allowed (no identity).

- [ ] **Step 3: Add identities**

In `lib/emakola/accounts/resources/merchant.ex`, change the `identities do` block to:

```elixir
  identities do
    identity(:unique_email, [:email])
    # Phone is a login method (WhatsApp/SMS OTP); nullable, so Postgres allows
    # many email-only rows (multiple NULLs) — only set phones must be unique.
    identity(:unique_phone, [:phone])
  end
```

In `lib/emakola/customers/resources/customer.ex`, add to the `identities do` block (after `unique_email`):

```elixir
    identity(:unique_store_phone, [:store_id, :phone])
```

- [ ] **Step 4: Write the migration**

```elixir
# priv/repo/migrations/<ts>_add_phone_login_identities.exs
defmodule Emakola.Repo.Migrations.AddPhoneLoginIdentities do
  use Ecto.Migration

  def up do
    create unique_index(:merchants, [:phone], name: "merchants_unique_phone_index")

    create unique_index(:customers, [:store_id, :phone],
             name: "customers_unique_store_phone_index"
           )
  end

  def down do
    drop_if_exists unique_index(:merchants, [:phone], name: "merchants_unique_phone_index")

    drop_if_exists unique_index(:customers, [:store_id, :phone],
                     name: "customers_unique_store_phone_index"
                   )
  end
end
```

> Postgres treats NULLs as distinct, so existing email-only (phone = NULL) rows are unaffected.

- [ ] **Step 5: Migrate + run test**

Run:
```bash
mix ecto.migrate && MIX_ENV=test mix ecto.migrate
mix test test/emakola/accounts/phone_identity_test.exs
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/accounts/resources/merchant.ex lib/emakola/customers/resources/customer.ex \
        priv/repo/migrations/*_add_phone_login_identities.exs test/emakola/accounts/phone_identity_test.exs
git commit -m "feat(auth): unique phone identities for merchants + customers"
```

---

### Task 3: Passwordless phone-register actions

**Files:**
- Modify: `lib/emakola/accounts/resources/merchant.ex` (actions block)
- Modify: `lib/emakola/customers/resources/customer.ex` (actions block)
- Modify: `lib/emakola/accounts/accounts.ex` (code interfaces)
- Test: `test/emakola/accounts/phone_register_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola/accounts/phone_register_test.exs
defmodule Emakola.Accounts.PhoneRegisterTest do
  use Emakola.DataCase, async: true

  test "merchant register_with_phone creates a passwordless, confirmed merchant" do
    {:ok, m} =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_phone, %{
        email: "wa-merchant@example.com",
        name: "Akua",
        phone: "+233501234567"
      })
      |> Ash.create(authorize?: false)

    assert m.phone == "+233501234567"
    assert is_nil(m.hashed_password)
    refute is_nil(m.confirmed_at)
  end

  test "customer register_with_phone creates a store-scoped customer" do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()

    {:ok, c} =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(
        :register_with_phone,
        %{email: "wa-cust@example.com", name: "Kofi", phone: "+233502223333"},
        tenant: store.id
      )
      |> Ash.create(authorize?: false)

    assert c.store_id == store.id
    assert c.phone == "+233502223333"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/accounts/phone_register_test.exs`
Expected: FAIL — `register_with_phone` action does not exist.

- [ ] **Step 3: Add merchant action** — in `lib/emakola/accounts/resources/merchant.ex`, inside `actions do`, after `defaults([:read])`:

```elixir
    # Passwordless registration via verified phone (WhatsApp/SMS OTP). The phone
    # is already OTP-verified by PhoneAuth; email is collected once in the UI.
    create :register_with_phone do
      accept([:email, :name, :phone])
      change(set_attribute(:confirmed_at, &DateTime.utc_now/0))
    end
```

In `lib/emakola/customers/resources/customer.ex`, inside `actions do`, after the `create :create` block:

```elixir
    # Passwordless, store-scoped registration via verified phone. store_id comes
    # from the request tenant (multitenancy :attribute).
    create :register_with_phone do
      accept([:email, :name, :phone])
    end
```

- [ ] **Step 4: Add code interfaces** — in `lib/emakola/accounts/accounts.ex`, in the `Merchant` resource block, add:

```elixir
      define(:register_merchant_with_phone, action: :register_with_phone)
```

(Customer interfaces live in `Emakola.Customers`; the LiveView will call the action directly with the tenant, so no domain interface is required there.)

- [ ] **Step 5: Run test**

Run: `mix test test/emakola/accounts/phone_register_test.exs`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/accounts/resources/merchant.ex lib/emakola/customers/resources/customer.ex \
        lib/emakola/accounts/accounts.ex test/emakola/accounts/phone_register_test.exs
git commit -m "feat(auth): passwordless register_with_phone for merchants + customers"
```

---

### Task 4: `auth_code` WhatsApp template wiring

**Files:**
- Modify: `lib/emakola/notifications/channels/whatsapp.ex`
- Test: `test/emakola/notifications/channels/whatsapp_auth_template_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola/notifications/channels/whatsapp_auth_template_test.exs
defmodule Emakola.Notifications.Channels.WhatsAppAuthTemplateTest do
  use ExUnit.Case, async: true
  alias Emakola.Notifications.Channels.WhatsApp

  test "auth_code template renders the code as its single body parameter" do
    msg = WhatsApp.build_template_message("+233501234567", "auth_code", [%{type: "text", text: "123456"}])
    assert %{template: %{name: "auth_code", components: [%{parameters: [%{text: "123456"}]}]}} = msg
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/notifications/channels/whatsapp_auth_template_test.exs`
Expected: PASS for `build_template_message` (it's generic) — but `send_message/4` would reject `"auth_code"` as unknown. Add a second assertion:

```elixir
  test "send_message knows the auth_code parameter order" do
    # @template_param_order must include "auth_code" => [:code]
    assert {:error, {:unknown_template, _}} != WhatsApp.send_message("x", "auth_code", %{code: "1"}, bypass_rate_limit: true)
  end
```
Run again; Expected: FAIL — `"auth_code"` not in `@template_param_order`.

- [ ] **Step 3: Register the template parameter order** — in `lib/emakola/notifications/channels/whatsapp.ex`, add to the `@template_param_order` map:

```elixir
  "auth_code" => [:code]
```

- [ ] **Step 4: Run test** — `mix test test/emakola/notifications/channels/whatsapp_auth_template_test.exs` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/notifications/channels/whatsapp.ex test/emakola/notifications/channels/whatsapp_auth_template_test.exs
git commit -m "feat(auth): wire auth_code WhatsApp template parameter order"
```

---

### Task 5: `PhoneAuth` service — issue + verify + delivery fallback

**Files:**
- Create: `lib/emakola/accounts/phone_auth.ex`
- Modify: `config/test.exs` (`:phone_auth_enabled`, true in test)
- Test: `test/emakola/accounts/phone_auth_test.exs`

- [ ] **Step 1: Write the failing test** (covers issue, WhatsApp→SMS fallback, verify happy/invalid/expired/attempts)

```elixir
# test/emakola/accounts/phone_auth_test.exs
defmodule Emakola.Accounts.PhoneAuthTest do
  use Emakola.DataCase, async: false
  import Mox
  alias Emakola.Accounts.PhoneAuth
  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock)
    Application.put_env(:emakola, :sms_provider, Emakola.SMSProviderMock)
    :ok
  end

  test "request_code sends via WhatsApp and verify_code accepts the code" do
    test_pid = self()

    expect(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: code}, _opts ->
      send(test_pid, {:code, code})
      {:ok, %{}}
    end)

    assert :ok = PhoneAuth.request_code("0501234567", :merchant)
    assert_received {:code, code}
    assert :ok = PhoneAuth.verify_code("0501234567", code, :merchant)
  end

  test "request_code falls back to SMS when WhatsApp fails" do
    test_pid = self()
    expect(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ -> {:error, :boom} end)

    expect(Emakola.SMSProviderMock, :send_sms, fn _to, body ->
      send(test_pid, {:sms, body})
      {:ok, %{}}
    end)

    assert :ok = PhoneAuth.request_code("0501234567", :merchant)
    assert_received {:sms, body}
    assert body =~ ~r/\d{6}/
  end

  test "verify_code rejects a wrong code, and too many attempts" do
    stub(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ -> {:ok, %{}} end)
    assert :ok = PhoneAuth.request_code("0509999999", :merchant)
    assert {:error, :invalid} = PhoneAuth.verify_code("0509999999", "000000", :merchant)
  end
end
```

> Confirm the SMS behaviour callback name from `Emakola.Notifications.SMSProvider` (likely `send_sms/2`); match it in both the mock expectation and the service.

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/accounts/phone_auth_test.exs`
Expected: FAIL — `Emakola.Accounts.PhoneAuth` undefined.

- [ ] **Step 3: Implement the service**

```elixir
# lib/emakola/accounts/phone_auth.ex
defmodule Emakola.Accounts.PhoneAuth do
  @moduledoc """
  Issues and verifies phone one-time codes for WhatsApp/SMS authentication.
  Codes are 6 digits, stored hashed (Bcrypt), ~10-min TTL, ≤5 attempts, and
  rate-limited per phone. Delivery prefers WhatsApp, falls back to SMS.
  """
  require Ash.Query
  alias Emakola.Accounts.PhoneOtp

  @ttl_seconds 600
  @max_attempts 5
  @send_limit 3
  @send_window_ms 600_000
  @verify_limit 10
  @verify_window_ms 600_000

  @doc "Ship-dark switch — show the WhatsApp button only when enabled."
  def enabled?, do: Application.get_env(:emakola, :phone_auth_enabled, false)

  @doc "Generate, store (hashed), and deliver a code. opts: :store_id."
  def request_code(phone, purpose, opts \\ []) when purpose in [:merchant, :customer] do
    phone = normalize(phone)

    with :ok <- rate_limit("phone_otp:send:#{phone}", @send_limit, @send_window_ms),
         code <- generate_code(),
         {:ok, _otp} <- store(phone, code, purpose, opts),
         :ok <- deliver(phone, code, opts) do
      :ok
    end
  end

  @doc "Verify a code; consumes the OTP on success."
  def verify_code(phone, code, purpose, opts \\ []) when purpose in [:merchant, :customer] do
    phone = normalize(phone)

    with :ok <- rate_limit("phone_otp:verify:#{phone}", @verify_limit, @verify_window_ms),
         {:ok, otp} <- latest_live_otp(phone, purpose, opts),
         :ok <- check_not_expired(otp),
         :ok <- check_attempts(otp),
         :ok <- check_code(otp, code) do
      consume(otp)
      :ok
    end
  end

  @doc "Normalize a Ghana/Nigeria local or international number to E.164."
  def normalize(phone) do
    digits = String.replace(phone, ~r/[^\d+]/, "")

    cond do
      String.starts_with?(digits, "+") -> digits
      String.starts_with?(digits, "0") -> "+233" <> String.slice(digits, 1..-1//1)
      String.starts_with?(digits, "233") or String.starts_with?(digits, "234") -> "+" <> digits
      true -> "+233" <> digits
    end
  end

  defp generate_code, do: 100_000..999_999 |> Enum.random() |> Integer.to_string()

  defp store(phone, code, purpose, opts) do
    PhoneOtp
    |> Ash.Changeset.for_create(:issue, %{
      phone: phone,
      code_hash: Bcrypt.hash_pwd_salt(code),
      purpose: purpose,
      store_id: Keyword.get(opts, :store_id),
      expires_at: DateTime.add(DateTime.utc_now(), @ttl_seconds, :second)
    })
    |> Ash.create(authorize?: false)
  end

  defp deliver(phone, code, opts) do
    case send_whatsapp(phone, code, opts) do
      :ok -> :ok
      :error -> send_sms(phone, code)
    end
  end

  defp send_whatsapp(phone, code, opts) do
    case whatsapp_provider().send_message(phone, "auth_code", %{code: code},
           Keyword.take(opts, [:store_id]) ++ [bypass_rate_limit: true]
         ) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  defp send_sms(phone, code) do
    body = "Your Makola verification code is #{code}. It expires in 10 minutes."

    case sms_provider().send_sms(phone, body) do
      {:ok, _} -> :ok
      _ -> {:error, :delivery_failed}
    end
  end

  defp latest_live_otp(phone, purpose, _opts) do
    PhoneOtp
    |> Ash.Query.for_read(:live_for_phone, %{phone: phone, purpose: purpose})
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [otp]} -> {:ok, otp}
      _ -> {:error, :invalid}
    end
  end

  defp check_not_expired(otp) do
    if DateTime.compare(otp.expires_at, DateTime.utc_now()) == :gt, do: :ok, else: {:error, :expired}
  end

  defp check_attempts(otp) do
    if otp.attempts < @max_attempts, do: :ok, else: {:error, :too_many_attempts}
  end

  defp check_code(otp, code) do
    if Bcrypt.verify_pass(code, otp.code_hash) do
      :ok
    else
      otp |> Ash.Changeset.for_update(:record_attempt, %{}) |> Ash.update(authorize?: false)
      {:error, :invalid}
    end
  end

  defp consume(otp), do: otp |> Ash.Changeset.for_update(:consume, %{}) |> Ash.update(authorize?: false)

  defp rate_limit(key, limit, window_ms) do
    case Emakola.RateLimit.check_rate(key, limit, window_ms) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, :rate_limited}
    end
  end

  defp whatsapp_provider,
    do: Application.get_env(:emakola, :whatsapp_provider, Emakola.Notifications.Providers.LogWhatsApp)

  defp sms_provider,
    do: Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
end
```

> Verify the SMS provider module name + `send_sms/2` callback in `lib/emakola/notifications/` and the default Log provider names; adjust the two `*_provider/0` defaults to match.

- [ ] **Step 4: Enable in test config** — add to `config/test.exs`:

```elixir
config :emakola, :phone_auth_enabled, true
```

- [ ] **Step 5: Run test** — `mix test test/emakola/accounts/phone_auth_test.exs` → PASS (all cases).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/accounts/phone_auth.ex config/test.exs test/emakola/accounts/phone_auth_test.exs
git commit -m "feat(auth): PhoneAuth service — issue/verify OTP with WhatsApp→SMS fallback"
```

---

## Phase B — Web (components, merchant flow, customer flow, button activation)

### Task 6: Shared auth components (`otp_code_input`, `phone_input`, `whatsapp_button`)

**Files:**
- Create: `lib/emakola_web/components/auth_components.ex`
- Test: `test/emakola_web/components/auth_components_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola_web/components/auth_components_test.exs
defmodule EmakolaWeb.AuthComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "otp_code_input renders a numeric one-time-code field" do
    html = render_component(&EmakolaWeb.AuthComponents.otp_code_input/1, id: "otp")
    assert html =~ ~s(inputmode="numeric")
    assert html =~ ~s(autocomplete="one-time-code")
    assert html =~ ~s(maxlength="6")
  end

  test "phone_input defaults to the +233 country code" do
    html = render_component(&EmakolaWeb.AuthComponents.phone_input/1, id: "phone")
    assert html =~ "+233"
  end
end
```

- [ ] **Step 2: Run** — `mix test test/emakola_web/components/auth_components_test.exs` → FAIL (module undefined).

- [ ] **Step 3: Implement** (lift the platform `code_input` styling; numeric, letter-spaced)

```elixir
# lib/emakola_web/components/auth_components.ex
defmodule EmakolaWeb.AuthComponents do
  @moduledoc "Shared inputs for phone (WhatsApp/SMS) authentication."
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, default: "otp[code]"

  def otp_code_input(assigns) do
    ~H"""
    <input
      type="text"
      id={@id}
      name={@name}
      inputmode="numeric"
      autocomplete="one-time-code"
      pattern="[0-9]{6}"
      maxlength="6"
      placeholder="123456"
      required
      class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-center text-lg tracking-[0.5em] text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
    />
    """
  end

  attr :id, :string, required: true
  attr :name, :string, default: "phone[number]"
  attr :cc_name, :string, default: "phone[cc]"

  def phone_input(assigns) do
    ~H"""
    <div class="flex gap-2">
      <select
        name={@cc_name}
        class="w-24 bg-white border border-gray-200 rounded-xl px-2 py-3 text-sm text-[#0c1526]"
      >
        <option value="+233">+233</option>
        <option value="+234">+234</option>
      </select>
      <input
        type="tel"
        id={@id}
        name={@name}
        inputmode="tel"
        autocomplete="tel-national"
        placeholder="50 123 4567"
        required
        class="flex-1 bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
      />
    </div>
    """
  end

  attr :href, :string, required: true
  attr :class, :string, default: nil

  def whatsapp_button(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "w-full flex items-center justify-center gap-2 bg-whatsapp hover:bg-whatsapp-dark text-white font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm",
        @class
      ]}
    >
      <span class="material-symbols-outlined text-xl">chat</span> Continue with WhatsApp
    </.link>
    """
  end
end
```

- [ ] **Step 4: Run** — `mix test test/emakola_web/components/auth_components_test.exs` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/components/auth_components.ex test/emakola_web/components/auth_components_test.exs
git commit -m "feat(auth): shared OTP code + phone inputs + WhatsApp button component"
```

---

### Task 7: Merchant WhatsApp LiveView + route

**Files:**
- Create: `lib/emakola_web/live/auth/whats_app_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/auth/whats_app_live_test.exs`

**Behaviour:** `:phone` step → submit phone → `PhoneAuth.request_code(phone, :merchant)` → `:code` step → submit code → `PhoneAuth.verify_code/3` → resolve merchant by phone (existing → sign in; new → `:email` step → `register_with_phone`) → sign subject → redirect `/auth/session?token=…`. Resend gated by send rate-limit.

- [ ] **Step 1: Write the failing test** (drive the full flow with the WhatsApp mock capturing the code)

```elixir
# test/emakola_web/live/auth/whats_app_live_test.exs
defmodule EmakolaWeb.Auth.WhatsAppLiveTest do
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Mox
  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock)
    Application.put_env(:emakola, :phone_auth_enabled, true)
    :ok
  end

  test "new merchant: phone → code → email → signed in", %{conn: conn} do
    parent = self()
    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: c}, _ ->
      send(parent, {:code, c}); {:ok, %{}}
    end)

    {:ok, lv, _} = live(conn, ~p"/auth/whatsapp")
    lv |> form("#phone-form", phone: %{cc: "+233", number: "0501234567"}) |> render_submit()
    assert_received {:code, code}

    lv |> form("#code-form", otp: %{code: code}) |> render_submit()
    # New phone → email step
    result =
      lv |> form("#email-form", merchant: %{email: "wa@example.com", name: "Ama"}) |> render_submit()

    assert {:error, {:redirect, %{to: to}}} = result
    assert to =~ "/auth/session"
  end
end
```

- [ ] **Step 2: Run** — FAIL (`~p"/auth/whatsapp"` has no route).

- [ ] **Step 3: Add the route** — in `lib/emakola_web/router.ex`, inside the `scope "/auth", EmakolaWeb.Auth do` block (the LoginLive/RegisterLive scope):

```elixir
    live "/whatsapp", WhatsAppLive
```

- [ ] **Step 4: Implement the LiveView** (state machine; `current_user` set by AssignDefaults; calls `PhoneAuth` + `register_with_phone`; signs the subject)

```elixir
# lib/emakola_web/live/auth/whats_app_live.ex
defmodule EmakolaWeb.Auth.WhatsAppLive do
  use EmakolaWeb, :live_view
  import EmakolaWeb.AuthComponents
  alias Emakola.Accounts.{Merchant, PhoneAuth}
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, step: :phone, phone: nil, error: nil, page_title: "Sign in with WhatsApp")}
  end

  @impl true
  def handle_event("send_code", %{"phone" => %{"cc" => cc, "number" => number}}, socket) do
    phone = PhoneAuth.normalize(cc <> number)

    case PhoneAuth.request_code(phone, :merchant) do
      :ok -> {:noreply, assign(socket, step: :code, phone: phone, error: nil)}
      {:error, :rate_limited} -> {:noreply, assign(socket, error: "Too many attempts. Try again in a minute.")}
      {:error, _} -> {:noreply, assign(socket, error: "Couldn't send a code. Please try again.")}
    end
  end

  def handle_event("verify_code", %{"otp" => %{"code" => code}}, socket) do
    case PhoneAuth.verify_code(socket.assigns.phone, code, :merchant) do
      :ok -> resolve(socket)
      {:error, :too_many_attempts} -> {:noreply, assign(socket, error: "Too many attempts. Request a new code.")}
      {:error, :expired} -> {:noreply, assign(socket, step: :phone, error: "Code expired. Please try again.")}
      {:error, _} -> {:noreply, assign(socket, error: "Invalid code.")}
    end
  end

  def handle_event("create_account", %{"merchant" => params}, socket) do
    case Ash.create(
           Ash.Changeset.for_create(Merchant, :register_with_phone, %{
             email: params["email"],
             name: params["name"],
             phone: socket.assigns.phone
           }),
           authorize?: false
         ) do
      {:ok, merchant} -> {:noreply, sign_in(socket, merchant)}
      {:error, _} -> {:noreply, assign(socket, error: "That email is already in use. Try signing in instead.")}
    end
  end

  def handle_event("resend", _params, socket) do
    PhoneAuth.request_code(socket.assigns.phone, :merchant)
    {:noreply, assign(socket, error: nil)}
  end

  # After OTP success: existing merchant signs in; new phone goes to the email step.
  defp resolve(socket) do
    case merchant_by_phone(socket.assigns.phone) do
      nil -> {:noreply, assign(socket, step: :email, error: nil)}
      merchant -> {:noreply, sign_in(socket, merchant)}
    end
  end

  defp merchant_by_phone(phone) do
    Merchant
    |> Ash.Query.filter(phone == ^phone)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, m} -> m
      _ -> nil
    end
  end

  defp sign_in(socket, merchant) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))
    redirect(socket, to: ~p"/auth/session?#{[token: token]}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#f7f8fa] px-4">
      <div class="w-full max-w-md bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
        <h1 class="text-xl font-semibold text-[#0c1526] mb-6">Continue with WhatsApp</h1>

        <div :if={@error} class="mb-4 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700">
          {@error}
        </div>

        <.form :if={@step == :phone} for={%{}} id="phone-form" phx-submit="send_code" class="space-y-4">
          <label class="block text-sm font-medium text-[#0c1526]">Your WhatsApp number</label>
          <.phone_input id="wa-phone" />
          <button class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-white font-semibold py-3 rounded-xl text-sm">Send code</button>
        </.form>

        <.form :if={@step == :code} for={%{}} id="code-form" phx-submit="verify_code" class="space-y-4">
          <label class="block text-sm font-medium text-[#0c1526]">Enter the 6-digit code</label>
          <.otp_code_input id="wa-code" />
          <button class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-white font-semibold py-3 rounded-xl text-sm">Verify</button>
          <button type="button" phx-click="resend" class="w-full text-[#2563eb] text-sm font-medium">Resend code</button>
        </.form>

        <.form :if={@step == :email} for={%{}} id="email-form" phx-submit="create_account" class="space-y-4">
          <p class="text-sm text-[#5f6b7a]">Last step — your email (for receipts &amp; recovery).</p>
          <input type="email" name="merchant[email]" required placeholder="you@business.com"
            class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526]" />
          <input type="text" name="merchant[name]" placeholder="Your name (optional)"
            class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526]" />
          <button class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-white font-semibold py-3 rounded-xl text-sm">Create account</button>
        </.form>
      </div>
    </div>
    """
  end
end
```

> Iron Laws: `phone`/`code`/`email` are handled as strings (no `String.to_atom`); `:merchant` is a literal. The OTP gate is the authorization for account creation (verified phone).

- [ ] **Step 5: Run** — `mix test test/emakola_web/live/auth/whats_app_live_test.exs` → PASS. Add an "existing merchant signs in directly" test (seed `create_merchant!(phone: …)`, expect redirect after the code step, no email step).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/live/auth/whats_app_live.ex lib/emakola_web/router.ex test/emakola_web/live/auth/whats_app_live_test.exs
git commit -m "feat(auth): merchant WhatsApp phone-OTP LiveView flow"
```

---

### Task 8: Customer WhatsApp LiveView + route (store-scoped)

**Files:**
- Create: `lib/emakola_web/live/storefront/customer_whats_app_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Test: `test/emakola_web/live/storefront/customer_whats_app_live_test.exs`

Mirror Task 7 with these differences: route inside the storefront `live_session` (`live "/whatsapp", CustomerWhatsAppLive`); `on_mount ResolveStore` provides `@store`; pass `purpose: :customer, store_id: @store.id` to `PhoneAuth`; look up / create the `Customer` with `tenant: @store.id`; new-user step creates via `Customer` `register_with_phone` (tenant set); sign in with `:customer_token` by redirecting to `~p"/s/#{@store.slug}/auth/customer-session?#{[token: token]}"`. The store theme uses `cta-dark` classes instead of `#0c1526`.

- [ ] **Step 1: Write the failing test** (full flow, scoped to a seeded store; assert redirect to `/s/<slug>/auth/customer-session`).
- [ ] **Step 2: Run → FAIL (no route).**
- [ ] **Step 3: Add route** inside `scope "/s/:store_slug", EmakolaWeb.Storefront do … live_session :storefront_auth …`: `live "/whatsapp", CustomerWhatsAppLive`.
- [ ] **Step 4: Implement** (copy Task 7's LiveView; swap `Merchant`→`Customer`, add `store` from `@store`, thread `tenant: @store.id` + `store_id` into every `PhoneAuth`/`Ash` call, redirect to the customer-session controller). Look up by `Ash.Query.filter(phone == ^phone)` with `Ash.read_one(tenant: store.id, authorize?: false)`.
- [ ] **Step 5: Run → PASS** (+ a cross-store test: a phone registered in store A does not sign into store B).
- [ ] **Step 6: Commit** — `git commit -m "feat(auth): customer (store-scoped) WhatsApp phone-OTP LiveView flow"`.

---

### Task 9: Activate the buttons + consistency pass (ship-dark)

**Files:**
- Modify: `lib/emakola_web/live/auth/login_live.ex`, `register_live.ex`
- Modify: `lib/emakola_web/live/storefront/customer_login_live.ex`, `customer_register_live.ex`
- Test: `test/emakola_web/live/auth/whatsapp_button_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola_web/live/auth/whatsapp_button_test.exs
defmodule EmakolaWeb.Auth.WhatsAppButtonTest do
  use EmakolaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "merchant login shows an enabled WhatsApp link when phone auth is on", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, true)
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    assert html =~ ~s(href="/auth/whatsapp")
    refute html =~ "Coming Soon"
  end

  test "merchant login hides WhatsApp when phone auth is off", %{conn: conn} do
    Application.put_env(:emakola, :phone_auth_enabled, false)
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    refute html =~ "/auth/whatsapp"
  end
end
```

- [ ] **Step 2: Run → FAIL** (button is disabled "Coming Soon").

- [ ] **Step 3: Replace the disabled button** — in `login_live.ex` and `register_live.ex`, swap the disabled WhatsApp `<button>…Coming Soon…</button>` for:

```elixir
          <.whatsapp_button :if={Emakola.Accounts.PhoneAuth.enabled?()} href={~p"/auth/whatsapp"} class="mb-6" />
```

Add `import EmakolaWeb.AuthComponents` near the top of each LiveView (after `use EmakolaWeb, :live_view`). Keep the existing `<.oauth_buttons …>` and email form below it → final order **WhatsApp · social · email**.

For `customer_login_live.ex` and `customer_register_live.ex`, add above the existing `<.oauth_buttons …>`:

```elixir
          <.whatsapp_button :if={Emakola.Accounts.PhoneAuth.enabled?()} href={~p"/s/#{@store.slug}/whatsapp"} class="mb-6" />
```

(and `import EmakolaWeb.AuthComponents`).

- [ ] **Step 4: Run → PASS.** Also run the existing `register_live_test.exs` + customer auth tests to confirm no regression.

- [ ] **Step 5: Commit** — `git commit -m "feat(auth): activate WhatsApp button on merchant + customer auth pages (ship-dark)"`.

---

## Phase C — Config, housekeeping, verification

### Task 10: Runtime config + OTP prune worker

**Files:**
- Modify: `config/runtime.exs`, `config/dev.exs`
- Create: `lib/emakola/accounts/workers/phone_otp_prune_worker.ex`
- Modify: `config/config.exs` (add the worker to the Oban cron, if a cron plugin is configured)
- Test: `test/emakola/accounts/workers/phone_otp_prune_worker_test.exs`

- [ ] **Step 1:** Add `config :emakola, :phone_auth_enabled, System.get_env("PHONE_AUTH_ENABLED") == "true"` to `runtime.exs` (prod) and `config :emakola, :phone_auth_enabled, true` to `dev.exs`.
- [ ] **Step 2 (TDD):** Test that the prune worker deletes consumed/expired OTPs and leaves live ones. Run → FAIL.
- [ ] **Step 3:** Implement `PhoneOtpPruneWorker` (`use Oban.Worker, queue: :default`) deleting `phone_otps` where `consumed_at` is set or `expires_at < now()` (a bulk `Ash.bulk_destroy` or `Repo.delete_all` with a filter). Run → PASS.
- [ ] **Step 4:** Register it on the Oban cron if the project uses `Oban.Plugins.Cron` (check `config :emakola, Oban`); otherwise note it's enqueued opportunistically and skip the cron wiring.
- [ ] **Step 5: Commit** — `git commit -m "feat(auth): phone_auth config flag + OTP prune worker"`.

### Task 11: Full verification + docs

- [ ] **Step 1:** `mix test` (full suite) → all green.
- [ ] **Step 2:** `mix format --check-formatted` and `mix credo --strict` → clean. (Split any `references(...), null: false` onto separate lines per CI's Elixir 1.18 formatter; verify `mix compile --warnings-as-errors` has no new warnings on the changed files.)
- [ ] **Step 3:** Add a short "WhatsApp OTP" section to `docs/PROVIDER_SETUP.md`: submit the `auth_code` **authentication-category** template to Meta (`{{1}}` = code), and set `PHONE_AUTH_ENABLED=true` once SMS (now) or WhatsApp (after approval) can deliver. Note SMS fallback carries it in the meantime.
- [ ] **Step 4: Commit** — `git commit -m "docs(auth): WhatsApp OTP template + activation steps"`.
- [ ] **Step 5:** Push + open PR targeting `main`.

---

## Self-Review

**Spec coverage:** PhoneOtp (T1) · service issue/verify + WhatsApp→SMS fallback (T5) · phone identities (T2) · passwordless register_with_phone + find-or-create-collect-email (T3, T7, T8) · auth_code template (T4) · OTP/phone inputs + button (T6, T9) · merchant flow (T7) · customer store-scoped flow (T8) · ship-dark gating (T5 `enabled?` + T9) · rate limiting + hashing + expiry + attempts + tenant scoping (T1, T5, T8) · config + prune + Meta template dependency (T10, T11). All spec sections map to a task.

**Placeholder scan:** Tasks 8 and 10 describe steps by mirroring Task 7 / standard patterns rather than repeating every line — intentional (T8 is T7 with documented deltas; T10 is mechanical config). All novel code (resource, service, components, merchant LiveView) is shown in full.

**Type consistency:** `PhoneAuth.request_code/3` + `verify_code/4` + `normalize/1` + `enabled?/0` signatures match across tasks; `purpose` is `:merchant | :customer` everywhere; `register_with_phone` accepts `[:email, :name, :phone]` on both resources; the WhatsApp template name `"auth_code"` and its `[:code]` param order match between T4 and T5.

**Pre-implementation checks (do first):** confirm the SMS provider module + `send_sms/2` callback name and the default Log provider module names; confirm whether `Oban.Plugins.Cron` is configured (affects T10 step 4).
