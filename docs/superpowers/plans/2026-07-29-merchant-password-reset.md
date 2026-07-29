# Merchant Password Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Self-serve password reset for merchants: request a link at `/auth/forgot-password`, set a new password at `/auth/reset-password?token=`, all other sessions revoked on success.

**Architecture:** AshAuthentication's `resettable` on the existing Merchant password strategy generates both actions; two hand-rolled LiveViews (matching `LoginLive`'s style and in-LiveView rate limiting) drive them via `AshAuthentication.Strategy.action/3`. The orphaned `PasswordResetSender`/`AuthMailer.password_reset/2` scaffolding is reused as-is (one copy fix).

**Tech Stack:** Phoenix LiveView, AshAuthentication 4.13, Swoosh (Test adapter in tests, Local + `/dev/mailbox` in dev), Playwright.

**Spec:** `docs/superpowers/specs/2026-07-29-merchant-password-reset-design.md`

## Global Constraints

- TDD: write the failing test first for every task; run it red before implementing.
- `mix format` + `mix credo --strict` + `MIX_ENV=test mix compile --warnings-as-errors` must stay clean.
- Conventional commits ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- User-facing Ash errors go through `EmakolaWeb.AshErrors.message/1` (never raw `.message` — `%{min}` leak).
- No `String.to_atom` on user input; both new LiveViews are pre-auth screens — every `handle_event` treats params as untrusted strings.
- Token lifetime is exactly `{24, :hours}`; email copy must say "24 hours".
- Anti-enumeration: unknown email renders the identical confirmation UI as a known one.
- E2E uses `efua@tinystitches.com` (NOT kwame — his credentials back the suite's shared storageState) and always sets the same new password `Reset-Password-99!` so reruns are deterministic.

---

### Task 1: `resettable` strategy + email copy fix

**Files:**
- Modify: `lib/emakola/accounts/resources/merchant.ex` (password strategy block, ~line 88)
- Modify: `lib/emakola/notifications/mailers/auth_mailer.ex` (`password_reset/2` copy: "1 hour" → "24 hours")
- Test: `test/emakola/accounts/password_reset_test.exs` (new)

**Interfaces:**
- Consumes: existing `Emakola.Accounts.Senders.PasswordResetSender`, `AuthMailer.password_reset/2`.
- Produces: Merchant actions `:request_password_reset_with_password` and `:password_reset_with_password`, reachable via `AshAuthentication.Strategy.action(strategy, :reset_request | :reset, params)` where `strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.Merchant, :password)`. Reset params: `%{"reset_token" => t, "password" => p, "password_confirmation" => p}`.

- [ ] **Step 1: Write the failing tests**

```elixir
# test/emakola/accounts/password_reset_test.exs
defmodule Emakola.Accounts.PasswordResetTest do
  use Emakola.DataCase, async: true

  import Swoosh.TestAssertions

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.Merchant

  defp unique_email, do: "reset-#{System.unique_integer([:positive])}@example.com"

  defp register!(email) do
    Merchant
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{
        name: "Reset Tester",
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp strategy, do: Info.strategy!(Merchant, :password)

  defp extract_token_from_email do
    assert_email_sent(fn sent ->
      assert sent.subject == "Reset your Makola password"
      assert [token] = Regex.run(~r{/auth/reset-password\?token=([^"\s]+)}, sent.text_body, capture: :all_but_first)
      token
    end)
  end

  describe "reset_request" do
    test "sends a reset email with a /auth/reset-password?token= link" do
      email = unique_email()
      register!(email)

      assert :ok = Strategy.action(strategy(), :reset_request, %{"email" => email})

      assert_email_sent(fn sent ->
        assert {_, ^email} = hd(sent.to)
        assert sent.subject == "Reset your Makola password"
        assert sent.text_body =~ "/auth/reset-password?token="
        # Copy must match the configured 24h lifetime
        assert sent.html_body =~ "24 hours"
      end)
    end

    test "an unknown email sends nothing and returns the same shape" do
      assert :ok = Strategy.action(strategy(), :reset_request, %{"email" => unique_email()})
      refute_email_sent()
    end
  end

  describe "reset" do
    test "a valid token sets the new password; the old one stops working" do
      email = unique_email()
      register!(email)
      :ok = Strategy.action(strategy(), :reset_request, %{"email" => email})
      token = extract_token_from_email()

      assert {:ok, _user} =
               Strategy.action(strategy(), :reset, %{
                 "reset_token" => token,
                 "password" => "NewPassword456!",
                 "password_confirmation" => "NewPassword456!"
               })

      assert {:ok, _} =
               Strategy.action(strategy(), :sign_in, %{"email" => email, "password" => "NewPassword456!"})

      assert {:error, _} =
               Strategy.action(strategy(), :sign_in, %{"email" => email, "password" => "Password123!"})
    end

    test "a garbage token is rejected" do
      assert {:error, _} =
               Strategy.action(strategy(), :reset, %{
                 "reset_token" => "not-a-real-token",
                 "password" => "NewPassword456!",
                 "password_confirmation" => "NewPassword456!"
               })
    end

    test "a too-short password is rejected with the field error" do
      email = unique_email()
      register!(email)
      :ok = Strategy.action(strategy(), :reset_request, %{"email" => email})
      token = extract_token_from_email()

      assert {:error, %Ash.Error.Invalid{}} =
               Strategy.action(strategy(), :reset, %{
                 "reset_token" => token,
                 "password" => "short",
                 "password_confirmation" => "short"
               })
    end
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/accounts/password_reset_test.exs`
Expected: FAIL — `Info.strategy!` returns a strategy whose `resettable` is `nil`, so `:reset_request` raises/errors (no such phase).

- [ ] **Step 3: Implement**

In `lib/emakola/accounts/resources/merchant.ex`, extend the password strategy:

```elixir
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)

        resettable do
          sender(Emakola.Accounts.Senders.PasswordResetSender)
          token_lifetime({24, :hours})
        end
      end
```

In `lib/emakola/notifications/mailers/auth_mailer.ex`, `password_reset/2`: change
`This link expires in 1 hour.` → `This link expires in 24 hours.`

- [ ] **Step 4: Run to verify pass**

Run: `mix test test/emakola/accounts/password_reset_test.exs`
Expected: 5 tests PASS. If `Strategy.action(:reset_request, ...)` returns `{:ok, _}` instead of `:ok`, relax the two asserts to `assert :ok = ` → `assert match?(:ok, result) or match?({:ok, _}, result)` — pin whatever the library actually returns, then keep it exact.

- [ ] **Step 5: Full-file gates + commit**

```bash
mix format && mix credo --strict && MIX_ENV=test mix compile --warnings-as-errors
git add lib/emakola/accounts/resources/merchant.ex lib/emakola/notifications/mailers/auth_mailer.ex test/emakola/accounts/password_reset_test.exs
git commit -m "feat(auth): enable password reset on the Merchant password strategy"
```

---

### Task 2: revoke-all-tokens helper (sign out everywhere)

**Files:**
- Modify: `lib/emakola/accounts/accounts.ex` (add one public function)
- Test: `test/emakola/accounts/revoke_all_tokens_test.exs` (new)

**Interfaces:**
- Consumes: `Emakola.Accounts.Token`'s auto-generated `:revoke_all_stored_for_subject` update action (argument `subject :: String.t()`); `AshAuthentication.user_to_subject/1`.
- Produces: `Emakola.Accounts.revoke_all_tokens_for(merchant) :: :ok` — used by Task 4.

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola/accounts/revoke_all_tokens_test.exs
defmodule Emakola.Accounts.RevokeAllTokensTest do
  use Emakola.DataCase, async: true

  require Ash.Query

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.{Merchant, Token}

  test "revoke_all_tokens_for/1 marks every stored token for the merchant as revoked" do
    email = "revoke-#{System.unique_integer([:positive])}@example.com"

    merchant =
      Merchant
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{name: "Revoke Tester", email: email, password: "Password123!", password_confirmation: "Password123!"},
        authorize?: false
      )
      |> Ash.create!()

    # Minting a session stores a token row (store_all_tokens? is on)
    strategy = Info.strategy!(Merchant, :password)
    {:ok, _} = Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "Password123!"})

    subject = AshAuthentication.user_to_subject(merchant)

    live_tokens =
      Token
      |> Ash.Query.filter(subject == ^subject and purpose != "revocation")
      |> Ash.read!(authorize?: false)

    assert live_tokens != [], "expected sign-in to store at least one live token"

    assert :ok = Emakola.Accounts.revoke_all_tokens_for(merchant)

    remaining =
      Token
      |> Ash.Query.filter(subject == ^subject and purpose != "revocation")
      |> Ash.read!(authorize?: false)

    assert remaining == []
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola/accounts/revoke_all_tokens_test.exs`
Expected: FAIL — `Emakola.Accounts.revoke_all_tokens_for/1` is undefined.

- [ ] **Step 3: Implement**

In `lib/emakola/accounts/accounts.ex` (the domain module — match its existing style; add `require Ash.Query` at module level if you use the filter form):

```elixir
  @doc """
  Revoke every stored authentication token for a merchant — web sessions and
  API refresh tokens alike. Used after a successful password reset so a
  changed password signs out every other device (including an attacker's).
  """
  def revoke_all_tokens_for(merchant) do
    subject = AshAuthentication.user_to_subject(merchant)

    Emakola.Accounts.Token
    |> Ash.bulk_update!(:revoke_all_stored_for_subject, %{subject: subject},
      authorize?: false,
      strategy: [:atomic, :atomic_batches, :stream]
    )

    :ok
  end
