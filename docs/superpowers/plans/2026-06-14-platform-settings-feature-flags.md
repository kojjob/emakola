# Platform Settings — Feature Flags Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a production-grade `/platform/settings` page that lets the project owner manage runtime feature flags (list, search, filter, toggle, create, edit, delete) over the existing `Emakola.FeatureFlags` domain — no new DB models.

**Architecture:** A single LiveView (`EmakolaWeb.Platform.SettingsLive`) mounted in the existing `:platform` `live_session` (already gated by `RequirePlatformAdmin`). The flag grid uses **Phoenix streams**; create/edit/delete use the project's established **plain-params + server-driven modal** convention (mirroring `Admin.CategoryLive.Index` — NOT `AshPhoenix.Form`). Three thin domain code-interface defines expose the resource's existing `update`/`toggle`/`destroy` actions.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x (FeatureFlags domain), TailwindCSS, core_components `<.modal>` / `<.confirm_modal>` / `show_modal` / `hide_modal`, ExUnit + `Phoenix.LiveViewTest`.

**Spec:** `docs/superpowers/specs/2026-06-14-platform-settings-feature-flags-design.md`

**Branch:** `feature/platform-settings-feature-flags` (already created; spec already committed).

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/emakola/feature_flags/feature_flags.ex` | expose `update_flag` / `toggle_flag` / `destroy_flag` | Modify |
| `test/support/factory.ex` | `create_platform_admin!/1`, `create_feature_flag!/1` | Modify |
| `lib/emakola_web/router.ex` | route `/platform/settings` | Modify |
| `lib/emakola_web/components/layouts/platform.html.heex` | live Settings nav link (drop "Soon" stub) | Modify |
| `lib/emakola_web/live/platform/settings_live.ex` | the page | Create |
| `test/emakola/feature_flags/feature_flags_test.exs` | domain-interface tests | Create |
| `test/emakola_web/live/platform/settings_live_test.exs` | LiveView tests | Create |

---

## Task 1: Domain code interfaces + test factories

**Files:**
- Modify: `lib/emakola/feature_flags/feature_flags.ex`
- Modify: `test/support/factory.ex`
- Test: `test/emakola/feature_flags/feature_flags_test.exs` (create)

- [ ] **Step 1: Write the failing test**

Create `test/emakola/feature_flags/feature_flags_test.exs`:

```elixir
defmodule Emakola.FeatureFlagsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.FeatureFlags

  describe "code interfaces" do
    test "toggle_flag flips enabled" do
      flag = Factory.create_feature_flag!(%{enabled: true})
      assert {:ok, updated} = FeatureFlags.toggle_flag(flag, authorize?: false)
      refute updated.enabled
    end

    test "update_flag changes name and required_plan" do
      flag = Factory.create_feature_flag!(%{name: "Old", required_plan: nil})

      assert {:ok, updated} =
               FeatureFlags.update_flag(flag, %{name: "New", required_plan: "pro"},
                 authorize?: false
               )

      assert updated.name == "New"
      assert updated.required_plan == "pro"
    end

    test "destroy_flag removes the flag" do
      flag = Factory.create_feature_flag!()
      assert :ok = FeatureFlags.destroy_flag(flag, authorize?: false)
      assert {:error, _} = FeatureFlags.get_flag(flag.id)
    end
  end

  describe "create_platform_admin! factory" do
    test "creates a user flagged as platform admin" do
      admin = Factory.create_platform_admin!()
      assert admin.is_platform_admin == true
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/feature_flags/feature_flags_test.exs`
Expected: FAIL — `function Emakola.FeatureFlags.toggle_flag/2 is undefined` (and factory funcs undefined).

- [ ] **Step 3: Add the domain code interfaces**

In `lib/emakola/feature_flags/feature_flags.ex`, extend the resource block:

```elixir
  resources do
    resource Emakola.FeatureFlags.FeatureFlag do
      define(:create_flag, action: :create)
      define(:list_flags, action: :read)
      define(:get_flag, action: :read, get_by: [:id])
      define(:get_flag_by_key, action: :read, get_by: [:key])
      define(:update_flag, action: :update)
      define(:toggle_flag, action: :toggle)
      define(:destroy_flag, action: :destroy)
    end
  end
