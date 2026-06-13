# Mobile API Phase 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bearer-token-authenticated, tenant-scoped JSON:API under `/api/v1` for merchant order management, plus a DeviceToken registry and an FCM push pipeline (mock-verified) that fires on new orders, with OpenAPI spec generation.

**Architecture:** `ash_json_api` exposes existing Ash resources (Orders, new DeviceToken) through an `AshJsonApi.Router` forwarded from the Phoenix router behind two new plugs (bearer auth → Ash actor; `X-Store-ID` → Ash tenant). Auth endpoints (sign-in / refresh / sign-out) are hand-rolled controllers on AshAuthentication's `Merchant` password strategy with custom-purpose refresh tokens and rotation. Push reuses the existing provider-behaviour + Oban-worker conventions.

**Tech Stack:** Elixir/Phoenix 1.8, Ash 3.x, AshAuthentication 4.x, ash_json_api, open_api_spex, Req + Goth (FCM HTTP v1), Oban, Mox.

> **Amendment after Task 1:** pigeon 2.x is unresolvable in this dep graph (pigeon → httpoison → hackney `~> 1.x` vs ex_aws 2.7.0's `hackney ~> 4.0`). The production push provider is therefore a thin FCM HTTP v1 client on `req` + Goth — Task 12 below was rewritten accordingly; no `pigeon` dep, no `Emakola.FCM` dispatcher module.

**Spec:** `docs/superpowers/specs/2026-06-12-mobile-api-phase0-design.md`

---

## Verified API facts (do not re-derive; these were checked against the installed deps)

These determine the shape of the code below. If something doesn't compile, re-check here first.

1. `AshAuthentication.Jwt.token_for_user(user, extra_claims, opts)` returns `{:ok, token, claims} | :error`. `opts` accepts `purpose:` (atom, default `:user` — controls the **stored** purpose) and `token_lifetime:` which accepts `{15, :minutes}` / `{30, :days}` tuples. The purpose **claim** must be passed separately in `extra_claims` (`%{"purpose" => "..."}`); built-in sign-in does exactly this.
2. `token_for_user` only stores the token's jti in `Emakola.Accounts.Token` when `store_all_tokens?(true)` is set on the resource. Merchant currently does NOT set it (web logins use session subjects, no presence check), but `AshAuthentication.Plug.Helpers.retrieve_from_bearer/3` **requires** a stored record with purpose `"user"` because Merchant sets `require_token_presence_for_authentication?(true)`. → Task 2 enables `store_all_tokens?(true)`.
3. `retrieve_from_bearer(conn, :emakola)` verifies the JWT, checks jti presence (purpose `"user"` only — so refresh tokens are inherently rejected as access tokens), loads the user, and assigns `conn.assigns.current_<subject_name>`. Merchant's subject name is derived from the resource (expected `:merchant` → assign `:current_merchant`); Task 5's first test will confirm the assign name — if it differs, read `AshAuthentication.Info.authentication_subject_name(Emakola.Accounts.Merchant)` in a test to find it.
4. `AshAuthentication.TokenResource.Actions.revoke(Emakola.Accounts.Token, token)` **upserts** the jti row with purpose `"revoked"` — which simultaneously makes the presence check fail. Rotation and sign-out need nothing else.
5. `AshAuthentication.TokenResource.Actions.get_token(Token, %{"jti" => jti, "purpose" => "emakola_api_refresh"})` returns `{:ok, [record]}` only for live (non-rotated) refresh tokens.
6. `Jwt.verify(token, :emakola)` returns `{:ok, claims, resource}` — resource tells you which resource signed it (User tokens verify too! Always pattern-match `Emakola.Accounts.Merchant`).
7. Existing helpers: `Emakola.Factory.create_merchant_with_store!/1` returns `{merchant, store}` (password `"Password123!"`), `create_order!(store, attrs)`, `create_store_membership!(merchant, store, role)`. `EmakolaWeb.ConnCase.put_unique_peer_ip/1` isolates rate-limit buckets — **use it in every API test**. `Emakola.Notifications.Templates.format_amount/1` formats minor units.
8. Order policies already enforce merchant store-membership and default-deny nil actors. Order multitenancy: `strategy(:attribute)`, `attribute(:store_id)`, `global?(true)` — tenant is the store id (string ok).
9. Existing router pipelines: `:api` (JSON + 100 req/min rate limit), `:auth_rate_limit` (10 req/min). Reuse both.

**Implementer notes:**
- Always `require Ash.Query` at module level before using `Ash.Query.filter` (CLAUDE.md gotcha).
- After EVERY task: `mix format` before committing. Run `mix test <files>` for the task, and the full file you touched.
- For `ash_json_api`/`pigeon` DSL details beyond what's written here, consult hexdocs via the context7 MCP tools (`resolve-library-id` then `query-docs`) — do not guess option names.
- Migrations: `mix ash.codegen <name>` then inspect the generated migration, then `mix ecto.migrate`.

---

### Task 1: Dependencies + mime config

**Files:**
- Modify: `mix.exs` (deps list, after the Ash block ~line 88)
- Modify: `config/config.exs`

- [ ] **Step 1: Add deps to `mix.exs`**

After `{:ash_authentication_phoenix, "~> 2.0"},` add:

```elixir
      {:ash_json_api, "~> 1.4"},
      {:open_api_spex, "~> 3.16"},

      # Mobile push notifications (FCM HTTP v1)
      {:pigeon, "~> 2.0"},
      {:goth, "~> 1.4"},
```

- [ ] **Step 2: Add mime type config to `config/config.exs`** (anywhere near the top-level config, e.g. after the Ash domains block):

```elixir
# JSON:API content type (ash_json_api)
config :mime,
  types: %{"application/vnd.api+json" => ["json"]},
  extensions: %{"json" => "application/vnd.api+json"}
```

- [ ] **Step 3: Fetch and force-recompile mime**

Run: `mix deps.get && mix deps.compile mime --force && mix compile --warnings-as-errors`
Expected: compiles clean. (mime bakes its type table at compile time — the `--force` is required.)

- [ ] **Step 4: Run quick sanity test**

Run: `mix test test/emakola_web/controllers 2>/dev/null || mix test --max-failures 5 test/emakola_web`
Expected: PASS (no behavior change yet).

- [ ] **Step 5: Commit**

```bash
git add mix.exs mix.lock config/config.exs
git commit -m "chore(api): add ash_json_api, open_api_spex, pigeon, goth deps"
```

---

### Task 2: Enable token storage on Merchant (prereq for bearer auth)

**Files:**
- Modify: `lib/emakola/accounts/resources/merchant.ex:14-23` (authentication/tokens block)
- Test: `test/emakola/accounts/merchant_token_storage_test.exs` (create)

- [ ] **Step 1: Write the failing test**

```elixir
defmodule Emakola.Accounts.MerchantTokenStorageTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.Merchant

  require Ash.Query

  test "password sign-in stores the issued token (presence check prerequisite)" do
    merchant = create_merchant!(%{password: "Password123!"})

    strategy = Info.strategy!(Merchant, :password)

    {:ok, signed_in} =
      Strategy.action(strategy, :sign_in, %{
        email: to_string(merchant.email),
        password: "Password123!"
      })

    token = signed_in.__metadata__.token
    assert is_binary(token)

    {:ok, %{"jti" => jti}, Merchant} = AshAuthentication.Jwt.verify(token, :emakola)

    {:ok, records} =
      AshAuthentication.TokenResource.Actions.get_token(
        Emakola.Accounts.Token,
        %{"jti" => jti, "purpose" => "user"}
      )

    assert [_record] = records
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/accounts/merchant_token_storage_test.exs`
Expected: FAIL — `get_token` returns `{:ok, []}` (token not stored because `store_all_tokens?` defaults to false).

- [ ] **Step 3: Enable storage in `merchant.ex`**

In the `authentication do ... tokens do` block, after `enabled?(true)`:

```elixir
    tokens do
      enabled?(true)
      token_resource(Emakola.Accounts.Token)
      store_all_tokens?(true)
      require_token_presence_for_authentication?(true)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/emakola/accounts/merchant_token_storage_test.exs`
Expected: PASS

- [ ] **Step 5: Run the existing accounts + auth web tests for regressions**

Run: `mix test test/emakola/accounts test/emakola_web/live/auth`
Expected: PASS (web session flow is unaffected; tokens are now additionally stored — the existing token expunger cleans expired rows).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/accounts/resources/merchant.ex test/emakola/accounts/merchant_token_storage_test.exs
git commit -m "feat(auth): store merchant tokens for API bearer presence checks"
```

---

### Task 3: `Emakola.Accounts.ApiTokens` — token pair service

**Files:**
- Create: `lib/emakola/accounts/api_tokens.ex`
- Test: `test/emakola/accounts/api_tokens_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Emakola.Accounts.ApiTokensTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.{ApiTokens, Merchant}

  describe "issue_pair/1" do
    test "returns access + refresh tokens with expiry" do
      merchant = create_merchant!()

      assert {:ok, pair} = ApiTokens.issue_pair(merchant)
      assert is_binary(pair.access_token)
      assert is_binary(pair.refresh_token)
      assert pair.expires_in == 900

      # Access token: purpose "user", verifiable, stored (presence check passes)
      assert {:ok, %{"purpose" => "user"}, Merchant} =
               AshAuthentication.Jwt.verify(pair.access_token, :emakola)

      # Refresh token: custom purpose
      assert {:ok, %{"purpose" => "emakola_api_refresh"}, Merchant} =
               AshAuthentication.Jwt.verify(pair.refresh_token, :emakola)
    end
  end

  describe "exchange_refresh/1" do
    test "issues a new pair and revokes the presented refresh token (rotation)" do
      merchant = create_merchant!()
      {:ok, pair} = ApiTokens.issue_pair(merchant)

      assert {:ok, new_pair} = ApiTokens.exchange_refresh(pair.refresh_token)
      assert new_pair.access_token != pair.access_token

      # Replaying the old refresh token fails
      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh(pair.refresh_token)

      # The new refresh token still works
      assert {:ok, _} = ApiTokens.exchange_refresh(new_pair.refresh_token)
    end

    test "rejects an access token used as refresh token" do
      merchant = create_merchant!()
      {:ok, pair} = ApiTokens.issue_pair(merchant)

      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh(pair.access_token)
    end

    test "rejects garbage" do
      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh("not-a-jwt")
    end
  end

  describe "revoke/1" do
    test "revoked refresh token can no longer be exchanged" do
      merchant = create_merchant!()
      {:ok, pair} = ApiTokens.issue_pair(merchant)

      assert :ok = ApiTokens.revoke(pair.refresh_token)
      assert {:error, :invalid_refresh_token} = ApiTokens.exchange_refresh(pair.refresh_token)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/accounts/api_tokens_test.exs`
Expected: FAIL — `Emakola.Accounts.ApiTokens` is undefined.

- [ ] **Step 3: Implement**

```elixir
defmodule Emakola.Accounts.ApiTokens do
  @moduledoc """
  Issues, rotates, and revokes bearer token pairs for the mobile/JSON API.

  Access tokens are standard AshAuthentication user tokens (purpose `"user"`,
  15 minutes) so `AshAuthentication.Plug.Helpers.retrieve_from_bearer/3`
  validates them with presence + revocation checks against the tokens table.

  Refresh tokens carry purpose `"emakola_api_refresh"` (30 days) and are
  rotated on every exchange: the presented token's jti is revoked (upserted
  to purpose `"revoked"`) before a new pair is issued, so replay fails.
  """

  alias AshAuthentication.{Jwt, TokenResource.Actions}
  alias Emakola.Accounts.{Merchant, Token}

  @refresh_purpose "emakola_api_refresh"
  @access_lifetime {15, :minutes}
  @refresh_lifetime {30, :days}
  @access_lifetime_seconds 900

  @spec issue_pair(Merchant.t() | struct()) ::
          {:ok, %{access_token: String.t(), refresh_token: String.t(), expires_in: pos_integer()}}
          | {:error, :token_generation_failed}
  def issue_pair(%Merchant{} = merchant) do
    with {:ok, access, _claims} <-
           Jwt.token_for_user(merchant, %{"purpose" => "user"},
             token_lifetime: @access_lifetime
           ),
         {:ok, refresh, _claims} <-
           Jwt.token_for_user(merchant, %{"purpose" => @refresh_purpose},
             purpose: String.to_atom(@refresh_purpose),
             token_lifetime: @refresh_lifetime
           ) do
      {:ok,
       %{
         access_token: access,
         refresh_token: refresh,
         expires_in: @access_lifetime_seconds
       }}
    else
      _ -> {:error, :token_generation_failed}
    end
  end

  @spec exchange_refresh(String.t()) ::
          {:ok, %{access_token: String.t(), refresh_token: String.t(), expires_in: pos_integer()}}
          | {:error, :invalid_refresh_token}
  def exchange_refresh(refresh_token) when is_binary(refresh_token) do
    with {:ok, %{"purpose" => @refresh_purpose, "jti" => jti, "sub" => subject}, Merchant} <-
           Jwt.verify(refresh_token, :emakola),
         {:ok, [_live_record]} <-
           Actions.get_token(Token, %{"jti" => jti, "purpose" => @refresh_purpose}),
         {:ok, merchant} <- AshAuthentication.subject_to_user(subject, Merchant),
         :ok <- Actions.revoke(Token, refresh_token),
         {:ok, pair} <- issue_pair(merchant) do
      {:ok, pair}
    else
      _ -> {:error, :invalid_refresh_token}
    end
  end

  @spec revoke(String.t()) :: :ok
  def revoke(token) when is_binary(token) do
    case Actions.revoke(Token, token) do
      :ok -> :ok
      # Revoking an invalid/garbage token is a no-op success: the caller is
      # discarding credentials; there is nothing to protect.
      {:error, _} -> :ok
    end
  end
end
```

Note: `String.to_atom(@refresh_purpose)` is a compile-time-known constant — not user input, so the SafeAtom rule does not apply.

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/emakola/accounts/api_tokens_test.exs`
Expected: PASS (4 tests). If the `purpose:` opt errors because `Jwt.token_for_user` requires an atom vs string, check the failure message — the stored-purpose opt is popped as-is and stringified during storage.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/accounts/api_tokens.ex test/emakola/accounts/api_tokens_test.exs
git commit -m "feat(auth): ApiTokens service - bearer pair issue/refresh-rotate/revoke"
```

---

### Task 4: Auth endpoints — sign_in / refresh / sign_out

**Files:**
- Create: `lib/emakola_web/controllers/api/auth_controller.ex`
- Modify: `lib/emakola_web/router.ex` (new scope, after the `/webhooks` scopes ~line 65)
- Test: `test/emakola_web/controllers/api/auth_controller_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.Api.AuthControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    merchant = create_merchant!(%{password: "Password123!"})
    {:ok, conn: put_unique_peer_ip(conn), merchant: merchant}
  end

  describe "POST /api/v1/auth/sign_in" do
    test "returns token pair for valid credentials", %{conn: conn, merchant: merchant} do
      conn =
        post(conn, ~p"/api/v1/auth/sign_in", %{
          "email" => to_string(merchant.email),
          "password" => "Password123!"
        })

      assert %{
               "data" => %{
                 "access_token" => access,
                 "refresh_token" => refresh,
                 "expires_in" => 900,
                 "merchant" => %{"id" => id, "email" => _}
               }
             } = json_response(conn, 200)

      assert id == merchant.id
      assert is_binary(access) and is_binary(refresh)
    end

    test "401 with opaque error for wrong password", %{conn: conn, merchant: merchant} do
      conn =
        post(conn, ~p"/api/v1/auth/sign_in", %{
          "email" => to_string(merchant.email),
          "password" => "wrong"
        })

      assert %{"errors" => [%{"status" => "401", "code" => "invalid_credentials"}]} =
               json_response(conn, 401)
    end

    test "401 for unknown email (no account enumeration)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/auth/sign_in", %{
          "email" => "nobody@example.com",
          "password" => "Password123!"
        })

      assert %{"errors" => [%{"code" => "invalid_credentials"}]} = json_response(conn, 401)
    end

    test "422 when params are missing", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/sign_in", %{})
      assert %{"errors" => [%{"status" => "422"}]} = json_response(conn, 422)
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "rotates the pair", %{conn: conn, merchant: merchant} do
      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn1 = post(conn, ~p"/api/v1/auth/refresh", %{"refresh_token" => pair.refresh_token})
      assert %{"data" => %{"access_token" => _, "refresh_token" => new_refresh}} =
               json_response(conn1, 200)

      # Old refresh token is dead
      conn2 =
        build_conn()
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/auth/refresh", %{"refresh_token" => pair.refresh_token})

      assert json_response(conn2, 401)

      # New one works
      conn3 =
        build_conn()
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/auth/refresh", %{"refresh_token" => new_refresh})

      assert json_response(conn3, 200)
    end

    test "401 for garbage", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/auth/refresh", %{"refresh_token" => "garbage"})
      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    test "revokes the refresh token", %{conn: conn, merchant: merchant} do
      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn1 = delete(conn, ~p"/api/v1/auth/sign_out", %{"refresh_token" => pair.refresh_token})
      assert response(conn1, 204)

      conn2 =
        build_conn()
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/auth/refresh", %{"refresh_token" => pair.refresh_token})

      assert json_response(conn2, 401)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/controllers/api/auth_controller_test.exs`
Expected: FAIL — no route matches `/api/v1/auth/sign_in`.

- [ ] **Step 3: Implement controller**

```elixir
defmodule EmakolaWeb.Api.AuthController do
  use EmakolaWeb, :controller

  alias AshAuthentication.{Info, Strategy}
  alias Emakola.Accounts.{ApiTokens, Merchant}

  def sign_in(conn, %{"email" => email, "password" => password})
      when is_binary(email) and is_binary(password) do
    strategy = Info.strategy!(Merchant, :password)

    with {:ok, merchant} <-
           Strategy.action(strategy, :sign_in, %{email: email, password: password}),
         {:ok, pair} <- ApiTokens.issue_pair(merchant) do
      json(conn, %{
        data: %{
          access_token: pair.access_token,
          refresh_token: pair.refresh_token,
          expires_in: pair.expires_in,
          merchant: %{
            id: merchant.id,
            email: to_string(merchant.email),
            name: merchant.name,
            business_name: merchant.business_name
          }
        }
      })
    else
      _ -> error(conn, 401, "invalid_credentials", "Invalid email or password")
    end
  end

  def sign_in(conn, _params),
    do: error(conn, 422, "missing_params", "email and password are required")

  def refresh(conn, %{"refresh_token" => token}) when is_binary(token) do
    case ApiTokens.exchange_refresh(token) do
      {:ok, pair} -> json(conn, %{data: pair})
      {:error, _} -> error(conn, 401, "invalid_refresh_token", "Refresh token is invalid or expired")
    end
  end

  def refresh(conn, _params),
    do: error(conn, 422, "missing_params", "refresh_token is required")

  def sign_out(conn, params) do
    case params["refresh_token"] do
      token when is_binary(token) -> ApiTokens.revoke(token)
      _ -> :ok
    end

    send_resp(conn, 204, "")
  end

  defp error(conn, status, code, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), code: code, detail: detail}]})
  end