```

Note: the `:revoke_all_stored_for_subject` change filters `subject == ^subject`
itself, so the bulk update over the resource is safe. If `Ash.bulk_update!`
raises on the unfiltered resource in this Ash version, switch to
`Emakola.Accounts.Token |> Ash.Query.for_read(:read) |> Ash.bulk_update!(...)` —
keep whichever form the test proves.

- [ ] **Step 4: Run to verify pass**

Run: `mix test test/emakola/accounts/revoke_all_tokens_test.exs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
mix format && git add lib/emakola/accounts/accounts.ex test/emakola/accounts/revoke_all_tokens_test.exs
git commit -m "feat(auth): revoke all stored merchant tokens helper"
```

---

### Task 3: ForgotPasswordLive + route + login link

**Files:**
- Create: `lib/emakola_web/live/auth/forgot_password_live.ex`
- Modify: `lib/emakola_web/router.ex` (the `scope "/auth", EmakolaWeb.Auth` block with `auth_rate_limit`, ~line 186: add one `live` line)
- Modify: `lib/emakola_web/live/auth/login_live.ex:146` (`href="#"` → `href="/auth/forgot-password"`)
- Test: `test/emakola_web/live/auth/forgot_password_live_test.exs` (new)

**Interfaces:**
- Consumes: `Strategy.action(strategy, :reset_request, %{"email" => email})` from Task 1; `Emakola.RateLimit.check_rate/3`.
- Produces: route `GET /auth/forgot-password`; confirmation copy exact string: `If that email has a Makola account, we've sent a reset link.`