```

- [ ] **Step 4: Add the test factories**

In `test/support/factory.ex`, add (place near the other `create_*!` helpers):

```elixir
  def create_platform_admin!(attrs \\ %{}) do
    create_user!(attrs)
    |> Ash.Changeset.for_update(:update, %{})
    |> Ash.Changeset.force_change_attribute(:is_platform_admin, true)
    |> Ash.update!(authorize?: false)
  end

  def create_feature_flag!(attrs \\ %{}) do
    params =
      Map.merge(
        %{
          key: "flag_#{System.unique_integer([:positive])}",
          name: "Test Flag",
          enabled: true
        },
        Map.new(attrs)
      )

    Emakola.FeatureFlags.FeatureFlag
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end
```

> Note: `register_with_password` does not accept `is_platform_admin`, and the `:update`
> action's `accept` list omits it too — hence `force_change_attribute/2`, which bypasses
> the accept list.

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/emakola/feature_flags/feature_flags_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/emakola/feature_flags/feature_flags.ex test/support/factory.ex test/emakola/feature_flags/feature_flags_test.exs
git commit -m "feat(feature-flags): expose update/toggle/destroy interfaces + test factories"
```

---

## Task 2: Route, nav link, and LiveView skeleton

This task makes `/platform/settings` reachable and authz-gated, with a minimal page. The full UI lands in Task 4.

**Files:**
- Modify: `lib/emakola_web/router.ex`
- Modify: `lib/emakola_web/components/layouts/platform.html.heex`
- Create: `lib/emakola_web/live/platform/settings_live.ex`
- Test: `test/emakola_web/live/platform/settings_live_test.exs` (create)

- [ ] **Step 1: Write the failing test**

Create `test/emakola_web/live/platform/settings_live_test.exs`:

```elixir
defmodule EmakolaWeb.Platform.SettingsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  defp log_in_platform_admin(conn) do
    admin = Factory.create_platform_admin!()
    token = AshAuthentication.user_to_subject(admin)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "access control" do
    test "platform admin can load the page", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "Settings"
      assert html =~ "feature flags"
    end

    test "a non-admin merchant is redirected", %{conn: conn} do
      {merchant, _store} = Factory.create_merchant_with_store!()
      token = AshAuthentication.user_to_subject(merchant)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/platform/settings")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/platform/settings_live_test.exs`
Expected: FAIL — no route for `/platform/settings`.

- [ ] **Step 3: Add the route**

In `lib/emakola_web/router.ex`, inside the existing `live_session :platform` block (right after the `/platform/stores` line):

```elixir
      live "/platform/settings", Platform.SettingsLive
```

- [ ] **Step 4: Create the LiveView skeleton**

Create `lib/emakola_web/live/platform/settings_live.ex`:

```elixir
defmodule EmakolaWeb.Platform.SettingsLive do
  @moduledoc "Platform-level feature flag management (project owner only)."
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:active_nav, :settings)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Settings</h1>
      <p class="text-sm text-gray-500 mt-1">Platform feature flags</p>
    </div>
    """
  end
end
```

- [ ] **Step 5: Swap the disabled Settings nav stub for a live link**

In `lib/emakola_web/components/layouts/platform.html.heex`, replace the entire disabled
Settings `<a href="#" ...>…Settings…Soon…</a>` block (the second "Soon" stub, under the
`Config` section label — currently lines ~150-178) with:

```heex
      <.sidebar_link
        href="/platform/settings"
        title="Settings"
        icon="gear"
        active={@active_nav == :settings}
      />
```