end
```

- [ ] **Step 4: Add routes to `lib/emakola_web/router.ex`** (after the `/webhooks` paystack scope):

```elixir
  # Mobile/JSON API auth — bearer token pair lifecycle. Strict rate limit:
  # sign_in is a brute-force vector, refresh a replay-probe vector.
  scope "/api/v1/auth", EmakolaWeb.Api do
    pipe_through [:api, :auth_rate_limit]

    post "/sign_in", AuthController, :sign_in
    post "/refresh", AuthController, :refresh
    delete "/sign_out", AuthController, :sign_out
  end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/emakola_web/controllers/api/auth_controller_test.exs`
Expected: PASS (8 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/controllers/api/auth_controller.ex lib/emakola_web/router.ex test/emakola_web/controllers/api/auth_controller_test.exs
git commit -m "feat(api): auth endpoints - sign_in, refresh (rotating), sign_out"
```

---

### Task 5: `ApiBearerAuth` plug

**Files:**
- Create: `lib/emakola_web/plugs/api_bearer_auth.ex`
- Test: `test/emakola_web/plugs/api_bearer_auth_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.Plugs.ApiBearerAuthTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.Plugs.ApiBearerAuth

  defp call(conn) do
    conn
    |> Plug.Conn.put_private(:phoenix_endpoint, @endpoint)
    |> ApiBearerAuth.call(ApiBearerAuth.init([]))
  end

  test "valid access token sets the merchant as Ash actor", %{conn: conn} do
    merchant = create_merchant!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> call()

    refute conn.halted
    assert %Emakola.Accounts.Merchant{} = actor = Ash.PlugHelpers.get_actor(conn)
    assert actor.id == merchant.id
  end

  test "missing header → 401 JSON:API error", %{conn: conn} do
    conn = call(conn)

    assert conn.halted
    assert conn.status == 401
    assert %{"errors" => [%{"status" => "401"}]} = Jason.decode!(conn.resp_body)
  end

  test "garbage token → 401", %{conn: conn} do
    conn = conn |> put_req_header("authorization", "Bearer garbage") |> call()
    assert conn.halted
    assert conn.status == 401
  end

  test "refresh token used as access token → 401", %{conn: conn} do
    merchant = create_merchant!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn = conn |> put_req_header("authorization", "Bearer #{pair.refresh_token}") |> call()
    assert conn.halted
    assert conn.status == 401
  end

  test "revoked access token → 401", %{conn: conn} do
    merchant = create_merchant!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    :ok =
      AshAuthentication.TokenResource.Actions.revoke(
        Emakola.Accounts.Token,
        pair.access_token
      )

    conn = conn |> put_req_header("authorization", "Bearer #{pair.access_token}") |> call()
    assert conn.halted
    assert conn.status == 401
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/plugs/api_bearer_auth_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 3: Implement**

```elixir
defmodule EmakolaWeb.Plugs.ApiBearerAuth do
  @moduledoc """
  Authenticates `/api/v1` requests via `Authorization: Bearer <access token>`.

  Delegates verification to `AshAuthentication.Plug.Helpers.retrieve_from_bearer/3`
  (signature, expiry, jti presence with purpose "user", revocation), then
  promotes the loaded merchant to the Ash actor. Tokens signed for other
  resources (e.g. platform staff Users) do not produce a `current_merchant`
  assign and are rejected.
  """

  @behaviour Plug

  import Plug.Conn

  alias AshAuthentication.Plug.Helpers

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = Helpers.retrieve_from_bearer(conn, :emakola)

    case conn.assigns[:current_merchant] do
      %Emakola.Accounts.Merchant{} = merchant ->
        Ash.PlugHelpers.set_actor(conn, merchant)

      _ ->
        conn
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(
          401,
          Jason.encode!(%{
            errors: [
              %{status: "401", code: "unauthorized", detail: "Invalid or expired access token"}
            ]
          })
        )
        |> halt()
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/emakola_web/plugs/api_bearer_auth_test.exs`
Expected: PASS (5 tests). If the actor test fails with a nil actor but no 401, the subject name isn't `:merchant` — inspect `AshAuthentication.Info.authentication_subject_name(Emakola.Accounts.Merchant)` and adjust the assign key.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/plugs/api_bearer_auth.ex test/emakola_web/plugs/api_bearer_auth_test.exs
git commit -m "feat(api): bearer auth plug - merchant actor from access token"
```