- [ ] **Step 1: Write the failing tests**

```elixir
# test/emakola_web/live/auth/forgot_password_live_test.exs
defmodule EmakolaWeb.Auth.ForgotPasswordLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  defp register!(email) do
    Emakola.Accounts.Merchant
    |> Ash.Changeset.for_create(
      :register_with_password,
      %{name: "Forgot Tester", email: email, password: "Password123!", password_confirmation: "Password123!"},
      authorize?: false
    )
    |> Ash.create!()
  end

  test "renders the request form with a back-to-login link", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/forgot-password")
    assert html =~ "Forgot your password"
    assert html =~ ~s(href="/auth/login")
  end

  test "a known email sends the reset mail and shows the neutral confirmation", %{conn: conn} do
    email = "forgot-#{System.unique_integer([:positive])}@example.com"
    register!(email)

    {:ok, lv, _html} = live(conn, ~p"/auth/forgot-password")

    html =
      lv
      |> form("form", forgot: %{email: email})
      |> render_submit()

    assert html =~ "If that email has a Makola account"
    assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
  end

  test "an unknown email shows the identical confirmation and sends nothing", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/auth/forgot-password")

    html =
      lv
      |> form("form", forgot: %{email: "nobody-#{System.unique_integer([:positive])}@example.com"})
      |> render_submit()

    assert html =~ "If that email has a Makola account"
    refute_email_sent()
  end

  test "the login page links here instead of href=#", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/login")
    assert html =~ ~s(href="/auth/forgot-password")
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/auth/forgot_password_live_test.exs`
Expected: FAIL — no route `/auth/forgot-password`.