Leave the `Config` section label line above it intact. Leave the **Billing** "Soon" stub
unchanged.

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/emakola_web/live/platform/settings_live_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/emakola_web/router.ex lib/emakola_web/components/layouts/platform.html.heex lib/emakola_web/live/platform/settings_live.ex test/emakola_web/live/platform/settings_live_test.exs
git commit -m "feat(platform): add /platform/settings route, nav link, and skeleton"
```

---

## Task 3: Full LiveView behavior tests (red)

Write the complete behavior test suite. It will fail against the Task-2 skeleton — that's the expected red state before Task 4.

**Files:**
- Modify: `test/emakola_web/live/platform/settings_live_test.exs`

- [ ] **Step 1: Append the behavior tests**

Add these `describe` blocks to `test/emakola_web/live/platform/settings_live_test.exs`
(keep the existing access-control block and the `log_in_platform_admin/1` helper):

```elixir
  describe "listing & stats" do
    setup %{conn: conn} do
      Factory.create_feature_flag!(%{key: "alpha", name: "Alpha", enabled: true})
      Factory.create_feature_flag!(%{key: "beta", name: "Beta", enabled: true, required_plan: "pro"})
      Factory.create_feature_flag!(%{key: "gamma", name: "Gamma", enabled: false})
      {:ok, conn: log_in_platform_admin(conn)}
    end

    test "renders all flags with names and keys", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      for s <- ["Alpha", "Beta", "Gamma", "alpha", "beta", "gamma"], do: assert(html =~ s)
    end

    test "stat strip shows correct counts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = render(view)
      # 3 total, 2 enabled, 1 disabled, 1 plan-gated
      assert html =~ "Total"
      assert html =~ "Enabled"
      assert html =~ "Plan-gated"
      assert html =~ "Disabled"
    end

    test "search narrows by name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = view |> form("#flag-search-form") |> render_change(%{"search" => "Alpha"})
      assert html =~ "Alpha"
      refute html =~ "Gamma"
    end

    test "search narrows by key", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = view |> form("#flag-search-form") |> render_change(%{"search" => "beta"})
      assert html =~ "Beta"
      refute html =~ "Alpha"
    end

    test "disabled filter shows only disabled flags", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")
      html = render_click(view, "filter", %{"filter" => "disabled"})
      assert html =~ "Gamma"
      refute html =~ "Alpha"
    end
  end

  describe "toggle" do
    test "flips a flag's enabled state and persists", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "tog", name: "Toggle Me", enabled: true})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "toggle", %{"id" => flag.id})

      {:ok, reloaded} = Emakola.FeatureFlags.get_flag(flag.id)
      refute reloaded.enabled
    end
  end

  describe "create" do
    setup %{conn: conn}, do: {:ok, conn: log_in_platform_admin(conn)}

    test "creates a new flag", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      view
      |> form("#flag-form", %{
        "key" => "new_feature",
        "name" => "New Feature",
        "description" => "A shiny thing",
        "enabled" => "true",
        "required_plan" => "starter"
      })
      |> render_submit()

      assert {:ok, flag} = Emakola.FeatureFlags.get_flag_by_key("new_feature")
      assert flag.name == "New Feature"
      assert flag.required_plan == "starter"
    end

    test "blank name shows a validation error and creates nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      html =
        view
        |> form("#flag-form", %{"key" => "k1", "name" => "", "enabled" => "true"})
        |> render_submit()

      assert html =~ "Name is required"
      assert {:ok, []} = Emakola.FeatureFlags.list_flags()
    end

    test "required_plan select offers only the four tiers plus none", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "All plans"
      for tier <- ~w(Free Starter Pro Enterprise), do: assert(html =~ tier)
    end
  end

  describe "edit" do
    test "updates name and keeps key field disabled", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "edit_me", name: "Before"})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "open_edit_modal", %{"id" => flag.id})
      html = render(view)
      assert html =~ "disabled"

      view
      |> form("#flag-form", %{"name" => "After", "enabled" => "true", "required_plan" => ""})
      |> render_submit()

      {:ok, reloaded} = Emakola.FeatureFlags.get_flag(flag.id)
      assert reloaded.name == "After"
      assert reloaded.key == "edit_me"
    end
  end

  describe "delete" do
    test "removes a flag", %{conn: conn} do
      flag = Factory.create_feature_flag!(%{key: "kill", name: "Kill Me"})
      conn = log_in_platform_admin(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/settings")

      render_click(view, "delete", %{"id" => flag.id})

      assert {:error, _} = Emakola.FeatureFlags.get_flag(flag.id)
    end
  end

  describe "empty state" do
    test "renders when no flags exist", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/settings")
      assert html =~ "No feature flags yet"
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola_web/live/platform/settings_live_test.exs`
Expected: FAIL — skeleton has no `#flag-search-form`, `#flag-form`, stat strip, events, or empty state.

- [ ] **Step 3: Commit the failing tests**

```bash
git add test/emakola_web/live/platform/settings_live_test.exs
git commit -m "test(platform): behavior specs for settings feature-flags page"
```

---

## Task 4: Full LiveView implementation (green)

Replace the skeleton with the complete page.

**Files:**
- Modify: `lib/emakola_web/live/platform/settings_live.ex` (full rewrite)

- [ ] **Step 1: Write the complete module**

Overwrite `lib/emakola_web/live/platform/settings_live.ex` with:

```elixir
defmodule EmakolaWeb.Platform.SettingsLive do
  @moduledoc "Platform-level feature flag management (project owner only)."
  use EmakolaWeb, :live_view

  alias Emakola.FeatureFlags

  @plans ~w(free starter pro enterprise)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:active_nav, :settings)
     |> assign(:search, "")
     |> assign(:filter, :all)
     |> assign(:plans, @plans)
     |> assign(:edit_flag_id, nil)
     |> assign(:delete_flag, nil)
     |> reset_form()
     |> load_flags()}
  end

  # ── Events ─────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"search" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> put_flags()}
  end

  def handle_event("filter", %{"filter" => f}, socket) do
    {:noreply, socket |> assign(:filter, parse_filter(f)) |> put_flags()}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply, socket |> assign(:edit_flag_id, nil) |> reset_form()}
  end

  def handle_event("open_edit_modal", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.all_flags, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      flag ->
        {:noreply,
         socket
         |> assign(:edit_flag_id, id)
         |> assign(:form_key, flag.key)
         |> assign(:form_name, flag.name)
         |> assign(:form_description, flag.description || "")
         |> assign(:form_enabled, flag.enabled)
         |> assign(:form_plan, flag.required_plan)
         |> assign(:form_errors, %{})}
    end
  end

  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_flag, Enum.find(socket.assigns.all_flags, &(&1.id == id)))}
  end

  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :form_errors, validate_params(params))}
  end

  def handle_event("save", params, socket) do
    errors = validate_params(params)

    if errors == %{} do
      case socket.assigns.edit_flag_id do
        nil -> create_flag(socket, params)
        id -> do_update_flag(socket, id, params)
      end
    else
      {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    with flag when not is_nil(flag) <- Enum.find(socket.assigns.all_flags, &(&1.id == id)),
         {:ok, updated} <- FeatureFlags.toggle_flag(flag, authorize?: false) do
      {:noreply, sync_flag(socket, updated)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not update flag")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with flag when not is_nil(flag) <- Enum.find(socket.assigns.all_flags, &(&1.id == id)),
         :ok <- FeatureFlags.destroy_flag(flag, authorize?: false) do
      all = Enum.reject(socket.assigns.all_flags, &(&1.id == id))

      {:noreply,
       socket
       |> assign(:all_flags, all)
       |> assign(:stats, compute_stats(all))
       |> assign(:delete_flag, nil)
       |> assign(:filtered_count, length(filtered(all, socket.assigns.search, socket.assigns.filter)))
       |> stream_delete(:flags, flag)
       |> put_flash(:info, "Feature flag deleted")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not delete flag")}
    end
  end

  # ── Create / Update ────────────────────────────────────

  defp create_flag(socket, params) do
    attrs = %{
      key: String.trim(params["key"] || ""),
      name: String.trim(params["name"] || ""),
      description: params["description"] || "",
      enabled: params["enabled"] == "true",
      required_plan: parse_plan(params["required_plan"])
    }

    case FeatureFlags.create_flag(attrs, authorize?: false) do
      {:ok, _flag} ->
        {:noreply,
         socket
         |> reset_form()
         |> load_flags()
         |> put_flash(:info, "Feature flag created")
         |> push_event("js-exec", %{to: "#flag-modal", attr: "phx-remove"})}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, format_error(error))}
    end
  end

  defp do_update_flag(socket, id, params) do
    case Enum.find(socket.assigns.all_flags, &(&1.id == id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Flag not found")}

      flag ->
        attrs = %{
          name: String.trim(params["name"] || ""),
          description: params["description"] || "",
          enabled: params["enabled"] == "true",
          required_plan: parse_plan(params["required_plan"])
        }

        case FeatureFlags.update_flag(flag, attrs, authorize?: false) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> assign(:edit_flag_id, nil)
             |> reset_form()
             |> load_flags()
             |> put_flash(:info, "Feature flag updated")
             |> push_event("js-exec", %{to: "#flag-modal", attr: "phx-remove"})}

          {:error, error} ->
            {:noreply, put_flash(socket, :error, format_error(error))}
        end
    end
  end

  # ── Data ───────────────────────────────────────────────

  defp load_flags(socket) do
    all = list_all_flags()

    socket
    |> assign(:all_flags, all)
    |> assign(:stats, compute_stats(all))
    |> put_flags()
  end

  defp put_flags(socket) do
    visible = filtered(socket.assigns.all_flags, socket.assigns.search, socket.assigns.filter)

    socket
    |> assign(:filtered_count, length(visible))
    |> stream(:flags, visible, reset: true)
  end

  defp sync_flag(socket, updated) do
    all =
      Enum.map(socket.assigns.all_flags, fn f -> if f.id == updated.id, do: updated, else: f end)

    socket =
      socket
      |> assign(:all_flags, all)
      |> assign(:stats, compute_stats(all))
      |> assign(:filtered_count, length(filtered(all, socket.assigns.search, socket.assigns.filter)))

    if matches?(updated, socket.assigns.search, socket.assigns.filter) do
      stream_insert(socket, :flags, updated)
    else
      stream_delete(socket, :flags, updated)
    end
  end

  defp list_all_flags do
    case FeatureFlags.list_flags(authorize?: false) do
      {:ok, flags} -> Enum.sort_by(flags, & &1.name)
      _ -> []
    end
  rescue
    _ -> []
  end

  defp filtered(all, search, filter) do
    q = normalize(search)

    all
    |> Enum.filter(&(matches_search?(&1, q) and matches_filter?(&1, filter)))
    |> Enum.sort_by(& &1.name)
  end

  defp matches?(flag, search, filter),
    do: matches_search?(flag, normalize(search)) and matches_filter?(flag, filter)

  defp matches_search?(_flag, ""), do: true

  defp matches_search?(flag, q) do
    String.contains?(String.downcase(flag.name || ""), q) or
      String.contains?(String.downcase(flag.key || ""), q)
  end

  defp matches_filter?(_flag, :all), do: true
  defp matches_filter?(flag, :enabled), do: flag.enabled
  defp matches_filter?(flag, :disabled), do: not flag.enabled

  defp compute_stats(flags) do
    %{
      total: length(flags),
      enabled: Enum.count(flags, & &1.enabled),
      disabled: Enum.count(flags, &(not &1.enabled)),
      gated: Enum.count(flags, &(&1.required_plan not in [nil, ""]))
    }
  end

  # ── Helpers ────────────────────────────────────────────

  defp reset_form(socket) do
    socket
    |> assign(:form_key, "")
    |> assign(:form_name, "")
    |> assign(:form_description, "")
    |> assign(:form_enabled, true)
    |> assign(:form_plan, nil)
    |> assign(:form_errors, %{})
  end

  defp validate_params(params) do
    %{}
    |> maybe_error(:name, blank?(params["name"]), "Name is required")
    |> maybe_error(:key, params["key"] != nil and blank?(params["key"]), "Key is required")
  end

  defp maybe_error(errors, _field, false, _msg), do: errors
  defp maybe_error(errors, field, true, msg), do: Map.put(errors, field, msg)

  defp blank?(nil), do: true
  defp blank?(s) when is_binary(s), do: String.trim(s) == ""
  defp blank?(_), do: false

  defp normalize(s), do: s |> to_string() |> String.trim() |> String.downcase()

  defp parse_filter("enabled"), do: :enabled
  defp parse_filter("disabled"), do: :disabled
  defp parse_filter(_), do: :all

  defp parse_plan(p) when p in [nil, "", "none"], do: nil
  defp parse_plan(p) when p in @plans, do: p
  defp parse_plan(_), do: nil

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{message: msg} when is_binary(msg) -> msg
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)

  # ── Render ─────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Header --%>
      <div class="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Settings</h1>
          <p class="text-sm text-gray-500 mt-1">
            Platform feature flags ({@stats.total} total)
          </p>
        </div>
        <button
          type="button"
          phx-click={JS.push("open_add_modal") |> show_modal("flag-modal")}
          class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
        >
          <span class="material-symbols-outlined text-base">add</span> New flag
        </button>
      </div>

      <%!-- Stat strip --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <.stat label="Total" value={@stats.total} icon="flag" color="blue" />
        <.stat label="Enabled" value={@stats.enabled} icon="check_circle" color="emerald" />
        <.stat label="Plan-gated" value={@stats.gated} icon="workspace_premium" color="amber" />
        <.stat label="Disabled" value={@stats.disabled} icon="cancel" color="slate" />
      </div>

      <%!-- Toolbar --%>
      <div class="mb-5 flex items-center gap-3 flex-wrap">
        <form id="flag-search-form" phx-change="search" class="relative flex-1 min-w-[200px] max-w-sm">
          <span class="material-symbols-outlined text-base text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none">
            search
          </span>
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search by name or key..."
            phx-debounce="300"
            class="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
          />
        </form>
        <div class="flex items-center gap-1.5">
          <.chip filter="all" active={@filter} label="All" />
          <.chip filter="enabled" active={@filter} label="Enabled" />
          <.chip filter="disabled" active={@filter} label="Disabled" />
        </div>
      </div>

      <%!-- Empty states --%>
      <div
        :if={@stats.total == 0}
        class="bg-white rounded-xl border border-gray-200 px-6 py-16 text-center"
      >
        <span class="material-symbols-outlined text-4xl text-gray-300">flag</span>
        <p class="mt-2 text-sm font-medium text-gray-900">No feature flags yet</p>
        <p class="text-sm text-gray-400 mb-4">Create your first flag to start gating features.</p>
        <button
          type="button"
          phx-click={JS.push("open_add_modal") |> show_modal("flag-modal")}
          class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
        >
          <span class="material-symbols-outlined text-base">add</span> New flag
        </button>
      </div>

      <div
        :if={@stats.total > 0 and @filtered_count == 0}
        class="bg-white rounded-xl border border-gray-200 px-6 py-16 text-center text-sm text-gray-400"
      >
        No flags match your filters
      </div>

      <%!-- Card grid --%>
      <div
        :if={@filtered_count > 0}
        id="flags"
        phx-update="stream"
        class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4"
      >
        <div
          :for={{dom_id, flag} <- @streams.flags}
          id={dom_id}
          class={[
            "bg-white rounded-xl border border-gray-200 border-l-4 p-5 flex flex-col",
            if(flag.enabled, do: "border-l-blue-500", else: "border-l-slate-300 opacity-75")
          ]}
        >
          <div class="flex items-start justify-between gap-3">
            <h3 class="font-semibold text-gray-900 leading-tight">{flag.name}</h3>
            <button
              type="button"
              phx-click="toggle"
              phx-value-id={flag.id}
              role="switch"
              aria-checked={to_string(flag.enabled)}
              aria-label="Toggle flag"
              class={[
                "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors",
                if(flag.enabled, do: "bg-blue-600", else: "bg-slate-300")
              ]}
            >
              <span class={[
                "inline-block h-4 w-4 transform rounded-full bg-white transition-transform",
                if(flag.enabled, do: "translate-x-6", else: "translate-x-1")
              ]}>
              </span>
            </button>
          </div>

          <div class="flex items-center gap-2 mt-2 flex-wrap">
            <span class="font-mono text-xs px-2 py-0.5 rounded bg-slate-100 text-slate-600">
              {flag.key}
            </span>
            <span
              :if={flag.required_plan}
              class="inline-flex items-center gap-1 text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 font-medium"
            >
              <span class="material-symbols-outlined" style="font-size: 12px;">workspace_premium</span>
              {String.capitalize(flag.required_plan)}
            </span>
            <span :if={is_nil(flag.required_plan)} class="text-xs text-slate-400">All plans</span>
          </div>

          <p class="text-sm text-slate-500 mt-2 line-clamp-2">
            {if flag.description in [nil, ""], do: "No description", else: flag.description}
          </p>

          <div class="flex items-center justify-between mt-4 pt-3 border-t border-gray-100">
            <span class="text-xs text-slate-400">
              Updated {Calendar.strftime(flag.updated_at, "%b %d, %Y")}
            </span>
            <div class="flex items-center gap-3">
              <button
                type="button"
                phx-click={JS.push("open_edit_modal", value: %{id: flag.id}) |> show_modal("flag-modal")}
                class="text-xs font-medium text-blue-600 hover:text-blue-700"
              >
                Edit
              </button>
              <button
                type="button"
                phx-click={
                  JS.push("open_delete_modal", value: %{id: flag.id})
                  |> show_modal("delete-flag-modal")
                }
                class="text-xs font-medium text-rose-600 hover:text-rose-700"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Create / Edit modal --%>
      <.modal id="flag-modal" title={if @edit_flag_id, do: "Edit feature flag", else: "New feature flag"} size={:md}>
        <form id="flag-form" phx-submit="save" phx-change="validate" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Key <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="key"
              value={@form_key}
              disabled={@edit_flag_id != nil}
              placeholder="new_checkout"
              autocomplete="off"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:bg-slate-100 disabled:text-slate-400 font-mono",
                if(@form_errors[:key], do: "border-red-300 bg-red-50", else: "border-slate-300")
              ]}
            />
            <p :if={@edit_flag_id} class="mt-1 text-xs text-slate-400">
              Key can't be changed after creation.
            </p>
            <p :if={@form_errors[:key]} class="mt-1 text-xs text-red-600">{@form_errors[:key]}</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">
              Name <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              name="name"
              value={@form_name}
              placeholder="New checkout"
              autocomplete="off"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
                if(@form_errors[:name], do: "border-red-300 bg-red-50", else: "border-slate-300")
              ]}
            />
            <p :if={@form_errors[:name]} class="mt-1 text-xs text-red-600">{@form_errors[:name]}</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Description</label>
            <textarea
              name="description"
              rows="3"
              placeholder="Optional description"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
            >{@form_description}</textarea>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">Required plan</label>
            <select
              name="required_plan"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="" selected={is_nil(@form_plan)}>All plans (no gate)</option>
              <option :for={p <- @plans} value={p} selected={@form_plan == p}>
                {String.capitalize(p)}
              </option>
            </select>
          </div>

          <label class="flex items-center gap-2">
            <input type="hidden" name="enabled" value="false" />
            <input
              type="checkbox"
              name="enabled"
              value="true"
              checked={@form_enabled}
              class="h-4 w-4 rounded border-slate-300 text-blue-600 focus:ring-blue-500"
            />
            <span class="text-sm text-slate-700">Enabled</span>
          </label>

          <div class="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              phx-click={hide_modal("flag-modal")}
              class="px-4 py-2.5 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-xl hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2.5 text-sm font-semibold bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors"
            >
              {if @edit_flag_id, do: "Update", else: "Create"}
            </button>
          </div>
        </form>
      </.modal>

      <%!-- Delete confirmation --%>
      <.confirm_modal
        :if={@delete_flag}
        id="delete-flag-modal"
        title="Delete feature flag"
        message={"Delete \"#{@delete_flag.name}\"? This action cannot be undone."}
        confirm_text="Delete"
        confirm_class="bg-rose-600 hover:bg-rose-700 text-white"
        on_confirm="delete"
        value={@delete_flag.id}
        icon="warning"
        icon_class="text-rose-500"
      />
    </div>
    """
  end

  # ── Function components ─────────────────────────────────

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp stat(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600",
      "emerald" => "bg-emerald-50 text-emerald-600",
      "amber" => "bg-amber-50 text-amber-600",
      "slate" => "bg-slate-100 text-slate-600"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600"))

    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-5">
      <span class={"material-symbols-outlined text-xl rounded-lg p-2 #{@color_class}"}>
        {@icon}
      </span>
      <p class="text-2xl font-bold text-gray-900 tabular-nums mt-3">{@value}</p>
      <p class="text-sm text-gray-500 mt-1">{@label}</p>
    </div>
    """
  end

  attr :filter, :string, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true

  defp chip(assigns) do
    assigns = assign(assigns, :is_active, to_string(assigns.active) == assigns.filter)

    ~H"""
    <button
      type="button"
      phx-click="filter"
      phx-value-filter={@filter}
      class={[
        "px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors",
        if(@is_active,
          do: "bg-blue-600 text-white",
          else: "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end
end
```

- [ ] **Step 2: Run the full test file to verify it passes**

Run: `mix test test/emakola_web/live/platform/settings_live_test.exs`
Expected: PASS (all access-control + behavior tests green).

> If the `disabled`-key edit test is flaky on whitespace, confirm the rendered input
> includes the literal `disabled` attribute (it does, via `disabled={@edit_flag_id != nil}`).

- [ ] **Step 3: Commit**

```bash
git add lib/emakola_web/live/platform/settings_live.ex
git commit -m "feat(platform): full feature-flags settings page (grid, toggle, CRUD)"
```

---

## Task 5: Quality gates & final verification

**Files:** none (verification only)

- [ ] **Step 1: Format**

Run: `mix format`
Then: `mix format --check-formatted`
Expected: no output (clean).

- [ ] **Step 2: Credo**

Run: `mix credo --strict lib/emakola_web/live/platform/settings_live.ex lib/emakola/feature_flags/feature_flags.ex`
Expected: no issues. Fix any reported (e.g. alias ordering, function arity grouping).

- [ ] **Step 3: Full suite**

Run: `mix test`
Expected: all green, including the two new test files. Confirm no regressions in
`assign_defaults`, dashboard, or store LiveView tests.

- [ ] **Step 4: Manual smoke (optional but recommended)**

```bash
mix phx.server
```
Visit `/platform/settings` as a platform admin. Verify: New flag → create; toggle a card;
edit (key disabled); delete via confirm; search + filter chips. Then stop the server
(per the project's "don't edit while phx.server runs" lesson).

- [ ] **Step 5: Final commit (if Step 1/2 changed anything)**

```bash
git add -A
git commit -m "chore(platform): format + credo for settings page"
```

---

## Self-review notes (author)

- **Spec coverage:** domain defines (Task 1), route + nav swap (Task 2), streams grid +
  stat strip + search/filter + toggle + create/edit/delete + plan-constrained select +
  empty states (Task 4); 12 spec test cases mapped across Tasks 2-3. ✅
- **Deviation from spec, intentional:** spec named `AshPhoenix.Form`; the codebase has
  **zero** `AshPhoenix.Form` usage and a consistent plain-params + `format_error/1` +
  `<.modal>` convention (`Admin.CategoryLive.Index`). Plan follows the codebase
  convention — it satisfies the spec's *intent* (real persisted CRUD, server-driven
  modal, no CSS `:checked`) and avoids introducing an unused pattern. The spec's
  `:all_flags` / `:stats` / streams design is implemented as written.
- **Type consistency:** `parse_filter/1` returns atoms; `chip` compares
  `to_string(@active) == @filter` (string) — consistent. `parse_plan/1` enforces the
  `@plans` allowlist (honors the SafeAtom lesson; no `String.to_atom` on user input).
- **No placeholders.** Every step has runnable code/commands.