---

### Task 6: `ApiTenant` plug

**Files:**
- Create: `lib/emakola_web/plugs/api_tenant.ex`
- Test: `test/emakola_web/plugs/api_tenant_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.Plugs.ApiTenantTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.Plugs.ApiTenant

  defp call_with_actor(conn, merchant) do
    conn
    |> Ash.PlugHelpers.set_actor(merchant)
    |> ApiTenant.call(ApiTenant.init([]))
  end

  test "member store id sets the Ash tenant", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()

    conn =
      conn
      |> put_req_header("x-store-id", store.id)
      |> call_with_actor(merchant)

    refute conn.halted
    assert Ash.PlugHelpers.get_tenant(conn) == store.id
  end

  test "missing header → 403", %{conn: conn} do
    {merchant, _store} = create_merchant_with_store!()
    conn = call_with_actor(conn, merchant)

    assert conn.halted
    assert conn.status == 403
    assert %{"errors" => [%{"status" => "403"}]} = Jason.decode!(conn.resp_body)
  end

  test "store the merchant is NOT a member of → 403", %{conn: conn} do
    {merchant, _own_store} = create_merchant_with_store!()
    other_store = create_store!()

    conn =
      conn
      |> put_req_header("x-store-id", other_store.id)
      |> call_with_actor(merchant)

    assert conn.halted
    assert conn.status == 403
  end

  test "non-UUID header → 403", %{conn: conn} do
    {merchant, _store} = create_merchant_with_store!()

    conn =
      conn
      |> put_req_header("x-store-id", "not-a-uuid")
      |> call_with_actor(merchant)

    assert conn.halted
    assert conn.status == 403
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/plugs/api_tenant_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 3: Implement**

```elixir
defmodule EmakolaWeb.Plugs.ApiTenant do
  @moduledoc """
  Resolves the Ash tenant for `/api/v1` requests from the `X-Store-ID` header.

  The store id must belong to a store the authenticated merchant (the Ash
  actor, set by `ApiBearerAuth`) is a member of. Anything else — missing
  header, malformed UUID, or a store the merchant has no membership in —
  is a uniform 403 so the API does not leak which store ids exist.
  """

  @behaviour Plug

  import Plug.Conn

  require Ash.Query

  alias Emakola.Accounts.{Merchant, StoreMembership}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with %Merchant{} = merchant <- Ash.PlugHelpers.get_actor(conn),
         [store_id] <- get_req_header(conn, "x-store-id"),
         {:ok, _uuid} <- Ecto.UUID.cast(store_id),
         true <- member?(merchant, store_id) do
      Ash.PlugHelpers.set_tenant(conn, store_id)
    else
      _ ->
        conn
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(
          403,
          Jason.encode!(%{
            errors: [
              %{
                status: "403",
                code: "forbidden",
                detail: "X-Store-ID header missing or store not accessible"
              }
            ]
          })
        )
        |> halt()
    end
  end

  defp member?(%Merchant{id: merchant_id}, store_id) do
    StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.exists?(authorize?: false)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/emakola_web/plugs/api_tenant_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/emakola_web/plugs/api_tenant.ex test/emakola_web/plugs/api_tenant_test.exs