- [ ] **Step 3: Implement**

Router — inside the existing block:

```elixir
  scope "/auth", EmakolaWeb.Auth do
    pipe_through [:browser, :auth_rate_limit]
    live "/login", LoginLive
    live "/register", RegisterLive
    live "/whatsapp", WhatsAppLive
    live "/forgot-password", ForgotPasswordLive
  end
```

`login_live.ex:146`: `<a href="/auth/forgot-password" class="text-xs font-medium text-[#2563eb] hover:underline">Forgot?</a>`

New LiveView — mirrors `LoginLive`'s structure (ip capture at mount, in-LiveView rate limiting, `layout: false`, same palette):

```elixir
defmodule EmakolaWeb.Auth.ForgotPasswordLive do
  use EmakolaWeb, :live_view

  require Logger

  # Mirrors LoginLive's limiter; plus a per-email cap so nobody can bomb a
  # merchant's inbox from rotating IPs.
  @ip_limit 10
  @ip_window_ms 60_000
  @email_limit 3
  @email_window_ms 15 * 60_000

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(client_ip: get_client_ip(socket))
     |> assign(sent: false)
     |> assign(form: to_form(%{"email" => ""}, as: :forgot)), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#f7f8fa] px-6 py-12">
      <div class="w-full max-w-md">
        <div class="flex items-center justify-center gap-2 mb-8">
          <img src={~p"/images/emakola-logo.svg"} alt="Makola" class="h-8 w-auto" />
          <span class="text-[#0c1526] text-lg font-bold tracking-tight">Makola</span>
        </div>

        <div class="mb-8 text-center">
          <h1 class="text-2xl font-bold text-[#0c1526]">Forgot your password?</h1>
          <p class="text-[#5f6b7a] mt-1 text-sm">
            Enter your account email and we'll send you a reset link.
          </p>
        </div>

        <div
          :if={@flash["error"]}
          class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
          role="alert"
        >
          <span class="material-symbols-outlined text-lg text-red-500">error</span>
          <span>{@flash["error"]}</span>
        </div>

        <div
          :if={@sent}
          class="mb-4 flex items-start gap-2 rounded-xl bg-emerald-50 border border-emerald-200 px-4 py-3 text-sm text-emerald-800"
          role="status"
        >
          <span class="material-symbols-outlined text-lg text-emerald-600">mark_email_read</span>
          <span>
            If that email has a Makola account, we've sent a reset link.
            It expires in 24 hours — check your spam folder too.
          </span>
        </div>

        <.form :if={!@sent} for={@form} phx-submit="request_reset" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Email</label>
            <div class="relative">
              <span class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-[#8896ab] text-xl">
                mail
              </span>
              <input
                type="email"
                name="forgot[email]"
                value={@form[:email].value}
                placeholder="you@business.com"
                required
                class="w-full bg-white border border-gray-200 rounded-xl pl-10 pr-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
              />
            </div>
          </div>
          <button
            type="submit"
            class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
          >
            Send Reset Link
          </button>
        </.form>

        <p class="mt-6 text-center text-sm text-[#5f6b7a]">
          Remembered it?
          <a href="/auth/login" class="font-medium text-[#2563eb] hover:underline">Back to login</a>
        </p>
      </div>
    </div>
    """
  end

  def handle_event("request_reset", %{"forgot" => %{"email" => email}}, socket) do
    ip = socket.assigns.client_ip
    email = email |> String.trim() |> String.downcase()

    with {:allow, _} <- Emakola.RateLimit.check_rate("auth_forgot:#{ip}", @ip_limit, @ip_window_ms),
         {:allow, _} <-
           Emakola.RateLimit.check_rate("auth_forgot_email:#{email}", @email_limit, @email_window_ms) do
      request_reset(email)
      {:noreply, assign(socket, sent: true)}
    else
      {:deny, _retry_after} ->
        Logger.warning("Password-reset request rate limit exceeded for #{ip}")

        {:noreply,
         put_flash(socket, :error, "Too many reset requests. Please try again in a few minutes.")}
    end
  end

  defp request_reset(email) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.Merchant, :password)
    AshAuthentication.Strategy.action(strategy, :reset_request, %{"email" => email})
  rescue
    # An email/provider hiccup must not become an enumeration oracle — the UI
    # shows the neutral confirmation either way; the failure is in the logs.
    exception ->
      Logger.error("[ForgotPassword] reset_request raised: #{Exception.message(exception)}")
      :ok
  end

  # Must be called during mount — get_connect_info is only available then
  defp get_client_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: {a, b, c, d}} -> "#{a}.#{b}.#{c}.#{d}"
      %{address: ip} -> to_string(:inet.ntoa(ip))
      _ -> "unknown"
    end
  rescue
    _ -> "unknown"
  end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `mix test test/emakola_web/live/auth/forgot_password_live_test.exs`
Expected: 4 tests PASS. (Rate-limit denial is NOT LiveView-tested here — `Emakola.RateLimit` is live in tests and per-test IPs collide on "unknown"; the limiter pattern is already covered by `login_live` precedent and security tests.)

- [ ] **Step 5: Commit**

```bash
mix format && git add lib/emakola_web/live/auth/forgot_password_live.ex lib/emakola_web/router.ex lib/emakola_web/live/auth/login_live.ex test/emakola_web/live/auth/forgot_password_live_test.exs
git commit -m "feat(auth): forgot-password request screen"
```

---

### Task 4: ResetPasswordLive + route

**Files:**
- Create: `lib/emakola_web/live/auth/reset_password_live.ex`
- Modify: `lib/emakola_web/router.ex` (same scope: `live "/reset-password", ResetPasswordLive`)
- Test: `test/emakola_web/live/auth/reset_password_live_test.exs` (new)

**Interfaces:**
- Consumes: `Strategy.action(strategy, :reset, %{"reset_token" => t, "password" => p, "password_confirmation" => p})` (Task 1); `Emakola.Accounts.revoke_all_tokens_for/1` (Task 2); `EmakolaWeb.AshErrors.message/1`.
- Produces: route `GET /auth/reset-password?token=...` — the exact URL `AuthMailer.password_reset/2` already emits.

- [ ] **Step 1: Write the failing tests**

```elixir
# test/emakola_web/live/auth/reset_password_live_test.exs
defmodule EmakolaWeb.Auth.ResetPasswordLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  require Ash.Query

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.{Merchant, Token}

  defp register_and_request_token! do
    email = "resetlv-#{System.unique_integer([:positive])}@example.com"

    merchant =
      Merchant
      |> Ash.Changeset.for_create(
        :register_with_password,
        %{name: "ResetLV Tester", email: email, password: "Password123!", password_confirmation: "Password123!"},
        authorize?: false
      )
      |> Ash.create!()

    strategy = Info.strategy!(Merchant, :password)
    Strategy.action(strategy, :reset_request, %{"email" => email})

    token =
      assert_email_sent(fn sent ->
        [t] = Regex.run(~r{/auth/reset-password\?token=([^"\s]+)}, sent.text_body, capture: :all_but_first)
        t
      end)

    {merchant, email, token}
  end

  test "renders the new-password form when a token is present", %{conn: conn} do
    {_m, _e, token} = register_and_request_token!()
    {:ok, _lv, html} = live(conn, ~p"/auth/reset-password?token=#{token}")
    assert html =~ "Set a new password"
  end

  test "a valid reset redirects to login, changes the password, and revokes other sessions", %{conn: conn} do
    {merchant, email, token} = register_and_request_token!()
    strategy = Info.strategy!(Merchant, :password)

    # A live session from before the reset — must die with the reset
    {:ok, _} = Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "Password123!"})

    {:ok, lv, _html} = live(conn, ~p"/auth/reset-password?token=#{token}")

    result =
      lv
      |> form("form",
        reset: %{password: "NewPassword456!", password_confirmation: "NewPassword456!"}
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: "/auth/login", flash: flash}}} = result
    assert flash["info"] =~ "Password updated"

    assert {:ok, _} = Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "NewPassword456!"})
    assert {:error, _} = Strategy.action(strategy, :sign_in, %{"email" => email, "password" => "Password123!"})

    subject = AshAuthentication.user_to_subject(merchant)

    live_tokens =
      Token
      |> Ash.Query.filter(subject == ^subject and purpose != "revocation")
      |> Ash.read!(authorize?: false)

    assert live_tokens == [], "expected all pre-reset tokens to be revoked"
  end

  test "a short password shows the interpolated error, not %{min}", %{conn: conn} do
    {_m, _e, token} = register_and_request_token!()
    {:ok, lv, _html} = live(conn, ~p"/auth/reset-password?token=#{token}")

    html =
      lv
      |> form("form", reset: %{password: "short", password_confirmation: "short"})
      |> render_submit()

    refute html =~ "%{min}"
    assert html =~ "greater than or equal to 8"
  end

  test "a garbage token shows the invalid-link state with a re-request link", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/auth/reset-password?token=garbage")

    html =
      lv
      |> form("form", reset: %{password: "NewPassword456!", password_confirmation: "NewPassword456!"})
      |> render_submit()

    assert html =~ "link is invalid or has expired"
    assert html =~ ~s(href="/auth/forgot-password")
  end

  test "no token at all renders the invalid-link state immediately", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/auth/reset-password")
    assert html =~ "link is invalid or has expired"
    assert html =~ ~s(href="/auth/forgot-password")
  end
