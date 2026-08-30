defmodule EmakolaWeb.Platform.SettingsLive do
  @moduledoc """
  Platform-level feature flag management.

  Mount is gated by RequirePermission (:manage_settings). No DB queries run
  during the disconnected render — a nil flags state is assigned and the
  template renders a loading shell. Every mutating handle_event (toggle,
  save, delete) re-checks the permission against a freshly reloaded user so a
  post-mount revocation is caught before the write.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_settings}

  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.FeatureFlags

  @plans ~w(free starter pro enterprise)
  @flag_form_fields [
    key: "key",
    name: "name",
    description: "description",
    enabled: "enabled",
    required_plan: "required_plan"
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Settings")
      |> assign(:active_nav, :settings)
      |> assign(:search, "")
      |> assign(:search_form, to_form(%{"search" => ""}))
      |> assign(:filter, :all)
      |> assign(:plans, @plans)
      |> assign(:edit_flag_id, nil)
      |> assign(:delete_flag, nil)
      |> assign(:confirming_id, nil)
      |> reset_form()

    socket =
      if connected?(socket) do
        load_flags(socket)
      else
        socket
        |> assign(all_flags: nil, stats: nil, filtered_count: 0)
        |> stream(:flags, [])
      end

    {:ok, socket}
  end

  # Re-check :manage_settings against a freshly reloaded user so a post-mount
  # permission revocation is caught before any write.
  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_settings) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to manage settings.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  # ── Events ─────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"search" => q} = params, socket) do
    {:noreply,
     socket
     |> assign(:search, q)
     |> assign(:search_form, to_form(params))
     |> put_flags()}
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
         |> assign(:flag_form, edit_flag_form(flag))
         |> assign(:form_errors, %{})}
    end
  end

  def handle_event("open_delete_modal", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_flag, Enum.find(socket.assigns.all_flags, &(&1.id == id)))}
  end

  def handle_event("validate", params, socket) do
    {:noreply,
     socket
     |> put_flag_form(params)
     |> assign(:form_errors, validate_params(params))}
  end

  def handle_event("save", params, socket) do
    socket = put_flag_form(socket, params)

    authorized(socket, fn socket ->
      errors = validate_params(params)

      if errors == %{} do
        case socket.assigns.edit_flag_id do
          nil -> create_flag(socket, params)
          id -> do_update_flag(socket, id, params)
        end
      else
        {:noreply, assign(socket, :form_errors, errors)}
      end
    end)
  end

  # The switch asks first, in the card, so the flag being changed stays on
  # screen while the decision is made. One click here changes what every
  # merchant sees; Delete — far less reachable — already had a modal.
  def handle_event("toggle", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:confirming_id, id) |> restream_flag(id)}
  end

  def handle_event("cancel_toggle", _params, socket) do
    id = socket.assigns.confirming_id
    {:noreply, socket |> assign(:confirming_id, nil) |> restream_flag(id)}
  end

  def handle_event("confirm_toggle", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      socket = assign(socket, :confirming_id, nil)

      with flag when not is_nil(flag) <- Enum.find(socket.assigns.all_flags, &(&1.id == id)),
           {:ok, updated} <- FeatureFlags.toggle_flag(flag, authorize?: false) do
        {:noreply, sync_flag(socket, updated)}
      else
        _ -> {:noreply, put_flash(socket, :error, "Could not update flag")}
      end
    end)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      with flag when not is_nil(flag) <- Enum.find(socket.assigns.all_flags, &(&1.id == id)),
           :ok <- FeatureFlags.destroy_flag(flag, authorize?: false) do
        all = Enum.reject(socket.assigns.all_flags, &(&1.id == id))

        {:noreply,
         socket
         |> assign(:all_flags, all)
         |> assign(:stats, compute_stats(all))
         |> assign(:delete_flag, nil)
         |> assign(
           :filtered_count,
           length(filtered(all, socket.assigns.search, socket.assigns.filter))
         )
         |> stream_delete(:flags, flag)
         |> put_flash(:info, "Feature flag deleted")}
      else
        _ -> {:noreply, put_flash(socket, :error, "Could not delete flag")}
      end
    end)
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
         |> push_event("close-modal", %{id: "flag-modal"})}

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
             |> push_event("close-modal", %{id: "flag-modal"})}

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
      |> assign(
        :filtered_count,
        length(filtered(all, socket.assigns.search, socket.assigns.filter))
      )

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
    exception ->
      Logger.error(
        "[platform.settings_live] list_all_flags loading feature flags raised: #{Exception.message(exception)}"
      )

      []
  end

  defp filtered(all, search, filter) do
    q = normalize(search)

    all
    |> Enum.filter(&(matches_search?(&1, q) and matches_filter?(&1, filter)))
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

  # A glyph per flag so the grid reads by shape. Unknown keys fall back to a
  # flag rather than rendering nothing.
  @flag_icons %{
    "ai_agents" => "hero-cpu-chip",
    "api_access" => "hero-code-bracket",
    "audit_log" => "hero-clipboard-document-list",
    "custom_branding" => "hero-paint-brush",
    "digital_downloads" => "hero-arrow-down-tray",
    "dropship_network" => "hero-truck",
    "priority_support" => "hero-lifebuoy",
    "snap_to_shop" => "hero-camera",
    "sso" => "hero-key",
    "susu_plans" => "hero-banknotes",
    "webhooks" => "hero-bolt"
  }

  # A stream only re-renders an item when that item is re-inserted, so a card
  # whose markup depends on @confirming_id has to be pushed back through the
  # stream — changing the assign alone leaves the rendered card untouched.
  defp restream_flag(socket, nil), do: socket

  defp restream_flag(socket, id) do
    case Enum.find(socket.assigns.all_flags, &(&1.id == id)) do
      nil -> socket
      flag -> stream_insert(socket, :flags, flag)
    end
  end

  defp flag_icon(key), do: Map.get(@flag_icons, key, "hero-flag")

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
    |> assign(:flag_form, new_flag_form())
    |> assign(:form_errors, %{})
  end

  defp new_flag_form do
    to_form(%{
      "key" => "",
      "name" => "",
      "description" => "",
      "enabled" => true,
      "required_plan" => ""
    })
  end

  defp edit_flag_form(flag) do
    to_form(%{
      "key" => flag.key,
      "name" => flag.name,
      "description" => flag.description || "",
      "enabled" => flag.enabled,
      "required_plan" => flag.required_plan || ""
    })
  end

  defp put_flag_form(socket, params) do
    current_values =
      Map.new(@flag_form_fields, fn {field, key} ->
        {key, socket.assigns.flag_form[field].value}
      end)

    values = Map.merge(current_values, Map.take(params, Keyword.values(@flag_form_fields)))
    assign(socket, :flag_form, to_form(values))
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
      <%!-- Header. "Settings" is only feature flags today, so the page says
            so rather than promising a settings surface that does not exist. --%>
      <div class="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div class="flex items-center gap-4">
          <div class="w-13 h-13 rounded-card bg-primary flex items-center justify-center shrink-0 shadow-sm">
            <.icon name="hero-flag" class="size-7 text-white" />
          </div>
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Settings</h1>
            <p class="text-sm text-gray-500 mt-1">
              {if @stats,
                do: "Platform feature flags — what's switched on, and for which plans",
                else: "Loading feature flags…"}
            </p>
          </div>
        </div>
        <button
          :if={@all_flags}
          type="button"
          phx-click={JS.push("open_add_modal") |> show_modal("flag-modal")}
          class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold bg-primary text-white rounded-control hover:bg-primary-hover transition-colors cursor-pointer"
        >
          <.icon name="hero-plus" class="size-5" /> New flag
        </button>
      </div>

      <%!-- Loading shell (disconnected mount — no DB) --%>
      <div
        :if={is_nil(@all_flags)}
        class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
      >
        Loading feature flags…
      </div>

      <div :if={@all_flags}>
        <%!-- Stat strip --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <.stat_tile label="Total" value={@stats.total} icon="flag" color="blue" />
          <.stat_tile label="Enabled" value={@stats.enabled} icon="check_circle" color="emerald" />
          <.stat_tile
            label="Plan-gated"
            value={@stats.gated}
            icon="workspace_premium"
            color="amber"
          />
          <.stat_tile label="Disabled" value={@stats.disabled} icon="cancel" color="slate" />
        </div>

        <%!-- Toolbar --%>
        <div class="mb-5 flex items-center gap-3 flex-wrap">
          <.form
            for={@search_form}
            id="flag-search-form"
            phx-change="search"
            class="relative flex-1 min-w-[200px] max-w-sm"
          >
            <.icon
              name="hero-magnifying-glass"
              class="size-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
            />
            <.input
              field={@search_form[:search]}
              type="search"
              id="flag-search"
              placeholder="Search by name or key..."
              phx-debounce="300"
              class="w-full pl-11 pr-4 py-2.5 bg-surface border border-border rounded-control text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all"
            />
          </.form>
          <div class="flex items-center gap-1.5">
            <.chip filter="all" active={@filter} label="All" />
            <.chip filter="enabled" active={@filter} label="Enabled" />
            <.chip filter="disabled" active={@filter} label="Disabled" />
          </div>
        </div>

        <%!-- Empty states --%>
        <div
          :if={@stats.total == 0}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center"
        >
          <div class="w-16 h-16 rounded-card bg-primary-soft flex items-center justify-center mx-auto mb-3">
            <.icon name="hero-flag" class="size-8 text-primary" />
          </div>
          <p class="mt-2 text-sm font-medium text-gray-900">No feature flags yet</p>
          <p class="text-sm text-gray-400 mb-4">Create your first flag to start gating features.</p>
          <button
            type="button"
            phx-click={JS.push("open_add_modal") |> show_modal("flag-modal")}
            class="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold bg-primary text-white rounded-control hover:bg-primary-hover transition-colors cursor-pointer"
          >
            <.icon name="hero-plus" class="size-5" /> New flag
          </button>
        </div>

        <div
          :if={@stats.total > 0 and @filtered_count == 0}
          class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
        >
          No flags match your filters
        </div>

        <%!-- Card grid --%>
        <div
          id="flags"
          phx-update="stream"
          class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4"
        >
          <div
            :for={{dom_id, flag} <- @streams.flags}
            id={dom_id}
            class={[
              "bg-surface rounded-card border shadow-sm overflow-hidden flex flex-col",
              if(@confirming_id == flag.id,
                do: "border-warning shadow-lg",
                else: "border-border"
              )
            ]}
          >
            <%!-- Status reads as a rail across the top rather than a left
                  border — the tired accent-stripe card. --%>
            <div class={[
              "h-1",
              cond do
                @confirming_id == flag.id -> "bg-warning"
                flag.enabled -> "bg-primary"
                true -> "bg-slate-300"
              end
            ]}>
            </div>

            <div class="p-5 flex flex-col gap-4 flex-1">
              <div class="flex items-start justify-between gap-3">
                <div class="flex gap-3 min-w-0">
                  <%!-- An icon per flag, so eight of these are scannable by
                        shape instead of by reading eight names. --%>
                  <div class={[
                    "w-11 h-11 rounded-control flex items-center justify-center shrink-0",
                    if(flag.enabled, do: "bg-primary-soft", else: "bg-slate-100")
                  ]}>
                    <.icon
                      name={flag_icon(flag.key)}
                      class={["size-6", if(flag.enabled, do: "text-primary", else: "text-slate-400")]}
                    />
                  </div>
                  <div class="min-w-0">
                    <h3 class={[
                      "font-bold leading-tight",
                      if(flag.enabled, do: "text-gray-900", else: "text-slate-600")
                    ]}>
                      {flag.name}
                    </h3>
                    <span class="inline-block mt-1.5 font-mono text-[11px] px-2 py-0.5 rounded-md bg-slate-100 text-slate-600">
                      {flag.key}
                    </span>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="toggle"
                  phx-value-id={flag.id}
                  role="switch"
                  aria-checked={to_string(flag.enabled)}
                  aria-label="Toggle flag"
                  class={[
                    "relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition-colors cursor-pointer",
                    cond do
                      @confirming_id == flag.id -> "bg-warning"
                      flag.enabled -> "bg-primary"
                      true -> "bg-slate-300"
                    end
                  ]}
                >
                  <span class={[
                    "inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform",
                    cond do
                      @confirming_id == flag.id -> "translate-x-3.5"
                      flag.enabled -> "translate-x-6"
                      true -> "translate-x-1"
                    end
                  ]}>
                  </span>
                </button>
              </div>

              <p :if={@confirming_id != flag.id} class="text-sm text-slate-500 line-clamp-2">
                {if flag.description in [nil, ""], do: "No description", else: flag.description}
              </p>

              <div :if={@confirming_id != flag.id} class="flex items-center gap-2 flex-wrap">
                <span
                  :if={flag.required_plan}
                  class="inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-full bg-warning-soft text-warning font-semibold"
                >
                  <.icon name="hero-trophy" class="size-3.5" />
                  {String.capitalize(flag.required_plan)} and up
                </span>
                <span
                  :if={is_nil(flag.required_plan)}
                  class="text-xs px-2.5 py-1 rounded-full bg-slate-100 text-slate-600 font-semibold"
                >
                  All plans
                </span>
                <span class={[
                  "inline-flex items-center gap-1.5 text-xs px-2.5 py-1 rounded-full font-semibold",
                  if(flag.enabled,
                    do: "bg-success-soft text-success",
                    else: "bg-slate-100 text-slate-600"
                  )
                ]}>
                  <span class={[
                    "w-1.5 h-1.5 rounded-full",
                    if(flag.enabled, do: "bg-success", else: "bg-slate-400")
                  ]}>
                  </span>
                  {if flag.enabled, do: "Live", else: "Off"}
                </span>
              </div>

              <%!-- The confirm happens IN the card, so the flag being changed
                    stays on screen while the decision is made. --%>
              <div
                :if={@confirming_id == flag.id}
                class="rounded-control bg-warning-soft p-4 flex flex-col gap-3"
              >
                <div class="flex gap-2.5">
                  <.icon name="hero-exclamation-triangle" class="size-5 text-warning shrink-0" />
                  <p class="text-sm text-amber-800 text-pretty">
                    {if flag.enabled,
                      do: "Turn this off for every store now?",
                      else: "Turn this on for every store now?"}
                  </p>
                </div>
                <div class="flex gap-2">
                  <button
                    type="button"
                    phx-click="confirm_toggle"
                    phx-value-id={flag.id}
                    class="flex-1 h-9 rounded-lg bg-warning text-white text-sm font-bold cursor-pointer hover:opacity-90 transition-opacity"
                  >
                    {if flag.enabled, do: "Turn it off", else: "Turn it on"}
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_toggle"
                    class="flex-1 h-9 rounded-lg border border-border bg-surface text-slate-700 text-sm font-bold cursor-pointer hover:bg-slate-50 transition-colors"
                  >
                    Keep it
                  </button>
                </div>
              </div>

              <div class="mt-auto pt-3.5 border-t border-gray-100 flex items-center justify-between gap-3">
                <span class="text-xs text-slate-400">
                  Changed {Calendar.strftime(flag.updated_at, "%b %d")}
                </span>
                <div class="flex items-center gap-1.5">
                  <button
                    type="button"
                    phx-click={
                      JS.push("open_edit_modal", value: %{id: flag.id}) |> show_modal("flag-modal")
                    }
                    class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg border border-border bg-surface text-xs font-bold text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
                  >
                    <.icon name="hero-pencil" class="size-3.5" /> Edit
                  </button>
                  <button
                    type="button"
                    aria-label="Delete flag"
                    phx-click={
                      JS.push("open_delete_modal", value: %{id: flag.id})
                      |> show_modal("delete-flag-modal")
                    }
                    class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-rose-200 bg-surface text-rose-600 hover:bg-rose-50 transition-colors cursor-pointer"
                  >
                    <.icon name="hero-trash" class="size-3.5" />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Create / Edit modal --%>
      <.modal
        id="flag-modal"
        title={if @edit_flag_id, do: "Edit feature flag", else: "New feature flag"}
        size={:md}
      >
        <.form
          for={@flag_form}
          id="flag-form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-4"
        >
          <%!-- Name and Key side by side: they are one identity, and the
                key is immutable after creation, so it reads as a fact. --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label for="flag-name" class="block text-sm font-semibold text-slate-700 mb-1.5">
                Name <span class="text-red-500">*</span>
              </label>
              <.input
                field={@flag_form[:name]}
                type="text"
                id="flag-name"
                placeholder="New checkout"
                autocomplete="off"
                class={[
                  "w-full px-3.5 py-2.5 text-sm rounded-control border focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all",
                  if(@form_errors[:name], do: "border-red-300 bg-red-50", else: "border-border")
                ]}
              />
              <p :if={@form_errors[:name]} class="mt-1.5 text-xs text-red-600">
                {@form_errors[:name]}
              </p>
            </div>

            <div>
              <div class="flex items-center justify-between mb-1.5">
                <label for="flag-key" class="block text-sm font-semibold text-slate-700">
                  Key <span class="text-red-500">*</span>
                </label>
                <span :if={@edit_flag_id} class="text-xs text-slate-400">can't change</span>
              </div>
              <.input
                field={@flag_form[:key]}
                type="text"
                id="flag-key"
                disabled={@edit_flag_id != nil}
                placeholder="new_checkout"
                autocomplete="off"
                class={[
                  "w-full px-3.5 py-2.5 text-sm rounded-control border font-mono focus:ring-2 focus:ring-primary/20 focus:border-primary transition-all disabled:bg-surface-subtle disabled:text-slate-500",
                  if(@form_errors[:key], do: "border-red-300 bg-red-50", else: "border-border")
                ]}
              />
              <p :if={@form_errors[:key]} class="mt-1.5 text-xs text-red-600">
                {@form_errors[:key]}
              </p>
            </div>
          </div>

          <div>
            <label for="flag-description" class="block text-sm font-semibold text-slate-700 mb-1.5">
              What it does
            </label>
            <.input
              field={@flag_form[:description]}
              type="textarea"
              id="flag-description"
              rows="3"
              placeholder="One line a colleague would understand"
              class="w-full px-3.5 py-2.5 text-sm rounded-control border border-border focus:ring-2 focus:ring-primary/20 focus:border-primary resize-none transition-all"
            />
          </div>

          <%!-- The plan gate as pickable tiers: the current choice is visible
                without opening anything, which a <select> never is. --%>
          <div>
            <label class="block text-sm font-semibold text-slate-700 mb-2">Who gets it</label>
            <div id="flag-plan" class="grid grid-cols-2 sm:grid-cols-5 gap-2">
              <label
                :for={
                  {value, label} <- [
                    {"", "Everyone"} | Enum.map(@plans, &{&1, String.capitalize(&1)})
                  ]
                }
                for={"flag-plan-#{if value == "", do: "none", else: value}"}
                class="relative flex items-center justify-center gap-1.5 h-11 rounded-control border border-border text-sm font-semibold text-slate-600 cursor-pointer transition-colors has-[:checked]:border-2 has-[:checked]:border-primary has-[:checked]:bg-primary-soft has-[:checked]:text-primary"
              >
                <input
                  type="radio"
                  id={"flag-plan-#{if value == "", do: "none", else: value}"}
                  name="required_plan"
                  value={value}
                  checked={to_string(@flag_form[:required_plan].value || "") == value}
                  class="peer sr-only"
                />
                <.icon name="hero-check-circle" class="size-4 hidden peer-checked:block" />
                {label}
              </label>
            </div>
          </div>

          <%!-- On/off is the whole point of a flag; a tick-box hid it. --%>
          <label
            for="flag-enabled"
            class="flex items-center justify-between gap-5 p-4 rounded-control bg-surface-subtle cursor-pointer"
          >
            <div class="min-w-0">
              <span class="block text-sm font-bold text-slate-900">Switched on</span>
              <span class="block text-xs text-slate-500 mt-0.5">
                Stores on the chosen plan can see it straight away.
              </span>
            </div>
            <input type="hidden" name="enabled" value="false" />
            <input
              type="checkbox"
              id="flag-enabled"
              name="enabled"
              value="true"
              checked={@flag_form[:enabled].value in [true, "true"]}
              class="peer sr-only"
            />
            <span class="relative shrink-0 w-13 h-7 rounded-full bg-slate-300 peer-checked:bg-primary transition-colors after:content-[''] after:absolute after:top-1 after:left-1 after:w-5 after:h-5 after:rounded-full after:bg-white after:shadow after:transition-transform peer-checked:after:translate-x-6">
            </span>
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
        </.form>
      </.modal>

      <%!-- Delete confirmation --%>
      <.confirm_modal
        id="delete-flag-modal"
        title="Delete feature flag"
        message={
          if @delete_flag,
            do: "Delete \"#{@delete_flag.name}\"? This action cannot be undone.",
            else: "Delete this feature flag? This action cannot be undone."
        }
        confirm_text="Delete"
        confirm_class="bg-rose-600 hover:bg-rose-700 text-white"
        on_confirm="delete"
        value={@delete_flag && @delete_flag.id}
        icon="warning"
        icon_class="text-rose-500"
      />
    </div>
    """
  end

  # ── Function components ─────────────────────────────────

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