git commit -m "feat(api): tenant plug - X-Store-ID validated against store membership"
```

---

### Task 7: `GET /api/v1/stores` + router pipelines

**Files:**
- Create: `lib/emakola_web/controllers/api/store_controller.ex`
- Modify: `lib/emakola_web/router.ex` (pipelines + scope)
- Test: `test/emakola_web/controllers/api/store_controller_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.Api.StoreControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  describe "GET /api/v1/stores" do
    test "lists only the merchant's stores with role", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      _other_store = create_store!()

      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn =
        conn
        |> put_unique_peer_ip()
        |> put_req_header("authorization", "Bearer #{pair.access_token}")
        |> get(~p"/api/v1/stores")

      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["id"] == store.id
      assert entry["role"] == "owner"
      assert is_binary(entry["name"]) and is_binary(entry["slug"])
      assert entry["currency"] == "GHS"
    end

    test "401 without a token", %{conn: conn} do
      conn = conn |> put_unique_peer_ip() |> get(~p"/api/v1/stores")
      assert json_response(conn, 401)
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/controllers/api/store_controller_test.exs`
Expected: FAIL — no route.

- [ ] **Step 3: Implement controller**

```elixir
defmodule EmakolaWeb.Api.StoreController do
  use EmakolaWeb, :controller

  require Ash.Query

  alias Emakola.Accounts.StoreMembership

  def index(conn, _params) do
    merchant = Ash.PlugHelpers.get_actor(conn)

    memberships =
      StoreMembership
      |> Ash.Query.filter(merchant_id == ^merchant.id)
      |> Ash.Query.load(:store)
      |> Ash.read!(authorize?: false)

    json(conn, %{
      data:
        Enum.map(memberships, fn m ->
          %{
            id: m.store.id,
            name: m.store.name,
            slug: m.store.slug,
            currency: m.store.currency,
            role: m.role
          }
        end)
    })
  end
end
```

- [ ] **Step 4: Add pipelines and scope to `lib/emakola_web/router.ex`**

After the `:auth_rate_limit` pipeline definition:

```elixir
  # Mobile/JSON API: bearer-token merchant auth, then X-Store-ID tenant.
  pipeline :api_bearer do
    plug EmakolaWeb.Plugs.ApiBearerAuth
  end

  pipeline :api_tenant do
    plug EmakolaWeb.Plugs.ApiTenant
  end
```

After the `/api/v1/auth` scope from Task 4:

```elixir
  # Authenticated, NOT tenant-scoped — used to discover/pick a store.
  scope "/api/v1", EmakolaWeb.Api do
    pipe_through [:api, :api_bearer]

    get "/stores", StoreController, :index
  end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/emakola_web/controllers/api/store_controller_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola_web/controllers/api/store_controller.ex lib/emakola_web/router.ex test/emakola_web/controllers/api/store_controller_test.exs
git commit -m "feat(api): GET /api/v1/stores - merchant store picker endpoint"
```

---

### Task 8: Orders JSON:API — list + detail

**Files:**
- Modify: `lib/emakola/orders/resources/order.ex` (extension, json_api block, new read action)
- Modify: `lib/emakola/orders/orders.ex` (domain — add AshJsonApi.Domain extension)
- Create: `lib/emakola_web/api_router.ex`
- Modify: `lib/emakola_web/router.ex` (forward)
- Test: `test/emakola_web/controllers/api/order_endpoints_test.exs`

**Before coding:** consult ash_json_api docs (context7: `resolve-library-id` "ash_json_api", then `query-docs` for "routes DSL patch route open_api domain extension"). The DSL below follows current docs; verify option names if compile fails.

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.Api.OrderEndpointsTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store.id)
      |> put_req_header("accept", "application/vnd.api+json")

    {:ok, conn: conn, merchant: merchant, store: store}
  end

  describe "GET /api/v1/orders" do
    test "lists the store's orders newest-first", %{conn: conn, store: store} do
      order1 = create_order!(store)
      order2 = create_order!(store)

      conn = get(conn, "/api/v1/orders")

      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.map(data, & &1["id"]) == [order2.id, order1.id]
      assert [%{"type" => "order", "attributes" => attrs} | _] = data
      assert attrs["order_number"] =~ "ORD-"
      assert attrs["status"] == "pending"
    end

    test "filters by status", %{conn: conn, store: store} do
      _pending = create_order!(store)
      confirmed = create_order!(store, %{status: :confirmed})

      conn = get(conn, "/api/v1/orders?filter[status]=confirmed")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == confirmed.id
    end

    test "paginates", %{conn: conn, store: store} do
      for _ <- 1..3, do: create_order!(store)

      conn = get(conn, "/api/v1/orders?page[limit]=2")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 2
    end

    test "401 without token", %{store: store} do
      conn =
        build_conn()
        |> put_unique_peer_ip()
        |> put_req_header("x-store-id", store.id)
        |> get("/api/v1/orders")

      assert conn.status == 401
    end
  end

  describe "GET /api/v1/orders/:id" do
    test "returns the order", %{conn: conn, store: store} do
      order = create_order!(store)

      conn = get(conn, "/api/v1/orders/#{order.id}")

      assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 200)
      assert id == order.id
      assert attrs["currency"] == "GHS"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/orders/#{Ash.UUID.generate()}")
      assert conn.status == 404
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/controllers/api/order_endpoints_test.exs`
Expected: FAIL — no route.

- [ ] **Step 3: Add the API read action to Order** (`lib/emakola/orders/resources/order.ex`, inside `actions do`):

```elixir
    read :api_list do
      description("Mobile API order list — tenant-scoped, newest first.")

      argument(:status, :atom,
        allow_nil?: true,
        constraints: [
          one_of: [:pending, :confirmed, :processing, :shipped, :delivered, :cancelled]
        ]
      )

      filter(expr(is_nil(^arg(:status)) or status == ^arg(:status)))
      prepare(build(sort: [inserted_at: :desc]))

      pagination(offset?: true, keyset?: true, countable: true, default_limit: 25)
    end
```

- [ ] **Step 4: Add the json_api block to Order**

Add `AshJsonApi.Resource` to the resource's `extensions:` list (alongside the existing ones), then add at resource top level (near `multitenancy`):

```elixir
  json_api do
    type "order"

    routes do
      base("/orders")

      index(:api_list)
      get(:get_by_id)
    end
  end
```

Check which Order attributes are `public?` — JSON:API serializes public attributes. `order_number`, `status`, `subtotal`, `total`, `delivery_fee`, `discount_amount`, `currency`, `customer_name`/contact fields (whatever exists), `shipping_address`, `inserted_at` must be public for the app to render an order. Add `public?(true)` to any that are missing it (additive — web is unaffected).

- [ ] **Step 5: Add the domain extension** (`lib/emakola/orders/orders.ex`):

Change `use Ash.Domain` to include the extension and add the prefix:

```elixir
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    prefix("/api/v1")
  end
```

(Match however the domain currently declares `use Ash.Domain` — only add the extension and block, change nothing else.)

- [ ] **Step 6: Create the API router** (`lib/emakola_web/api_router.ex`):

```elixir
defmodule EmakolaWeb.ApiRouter do
  @moduledoc """
  JSON:API router for /api/v1 (ash_json_api). Mounted behind ApiBearerAuth +
  ApiTenant in the Phoenix router — actor and tenant arrive via
  Ash.PlugHelpers conn assigns.
  """

  use AshJsonApi.Router,
    domains: [Emakola.Orders],
    open_api: "/open_api"
end
```

- [ ] **Step 7: Forward from the Phoenix router** (after the `/api/v1` stores scope):