end
```

- [ ] **Step 2: Run to verify failure**

Run: `mix test test/emakola_web/live/auth/reset_password_live_test.exs`
Expected: FAIL — no route.

- [ ] **Step 3: Implement**

Router (same `/auth` scope): `live "/reset-password", ResetPasswordLive`

```elixir
defmodule EmakolaWeb.Auth.ResetPasswordLive do
  use EmakolaWeb, :live_view

  require Logger

  alias AshAuthentication.{Info, Strategy}

  def mount(params, _session, socket) do
    token = params["token"]

    {:ok,
     socket
     |> assign(token: token)
     |> assign(invalid_link: token in [nil, ""])
     |> assign(form: to_form(%{"password" => "", "password_confirmation" => ""}, as: :reset)),
     layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#f7f8fa] px-6 py-12">
      <div class="w-full max-w-md">
        <div class="flex items-center justify-center gap-2 mb-8">
          <img src={~p"/images/emakola-logo.svg"} alt="Makola" class="h-8 w-auto" />
          <span class="text-[#0c1526] text-lg font-bold tracking-tight">Makola</span>
        </div>

        <div :if={@invalid_link} class="text-center">
          <div class="mb-4 inline-flex items-center gap-2 rounded-xl bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-800">
            <span class="material-symbols-outlined text-lg text-amber-600">link_off</span>
            <span>This reset link is invalid or has expired.</span>
          </div>
          <p class="text-sm text-[#5f6b7a]">
            <a href="/auth/forgot-password" class="font-medium text-[#2563eb] hover:underline">
              Request a new reset link
            </a>
          </p>
        </div>

        <div :if={!@invalid_link}>
          <div class="mb-8 text-center">
            <h1 class="text-2xl font-bold text-[#0c1526]">Set a new password</h1>
            <p class="text-[#5f6b7a] mt-1 text-sm">Minimum 8 characters.</p>
          </div>

          <div
            :if={@flash["error"]}
            class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
            role="alert"
          >
            <span class="material-symbols-outlined text-lg text-red-500">error</span>
            <span>{@flash["error"]}</span>
          </div>

          <.form for={@form} phx-submit="reset_password" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-[#0c1526] mb-1.5">New password</label>
              <input
                type="password"
                name="reset[password]"
                placeholder="Min. 8 characters"
                required
                class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-[#0c1526] mb-1.5">Confirm new password</label>
              <input
                type="password"
                name="reset[password_confirmation]"
                placeholder="Repeat the password"
                required
                class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
              />
            </div>
            <button
              type="submit"
              class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
            >
              Update Password
            </button>
          </.form>

          <p class="mt-6 text-center text-sm text-[#5f6b7a]">
            <a href="/auth/login" class="font-medium text-[#2563eb] hover:underline">Back to login</a>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("reset_password", %{"reset" => params}, socket) do
    strategy = Info.strategy!(Emakola.Accounts.Merchant, :password)

    case Strategy.action(strategy, :reset, %{
           "reset_token" => socket.assigns.token,
           "password" => params["password"] || "",
           "password_confirmation" => params["password_confirmation"] || ""
         }) do
      {:ok, merchant} ->
        # Password proof rotated — sign out every other device, attacker included.
        Emakola.Accounts.revoke_all_tokens_for(merchant)

        {:noreply,
         socket
         |> put_flash(:info, "Password updated. Sign in with your new password.")
         |> redirect(to: "/auth/login")}

      {:error, error} ->
        if invalid_token_error?(error) do
          {:noreply, assign(socket, invalid_link: true)}
        else
          {:noreply, put_flash(socket, :error, format_field_errors(error))}
        end
    end
  end

  defp invalid_token_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %{field: :reset_token} -> true
      %AshAuthentication.Errors.InvalidToken{} -> true
      _ -> false
    end)
  end

  defp invalid_token_error?(_), do: false

  defp format_field_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ". ", fn
      %{field: field} = error when not is_nil(field) ->
        "#{Phoenix.Naming.humanize(field)} #{EmakolaWeb.AshErrors.message(error)}"

      %{message: message} = error when is_binary(message) ->
        EmakolaWeb.AshErrors.message(error)

      _ ->
        "Something went wrong. Please try again."
    end)
  end

  defp format_field_errors(_), do: "Something went wrong. Please try again."
end
```

- [ ] **Step 4: Run to verify pass**

Run: `mix test test/emakola_web/live/auth/reset_password_live_test.exs`
Expected: 5 tests PASS. If the invalid-token error arrives shaped differently
(e.g. `%Ash.Error.Forbidden{}` or a jwt-subject error), print it once with
`dbg(error)` in the failing test run, extend `invalid_token_error?/1` to match
the real struct, and delete the dbg.

- [ ] **Step 5: Run the whole auth surface + commit**

Run: `mix test test/emakola/accounts test/emakola_web/live/auth`
Expected: all PASS.

```bash
mix format && git add lib/emakola_web/live/auth/reset_password_live.ex lib/emakola_web/router.ex test/emakola_web/live/auth/reset_password_live_test.exs
git commit -m "feat(auth): reset-password screen with sign-out-everywhere"
```

---

### Task 5: Playwright E2E + full gates

**Files:**
- Create: `e2e/tests/password-reset.spec.ts`

**Interfaces:**
- Consumes: dev server with Swoosh Local adapter; `GET /dev/mailbox/json` (newest-first email list with `to`/`subject`/`text_body` fields — verify exact field casing against a live response before asserting); seeded merchant `efua@tinystitches.com`.

- [ ] **Step 1: Write the spec**

```typescript
// e2e/tests/password-reset.spec.ts
import { test, expect } from "@playwright/test";

/**
 * Full journey: request reset -> pull the real link out of the dev mailbox
 * (/dev/mailbox/json, Swoosh Local adapter) -> set a new password -> sign in
 * with it.
 *
 * Uses efua@tinystitches.com, NOT kwame (his credentials back the shared
 * storageState), and always sets the same password so reruns are stable:
 * requesting a reset never needs the old password.
 */
const EMAIL = "efua@tinystitches.com";
const NEW_PASSWORD = "Reset-Password-99!";

test.describe("Merchant password reset", () => {
  test("request -> email link -> new password -> login", async ({ page, request }) => {
    await page.goto("/auth/forgot-password");
    await page.waitForLoadState("networkidle");
    await page.locator("input[name='forgot[email]']").fill(EMAIL);
    await page.getByRole("button", { name: "Send Reset Link" }).click();
    await expect(page.getByText(/If that email has a Makola account/)).toBeVisible({
      timeout: 10_000,
    });

    // The Local adapter's mailbox lists newest first.
    const mailbox = await request.get("/dev/mailbox/json");
    expect(mailbox.ok()).toBe(true);
    const body = await mailbox.json();
    const emails: any[] = Array.isArray(body) ? body : body.data ?? body.emails ?? [];
    const resetMail = emails.find(
      (m) =>
        JSON.stringify(m.to).includes(EMAIL) &&
        String(m.subject).includes("Reset your Makola password")
    );
    expect(resetMail, "reset email not found in /dev/mailbox/json").toBeTruthy();

    const haystack = `${resetMail.text_body ?? ""} ${resetMail.html_body ?? ""}`;
    const match = haystack.match(/\/auth\/reset-password\?token=[A-Za-z0-9._~-]+/);
    expect(match, "no reset link in the email body").toBeTruthy();

    await page.goto(match![0]);
    await page.waitForLoadState("networkidle");
    await expect(page.getByRole("heading", { name: "Set a new password" })).toBeVisible();
    await page.locator("input[name='reset[password]']").fill(NEW_PASSWORD);
    await page.locator("input[name='reset[password_confirmation]']").fill(NEW_PASSWORD);
    await page.getByRole("button", { name: "Update Password" }).click();

    await page.waitForURL("**/auth/login", { timeout: 15_000 });
    await expect(page.locator("[role=alert], [role=status]").first()).toContainText(
      /Password updated/,
      { timeout: 10_000 }
    );

    await page.locator("input[name='user[email]']").fill(EMAIL);
    await page.locator("input[name='user[password]']").fill(NEW_PASSWORD);
    await page.getByRole("button", { name: "Sign In" }).click();
    await page.waitForURL("**/dashboard", { timeout: 20_000 });
  });

  test("a garbage token shows the invalid-link state", async ({ page }) => {
    await page.goto("/auth/reset-password?token=garbage");
    await page.locator("input[name='reset[password]']").fill(NEW_PASSWORD);
    await page.locator("input[name='reset[password_confirmation]']").fill(NEW_PASSWORD);
    await page.getByRole("button", { name: "Update Password" }).click();
    await expect(page.getByText(/link is invalid or has expired/)).toBeVisible({
      timeout: 10_000,
    });
    await expect(page.locator("a[href='/auth/forgot-password']")).toBeVisible();
  });
});
```

- [ ] **Step 2: Run the new spec against the dev server**

The dev server must be running the branch (`DISABLE_RATE_LIMIT=1 mix phx.server`;
hot reload picks the branch up). First run:
`cd e2e && npx playwright test --project=desktop-chrome tests/password-reset.spec.ts --reporter=list`
Expected: PASS. If `/dev/mailbox/json`'s shape differs (field names), adjust the
extraction to the real payload — check with `curl -s localhost:4000/dev/mailbox/json | head -c 600`.

- [ ] **Step 3: Full regression — both stacks**

```bash
mix format --check-formatted && mix credo --strict && MIX_ENV=test mix compile --warnings-as-errors
mix test                       # expect: 0 failures
cd e2e && npx playwright test  # expect: 0 failures (both projects)
```

- [ ] **Step 4: Commit**

```bash
git add e2e/tests/password-reset.spec.ts
git commit -m "test(web): E2E password-reset journey via the dev mailbox"
```

---

## Self-Review Notes

- Spec coverage: strategy+lifetime (T1), forgot screen+rate limits+link (T3), reset screen+AshErrors+invalid state (T4), revocation (T2, wired in T4), anti-enumeration (T1+T3 tests), E2E via mailbox (T5), email copy lifetime (T1). Out-of-scope items untouched.
- The per-IP/per-email limiter denial path is intentionally untested at LiveView level (live Hammer counters collide across async tests on the "unknown" IP); the deny branch is exercised in production code identical to LoginLive's proven pattern.
- Type consistency: `Strategy.action/3` phases `:reset_request`/`:reset`; helper `revoke_all_tokens_for/1`; form names `forgot[email]`, `reset[password]`, `reset[password_confirmation]` — consistent across T3/T4/T5.