```elixir
  # Tenant-scoped JSON:API resources (orders, device tokens).
  scope "/api/v1" do
    pipe_through [:api, :api_bearer, :api_tenant]

    forward "/", EmakolaWeb.ApiRouter
  end
```

- [ ] **Step 8: Run tests, iterate until green**

Run: `mix test test/emakola_web/controllers/api/order_endpoints_test.exs`
Expected: PASS (6 tests). Likely friction points: attribute `public?` flags (404s/missing attributes), the JSON:API filter syntax for action arguments (`filter[status]` maps to the `:status` argument — if it doesn't, check ash_json_api docs for `derive_filter?`/argument handling on index routes).

- [ ] **Step 9: Run the full orders test directory for regressions**

Run: `mix test test/emakola/orders test/emakola_web/live/admin`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/emakola/orders/ lib/emakola_web/api_router.ex lib/emakola_web/router.ex test/emakola_web/controllers/api/order_endpoints_test.exs
git commit -m "feat(api): JSON:API order list/detail endpoints via ash_json_api"
```

---

### Task 9: Order status-transition endpoints

**Files:**
- Modify: `lib/emakola/orders/resources/order.ex` (json_api routes)
- Test: `test/emakola_web/controllers/api/order_transitions_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule EmakolaWeb.Api.OrderTransitionsTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store.id)
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, store: store}
  end

  defp patch_transition(conn, order, transition) do
    patch(conn, "/api/v1/orders/#{order.id}/#{transition}", %{
      "data" => %{"type" => "order", "id" => order.id, "attributes" => %{}}
    })
  end

  test "confirm: pending → confirmed", %{conn: conn, store: store} do
    order = create_order!(store)

    conn = patch_transition(conn, order, "confirm")

    assert %{"data" => %{"attributes" => %{"status" => "confirmed"}}} =
             json_response(conn, 200)
  end

  test "full lifecycle: confirm → start_processing → mark_shipped → mark_delivered",
       %{conn: conn, store: store} do
    order = create_order!(store)

    for {transition, expected} <- [
          {"confirm", "confirmed"},
          {"start_processing", "processing"},
          {"mark_shipped", "shipped"},
          {"mark_delivered", "delivered"}
        ] do
      conn = patch_transition(conn, order, transition)
      assert %{"data" => %{"attributes" => %{"status" => ^expected}}} = json_response(conn, 200)
    end
  end

  test "cancel a pending order", %{conn: conn, store: store} do
    order = create_order!(store)

    conn = patch_transition(conn, order, "cancel")
    assert %{"data" => %{"attributes" => %{"status" => "cancelled"}}} = json_response(conn, 200)
  end

  test "invalid transition (deliver a pending order) → 4xx error, status unchanged",
       %{conn: conn, store: store} do
    order = create_order!(store)

    conn = patch_transition(conn, order, "mark_delivered")
    assert conn.status in [400, 409, 422]

    reloaded = Ash.get!(Emakola.Orders.Order, order.id, authorize?: false, tenant: store.id)
    assert reloaded.status == :pending
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola_web/controllers/api/order_transitions_test.exs`
Expected: FAIL — 404 (routes missing).

- [ ] **Step 3: Add the transition routes** to Order's `json_api > routes` block (from Task 8):

```elixir
      patch(:confirm, route: "/:id/confirm")
      patch(:start_processing, route: "/:id/start_processing")
      patch(:mark_shipped, route: "/:id/mark_shipped")
      patch(:mark_delivered, route: "/:id/mark_delivered")
      patch(:cancel, route: "/:id/cancel")
```

- [ ] **Step 4: Run tests, iterate until green**

Run: `mix test test/emakola_web/controllers/api/order_transitions_test.exs`
Expected: PASS (4 tests). Notes: the transition actions dispatch notifications via after-action hooks (`Dispatcher.dispatch/2` never raises — safe in tests, jobs land in the Oban sandbox). If the transition actions require arguments (check `mark_shipped` for tracking fields), pass them in the test's `attributes` map.

- [ ] **Step 5: Commit**

```bash
git add lib/emakola/orders/resources/order.ex test/emakola_web/controllers/api/order_transitions_test.exs
git commit -m "feat(api): order status transition endpoints"
```

---

### Task 10: Multi-tenant isolation integration suite (mandatory per spec)

**Files:**
- Test: `test/emakola_web/controllers/api/tenant_isolation_test.exs` (create only — this task should require NO production code changes; if a test fails, that's a real vulnerability: stop and fix it in the responsible module)

- [ ] **Step 1: Write the tests**

```elixir
defmodule EmakolaWeb.Api.TenantIsolationTest do
  @moduledoc """
  Multi-tenant isolation guarantees for the mobile API. Every test here is a
  security invariant: merchant A must never read or mutate store B's data,
  even with a valid token and a forged X-Store-ID.
  """
  use EmakolaWeb.ConnCase, async: true

  @moduletag :integration

  import Emakola.Factory

  setup %{conn: conn} do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()
    {:ok, pair_a} = Emakola.Accounts.ApiTokens.issue_pair(merchant_a)

    base =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair_a.access_token}")
      |> put_req_header("accept", "application/vnd.api+json")

    {:ok,
     conn: base,
     merchant_a: merchant_a,
     store_a: store_a,
     merchant_b: merchant_b,
     store_b: store_b}
  end

  test "forged X-Store-ID for a non-member store → 403", %{conn: conn, store_b: store_b} do
    conn = conn |> put_req_header("x-store-id", store_b.id) |> get("/api/v1/orders")
    assert conn.status == 403
  end

  test "own store list never contains another store's orders",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    _own = create_order!(store_a)
    foreign = create_order!(store_b)

    conn = conn |> put_req_header("x-store-id", store_a.id) |> get("/api/v1/orders")

    assert %{"data" => data} = json_response(conn, 200)
    refute foreign.id in Enum.map(data, & &1["id"])
  end

  test "fetching a foreign order id under own tenant → 404 (no existence leak)",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    foreign = create_order!(store_b)

    conn =
      conn
      |> put_req_header("x-store-id", store_a.id)
      |> get("/api/v1/orders/#{foreign.id}")

    assert conn.status == 404
  end

  test "transitioning a foreign order under own tenant fails and does not mutate",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    foreign = create_order!(store_b)

    conn =
      conn
      |> put_req_header("x-store-id", store_a.id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/v1/orders/#{foreign.id}/confirm", %{
        "data" => %{"type" => "order", "id" => foreign.id, "attributes" => %{}}
      })

    assert conn.status in [403, 404]

    reloaded =
      Ash.get!(Emakola.Orders.Order, foreign.id, authorize?: false, tenant: store_b.id)

    assert reloaded.status == :pending
  end

  test "merchant B's token cannot use store A's tenant", %{store_a: store_a, merchant_b: merchant_b} do
    {:ok, pair_b} = Emakola.Accounts.ApiTokens.issue_pair(merchant_b)

    conn =
      build_conn()
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair_b.access_token}")
      |> put_req_header("x-store-id", store_a.id)
      |> get("/api/v1/orders")

    assert conn.status == 403
  end
end
```

- [ ] **Step 2: Run the suite**

Run: `mix test test/emakola_web/controllers/api/tenant_isolation_test.exs`
Expected: PASS with zero production changes. **If any test fails, do not weaken the test** — the plug or policy has a hole; fix the production code and explain the fix in the commit message.

- [ ] **Step 3: Commit**

```bash
git add test/emakola_web/controllers/api/tenant_isolation_test.exs
git commit -m "test(api): multi-tenant isolation integration suite"
```

---

### Task 11: DeviceToken resource + registration endpoints

**Files:**
- Create: `lib/emakola/notifications/resources/device_token.ex`
- Modify: `lib/emakola/notifications/notifications.ex` (register resource in domain, add AshJsonApi.Domain extension + prefix, mirroring Task 8 Step 5)
- Modify: `lib/emakola_web/api_router.ex` (add domain)
- Migration: via `mix ash.codegen add_device_tokens`
- Test: `test/emakola/notifications/device_token_test.exs`, `test/emakola_web/controllers/api/device_token_endpoints_test.exs`

- [ ] **Step 1: Write the failing resource tests**

```elixir
defmodule Emakola.Notifications.DeviceTokenTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Notifications.DeviceToken

  defp register!(merchant, store, attrs) do
    DeviceToken
    |> Ash.Changeset.for_create(:register, attrs, actor: merchant, tenant: store.id)
    |> Ash.create!()
  end

  test "register creates a device token owned by the actor" do
    {merchant, store} = create_merchant_with_store!()

    dt = register!(merchant, store, %{platform: :android, token: "fcm-token-1"})

    assert dt.merchant_id == merchant.id
    assert dt.store_id == store.id
    assert dt.platform == :android
    assert %DateTime{} = dt.last_seen_at
  end

  test "re-registering the same token upserts (no duplicate) and refreshes ownership" do
    {merchant_a, store} = create_merchant_with_store!()
    merchant_b = create_merchant!()
    create_store_membership!(merchant_b, store, :staff)

    register!(merchant_a, store, %{platform: :android, token: "shared-device"})
    dt2 = register!(merchant_b, store, %{platform: :android, token: "shared-device"})

    assert dt2.merchant_id == merchant_b.id

    all = Ash.read!(DeviceToken, authorize?: false, tenant: store.id)
    assert length(all) == 1
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/notifications/device_token_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 3: Implement the resource**

```elixir
defmodule Emakola.Notifications.DeviceToken do
  @moduledoc """
  FCM registration token for a merchant's mobile device. One row per device
  token; re-registration upserts (devices are shared and change owners).
  Flutter's firebase_messaging issues FCM tokens on both Android and iOS,
  so this is FCM-only — `platform` is informational.
  """

  use Ash.Resource,
    domain: Emakola.Notifications,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("device_tokens")
    repo(Emakola.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  json_api do
    type "device_token"

    routes do
      base("/device_tokens")

      post(:register)
      delete(:destroy)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
    end

    attribute :platform, :atom do
      constraints(one_of: [:android, :ios])
      allow_nil?(false)
      public?(true)
    end

    attribute :token, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 4096)
    end

    attribute(:last_seen_at, :utc_datetime_usec, public?: true)

    timestamps()
  end

  relationships do
    belongs_to :merchant, Emakola.Accounts.Merchant do
      allow_nil?(false)
    end
  end

  identities do
    identity(:unique_token, [:token], all_tenants?: true)
  end

  policies do
    # Merchant actors with membership in the tenant store may register/read.
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    # Destroy additionally requires owning the token row.
    policy action_type(:destroy) do
      authorize_if(expr(merchant_id == ^actor(:id)))
    end
  end

  actions do
    defaults([:read])

    create :register do
      accept([:platform, :token])

      upsert?(true)
      upsert_identity(:unique_token)
      upsert_fields([:merchant_id, :platform, :last_seen_at, :store_id])

      change(relate_actor(:merchant))
      change(set_attribute(:last_seen_at, &DateTime.utc_now/0))
    end

    destroy :destroy do
      primary?(true)
    end

    read :for_store do
      description("All device tokens for a store — used by the push worker (authorize?: false).")
    end
  end
end
```

Note: `identity ... all_tenants?: true` makes the token globally unique across stores (a device re-registering under a different store moves rows, not duplicates). If `all_tenants?` isn't a valid identity option in the installed Ash version, drop it and scope uniqueness per store — then the upsert test for cross-store re-registration must register under the same store (adjust only in that case, and note it in the commit).

- [ ] **Step 4: Register resource in the Notifications domain** (`lib/emakola/notifications/notifications.ex`): add `resource(Emakola.Notifications.DeviceToken)` to the `resources do` block, add `extensions: [AshJsonApi.Domain]` + `json_api do prefix("/api/v1") end` exactly as in Task 8 Step 5.

- [ ] **Step 5: Generate and run the migration**

Run: `mix ash.codegen add_device_tokens`
Inspect the generated migration in `priv/repo/migrations/` (expect: `device_tokens` table, store_id, merchant_id FK, unique index on token, indexes on store_id). Then:
Run: `mix ecto.migrate && MIX_ENV=test mix ecto.migrate`

- [ ] **Step 6: Run resource tests**

Run: `mix test test/emakola/notifications/device_token_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 7: Write the failing endpoint tests**

```elixir
defmodule EmakolaWeb.Api.DeviceTokenEndpointsTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store.id)
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, merchant: merchant, store: store}
  end

  test "POST /api/v1/device_tokens registers a device", %{conn: conn} do
    conn =
      post(conn, "/api/v1/device_tokens", %{
        "data" => %{
          "type" => "device_token",
          "attributes" => %{"platform" => "android", "token" => "fcm-abc-123"}
        }
      })

    assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 201)
    assert is_binary(id)
    assert attrs["token"] == "fcm-abc-123"
    assert attrs["platform"] == "android"
  end

  test "re-registering the same token returns the same row (upsert)", %{conn: conn} do
    body = %{
      "data" => %{
        "type" => "device_token",
        "attributes" => %{"platform" => "ios", "token" => "fcm-same"}
      }
    }

    %{"data" => %{"id" => id1}} = conn |> post("/api/v1/device_tokens", body) |> json_response(201)
    %{"data" => %{"id" => id2}} = conn |> post("/api/v1/device_tokens", body) |> json_response(201)

    assert id1 == id2
  end

  test "DELETE /api/v1/device_tokens/:id unregisters", %{conn: conn} do
    %{"data" => %{"id" => id}} =
      conn
      |> post("/api/v1/device_tokens", %{
        "data" => %{
          "type" => "device_token",
          "attributes" => %{"platform" => "android", "token" => "fcm-del"}
        }
      })
      |> json_response(201)

    del_conn = delete(conn, "/api/v1/device_tokens/#{id}")
    assert del_conn.status in [200, 204]
  end
end
```

- [ ] **Step 8: Add Notifications domain to the ApiRouter** (`lib/emakola_web/api_router.ex`):

```elixir
    domains: [Emakola.Orders, Emakola.Notifications],
```

- [ ] **Step 9: Run endpoint tests, iterate until green**

Run: `mix test test/emakola_web/controllers/api/device_token_endpoints_test.exs`
Expected: PASS (3 tests). (If the upsert returns 200 instead of 201 on the second POST, accept either: change the assertion to `json_response(conn, conn.status)` pattern — actually assert `conn.status in [200, 201]` and decode the body.)

- [ ] **Step 10: Commit**

```bash
git add lib/emakola/notifications/ lib/emakola_web/api_router.ex priv/repo/migrations/ test/emakola/notifications/device_token_test.exs test/emakola_web/controllers/api/device_token_endpoints_test.exs
git commit -m "feat(notifications): DeviceToken resource + registration endpoints"
```

---

### Task 12: PushProvider behaviour + Log/FCM implementations

**Files:**
- Create: `lib/emakola/notifications/push_provider.ex`
- Create: `lib/emakola/notifications/providers/log_push.ex`
- Create: `lib/emakola/notifications/providers/fcm_push.ex`
- Modify: `mix.exs` (remove the "pigeon deferred" NOTE comment left by Task 1 — goth stays)
- Modify: `test/test_helper.exs` (defmock), `config/test.exs` (mock provider), `config/runtime.exs` (prod provider, env-gated), `lib/emakola/application.ex` (conditional Goth child)
- Test: `test/emakola/notifications/providers/log_push_test.exs`

**Before coding:** consult Goth docs if needed (context7: "goth" → "service account source Goth.fetch"). FCM HTTP v1 contract: `POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send` with `Authorization: Bearer <oauth token>`; dead tokens return 404, or 400 with `UNREGISTERED` in the error details.

- [ ] **Step 1: Write the behaviour**

```elixir
defmodule Emakola.Notifications.PushProvider do
  @moduledoc """
  Behaviour for mobile push delivery (FCM). Implementations:

    * `Emakola.Notifications.Providers.FcmPush` — production (FCM HTTP v1)
    * `Emakola.Notifications.Providers.LogPush` — dev default (logs only)
    * `Emakola.PushProviderMock` — test (Mox)

  Resolved at runtime from `config :emakola, :push_provider`.
  """

  @type notification :: %{title: String.t(), body: String.t(), data: map()}

  @callback send_push(device_token :: String.t(), notification()) ::
              {:ok, map()} | {:error, :unregistered} | {:error, term()}
end
```

- [ ] **Step 2: Write the failing LogPush test**

```elixir
defmodule Emakola.Notifications.Providers.LogPushTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Emakola.Notifications.Providers.LogPush

  test "logs and succeeds" do
    log =
      capture_log(fn ->
        assert {:ok, %{provider: :log}} =
                 LogPush.send_push("fcm-token-123456789", %{
                   title: "New order",
                   body: "GHS 50.00",
                   data: %{"order_id" => "abc"}
                 })
      end)

    assert log =~ "[push]"
    assert log =~ "New order"
    refute log =~ "fcm-token-123456789"
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/emakola/notifications/providers/log_push_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 4: Implement LogPush**

```elixir
defmodule Emakola.Notifications.Providers.LogPush do
  @moduledoc "Dev/no-op push provider — logs instead of calling FCM. Token is truncated to avoid leaking credentials into logs."

  @behaviour Emakola.Notifications.PushProvider

  require Logger

  @impl true
  def send_push(device_token, %{title: title, body: body}) do
    Logger.info(
      "[push] (log provider) to #{String.slice(device_token, 0, 8)}…: #{title} — #{body}"
    )

    {:ok, %{provider: :log}}
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola/notifications/providers/log_push_test.exs`
Expected: PASS.

- [ ] **Step 6: Implement the FCM client** (no unit test — exercised only in prod; the behaviour boundary is what tests rely on):

`lib/emakola/notifications/providers/fcm_push.ex`:

```elixir
defmodule Emakola.Notifications.Providers.FcmPush do
  @moduledoc """
  Production push provider — FCM HTTP v1 via Req, authenticated with an
  OAuth2 token from Goth (`Emakola.Goth`, started only when
  FCM_SERVICE_ACCOUNT_JSON is configured).
  """

  @behaviour Emakola.Notifications.PushProvider

  @fcm_base "https://fcm.googleapis.com/v1/projects"

  @impl true
  def send_push(device_token, %{title: title, body: body, data: data}) do
    project_id = Application.fetch_env!(:emakola, :fcm_project_id)

    payload = %{
      "message" => %{
        "token" => device_token,
        "notification" => %{"title" => title, "body" => body},
        "data" => data
      }
    }

    with {:ok, %{token: oauth_token}} <- Goth.fetch(Emakola.Goth),
         {:ok, response} <-
           Req.post("#{@fcm_base}/#{project_id}/messages:send",
             json: payload,
             auth: {:bearer, oauth_token}
           ) do
      handle_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_response(%Req.Response{status: 200, body: body}), do: {:ok, body}
  defp handle_response(%Req.Response{status: 404}), do: {:error, :unregistered}

  defp handle_response(%Req.Response{status: status, body: body}) do
    if unregistered?(body) do
      {:error, :unregistered}
    else
      {:error, {:fcm_error, status, body}}
    end
  end

  defp unregistered?(%{"error" => error}) do
    error
    |> Map.get("details", [])
    |> Enum.any?(&(Map.get(&1, "errorCode") == "UNREGISTERED"))
  end

  defp unregistered?(_body), do: false
end
```

- [ ] **Step 7: Wire config**

`config/test.exs` (next to the sms/whatsapp mock config ~line 83):

```elixir
config :emakola, :push_provider, Emakola.PushProviderMock
```

`test/test_helper.exs` (with the other defmocks):

```elixir
Mox.defmock(Emakola.PushProviderMock, for: Emakola.Notifications.PushProvider)
```

`config/runtime.exs` (in the prod section, near the sms/whatsapp provider config ~line 171):

```elixir
  # Mobile push (FCM HTTP v1 via Req + Goth). Only active when a Firebase
  # service account is configured; otherwise the Log provider keeps the
  # pipeline observable without sending anything.
  if System.get_env("FCM_SERVICE_ACCOUNT_JSON") do
    config :emakola, :push_provider, Emakola.Notifications.Providers.FcmPush
    config :emakola, :fcm_project_id, System.fetch_env!("FCM_PROJECT_ID")
  else
    config :emakola, :push_provider, Emakola.Notifications.Providers.LogPush
  end
```

`lib/emakola/application.ex` — add to the children list (find the list in `start/2`; insert before the Endpoint):

```elixir
      fcm_children() ++
```

(adapt to however the children list is built — if it's a plain list literal, change to `children = [...] ++ fcm_children()`), and add the private function:

```elixir
  # Goth OAuth2 token server for FCM — only when FCM is configured
  # (FCM_SERVICE_ACCOUNT_JSON in prod). Dev/test boot without it.
  defp fcm_children do
    case System.get_env("FCM_SERVICE_ACCOUNT_JSON") do
      nil ->
        []

      json ->
        credentials = Jason.decode!(json)

        [{Goth, name: Emakola.Goth, source: {:service_account, credentials}}]
    end
  end
```

- [ ] **Step 8: Verify boot + full compile**

Run: `mix compile --warnings-as-errors && mix test test/emakola/notifications --max-failures 3`
Expected: compiles clean, notifications tests pass (FCM children absent without env var).

- [ ] **Step 9: Document the env vars** — add to the Environment Variables table in `CLAUDE.md` and `.env.example` (if present):

```
| `FCM_PROJECT_ID` | Firebase project id for mobile push (optional — push disabled without it) |
| `FCM_SERVICE_ACCOUNT_JSON` | Firebase service-account JSON (single line) for FCM HTTP v1 |
```

- [ ] **Step 10: Commit**

```bash
git add mix.exs lib/emakola/notifications/push_provider.ex lib/emakola/notifications/providers/ lib/emakola/application.ex config/ test/test_helper.exs test/emakola/notifications/providers/log_push_test.exs CLAUDE.md .env.example
git commit -m "feat(notifications): PushProvider behaviour with Log + FCM (Req/Goth) implementations"
```

---

### Task 13: PushNotificationWorker + Dispatcher integration

**Files:**
- Create: `lib/emakola/notifications/workers/push_notification_worker.ex`
- Modify: `lib/emakola/notifications/dispatcher.ex:132-147` (`do_dispatch/2`)
- Test: `test/emakola/notifications/workers/push_notification_worker_test.exs`

- [ ] **Step 1: Write the failing tests**

```elixir
defmodule Emakola.Notifications.Workers.PushNotificationWorkerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Mox

  alias Emakola.Notifications.Workers.PushNotificationWorker

  setup :verify_on_exit!

  defp register_device!(merchant, store, token) do
    Emakola.Notifications.DeviceToken
    |> Ash.Changeset.for_create(:register, %{platform: :android, token: token},
      actor: merchant,
      tenant: store.id
    )
    |> Ash.create!()
  end

  test "sends a push to every device token registered for the order's store" do
    {merchant, store} = create_merchant_with_store!()
    second = create_merchant!()
    create_store_membership!(second, store, :staff)

    register_device!(merchant, store, "fcm-1")
    register_device!(second, store, "fcm-2")
    order = create_order!(store)

    expect(Emakola.PushProviderMock, :send_push, 2, fn token, notification ->
      assert token in ["fcm-1", "fcm-2"]
      assert notification.title =~ order.order_number
      assert notification.data["order_id"] == order.id
      {:ok, %{}}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })
  end

  test "prunes tokens FCM reports as unregistered" do
    {merchant, store} = create_merchant_with_store!()
    register_device!(merchant, store, "fcm-dead")
    order = create_order!(store)

    expect(Emakola.PushProviderMock, :send_push, fn "fcm-dead", _ ->
      {:error, :unregistered}
    end)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })

    assert [] ==
             Ash.read!(Emakola.Notifications.DeviceToken, authorize?: false, tenant: store.id)
  end

  test "no device tokens → succeeds without calling the provider" do
    {_merchant, store} = create_merchant_with_store!()
    order = create_order!(store)

    assert :ok =
             perform_job(PushNotificationWorker, %{
               "order_id" => order.id,
               "event" => "order_placed"
             })
  end

  test "Dispatcher.dispatch enqueues a push job for order_placed" do
    {_merchant, store} = create_merchant_with_store!()
    order = create_order!(store)

    {:ok, _job} = Emakola.Notifications.Dispatcher.dispatch(order, :order_placed)

    assert_enqueued(
      worker: PushNotificationWorker,
      args: %{"order_id" => order.id, "event" => "order_placed"}
    )
  end

  test "Dispatcher.dispatch does NOT enqueue push for other events" do
    {_merchant, store} = create_merchant_with_store!()
    order = create_order!(store)

    {:ok, _job} = Emakola.Notifications.Dispatcher.dispatch(order, :order_shipped)

    refute_enqueued(worker: PushNotificationWorker)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/emakola/notifications/workers/push_notification_worker_test.exs`
Expected: FAIL — worker undefined.

- [ ] **Step 3: Implement the worker**

(Read `lib/emakola/notifications/workers/order_notification_worker.ex` first and mirror its conventions — order loading, logging prefix style, provider resolution.)

```elixir
defmodule Emakola.Notifications.Workers.PushNotificationWorker do
  @moduledoc """
  Sends an FCM push to every device token registered for the order's store
  when a new order is placed. Idempotent: Oban uniqueness dedupes per
  order+event for 10 minutes (same window as OrderNotificationWorker), and
  re-delivery of a push is harmless. Dead tokens (FCM "unregistered") are
  pruned so the registry self-heals.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, keys: [:order_id, :event]]

  require Logger
  require Ash.Query

  alias Emakola.Notifications.{DeviceToken, Templates}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"order_id" => order_id, "event" => "order_placed"}}) do
    case Ash.get(Emakola.Orders.Order, order_id, authorize?: false) do
      {:ok, order} ->
        order.store_id
        |> device_tokens_for_store()
        |> Enum.each(&deliver(&1, order))

        :ok

      {:error, _} ->
        Logger.warning("[PushNotificationWorker] order not found: #{order_id}")
        # Order may not be committed yet on first attempt; retry via error.
        {:error, :order_not_found}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.warning("[PushNotificationWorker] unsupported args: #{inspect(args)}")
    :ok
  end

  defp device_tokens_for_store(store_id) do
    DeviceToken
    |> Ash.Query.for_read(:for_store)
    |> Ash.read!(authorize?: false, tenant: store_id)
  end

  defp deliver(device_token, order) do
    notification = %{
      title: "New order #{order.order_number}",
      body: "#{order.currency} #{Templates.format_amount(order.total)} — tap to view",
      data: %{"type" => "order_placed", "order_id" => order.id}
    }

    case push_provider().send_push(device_token.token, notification) do
      {:ok, _} ->
        :ok

      {:error, :unregistered} ->
        Logger.info("[PushNotificationWorker] pruning unregistered device token")
        Ash.destroy!(device_token, authorize?: false, tenant: device_token.store_id)

      {:error, reason} ->
        Logger.error("[PushNotificationWorker] push failed: #{inspect(reason)}")
        :ok
    end
  end

  defp push_provider do
    Application.get_env(:emakola, :push_provider, Emakola.Notifications.Providers.LogPush)
  end
end
```

(Adjust the `body` if `Templates.format_amount/1` already includes a currency symbol — check its implementation at `lib/emakola/notifications/templates.ex:132` and avoid double-printing the currency. If `order.total` can be nil for a factory order, fall back: `Templates.format_amount(order.total || 0)`.)

- [ ] **Step 4: Hook into the Dispatcher** — in `lib/emakola/notifications/dispatcher.ex`, alias the new worker at the top:

```elixir
  alias Emakola.Notifications.Workers.PushNotificationWorker
```

and in `do_dispatch/2`, after the successful `enqueue_job` (inside the `{:ok, job} ->` branch, before `maybe_broadcast`):

```elixir
      {:ok, job} ->
        enqueue_push(order_id, event)
        maybe_broadcast(order, event)
        {:ok, job}
```

with the new private function (near `enqueue_job/2`):

```elixir
  # Mobile push fires only on new orders (Phase 0). Failures are logged and
  # swallowed — push must never break the primary notification path.
  defp enqueue_push(order_id, :order_placed) do
    %{order_id: order_id, event: "order_placed"}
    |> PushNotificationWorker.new(queue: :notifications)
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error("[notifications] push enqueue failed: #{inspect(reason)}",
          order_id: order_id
        )

        :ok
    end
  end

  defp enqueue_push(_order_id, _event), do: :ok
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/emakola/notifications/workers/push_notification_worker_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 6: Run the whole notifications suite for regressions**

Run: `mix test test/emakola/notifications`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/emakola/notifications/workers/push_notification_worker.ex lib/emakola/notifications/dispatcher.ex test/emakola/notifications/workers/push_notification_worker_test.exs
git commit -m "feat(notifications): push worker fired on order_placed with dead-token pruning"
```

---

### Task 14: OpenAPI spec generation

**Files:**
- Modify: `lib/emakola_web/api_router.ex` (already has `open_api: "/open_api"` from Task 8)
- Test: `test/emakola_web/controllers/api/open_api_test.exs`

**Before coding:** consult ash_json_api OpenAPI docs (context7: query "open api spec generation mix task modify_open_api").

- [ ] **Step 1: Write the failing test**

```elixir
defmodule EmakolaWeb.Api.OpenApiTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  test "GET /api/v1/open_api returns a spec covering orders and device tokens", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store.id)
      |> get("/api/v1/open_api")

    assert %{"openapi" => _, "paths" => paths} = json_response(conn, 200)

    path_keys = Map.keys(paths)
    assert Enum.any?(path_keys, &String.contains?(&1, "orders"))
    assert Enum.any?(path_keys, &String.contains?(&1, "device_tokens"))
  end
end
```

- [ ] **Step 2: Run test**

Run: `mix test test/emakola_web/controllers/api/open_api_test.exs`
Expected: likely PASS already (the `open_api: "/open_api"` option from Task 8 serves it). If 404: check the AshJsonApi.Router option name in docs and fix.

- [ ] **Step 3: Verify file generation works**

Run: `mix openapi.spec.json --spec EmakolaWeb.ApiRouter` (the open_api_spex task; AshJsonApi.Router modules expose the spec — if the task needs a dedicated spec module, follow the ash_json_api "open-api" guide and create the minimal wrapper module it describes, placing it at `lib/emakola_web/api_spec.ex`).
Expected: an `openapi.json` file in the project root containing the same paths.
Then: `rm openapi.json` (generated on demand; not committed) and add `openapi.json` to `.gitignore`.

- [ ] **Step 4: Document the auth endpoints in the spec description.** The hand-rolled auth endpoints are not Ash resources, so rather than fighting the generated spec, document them in `docs/API.md`: add a "Mobile API v1" section listing `POST /api/v1/auth/sign_in`, `POST /api/v1/auth/refresh`, `DELETE /api/v1/auth/sign_out` with request/response JSON examples (copy the shapes from the controller tests in Task 4), the `Authorization: Bearer` + `X-Store-ID` header contract, and a pointer to `/api/v1/open_api` for the resource endpoints.

- [ ] **Step 5: Commit**

```bash
git add test/emakola_web/controllers/api/open_api_test.exs docs/API.md .gitignore
git commit -m "feat(api): OpenAPI spec endpoint + mobile API docs"
```

---

### Task 15: Full verification + quality gates

**Files:** none new (fixes only)

- [ ] **Step 1: Full test suite**

Run: `mix test`
Expected: 0 failures. (One pre-existing flaky: `OrderNotificationWorker` timing — re-run once before investigating.)

- [ ] **Step 2: Formatting + static analysis**

Run: `mix format --check-formatted && mix credo --strict && mix sobelow`
Expected: all clean. Fix anything flagged in code introduced by this plan (do not touch pre-existing findings).

- [ ] **Step 3: Compile warnings**

Run: `mix compile --warnings-as-errors --force`
Expected: clean.

- [ ] **Step 4: Manual curl smoke test (dev server)**

```bash
mix phx.server &
sleep 5
# sign in (use a seeded merchant or create one in iex)
curl -s -X POST localhost:4000/api/v1/auth/sign_in \
  -H 'content-type: application/json' \
  -d '{"email":"<seeded merchant email>","password":"<password>"}'
# then with the returned tokens:
curl -s localhost:4000/api/v1/stores -H "authorization: Bearer $ACCESS"
curl -s localhost:4000/api/v1/orders -H "authorization: Bearer $ACCESS" -H "x-store-id: $STORE"
```

Expected: token pair → store list → order list (and a `[push] (log provider)` line in server logs if an order is placed via the storefront). Kill the server afterwards.

- [ ] **Step 5: Update CLAUDE.md** — add a short "Mobile API (Phase 0)" subsection under Important Patterns documenting: bearer auth via `ApiTokens` (15-min access / 30-day rotating refresh), `X-Store-ID` tenant convention, DeviceToken + push provider config, and the `/api/v1/open_api` contract endpoint.

- [ ] **Step 5b: Deployment follow-up note (from Task 4 review)** — rate limiting now keys pre-auth endpoints by `conn.remote_ip`. Behind the Fly proxy, verify `remote_ip` reflects the real client IP (Fly sets it via proxy protocol/fly-client-ip); if it's the edge IP, all mobile clients share one 10/min sign-in bucket. Add this check to `docs/LAUNCH_TODO.md` or the deploy runbook rather than fixing blind.

- [ ] **Step 6: Commit any fixes + docs**

```bash
git add -A
git commit -m "docs(api): document mobile API patterns; quality-gate fixes"
```

---

## Self-review notes (already applied)

- Spec coverage: auth (T3-4), bearer/tenant plugs (T5-6), stores (T7), orders list/detail (T8), transitions (T9), isolation tests (T10), DeviceToken (T11), push provider (T12), push worker + dispatcher (T13), OpenAPI (T14), exit criteria (T15). Refresh rotation + revocation covered in T3/T4 tests.
- Real-device push verification is intentionally OUT (user decision) — tracked as follow-up in the spec.
- Type consistency: `ApiTokens.issue_pair/1` returns `{:ok, %{access_token, refresh_token, expires_in}}` — used identically in T4, T5, T7, T8, T10 tests.
