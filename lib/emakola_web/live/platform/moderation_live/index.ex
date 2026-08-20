defmodule EmakolaWeb.Platform.ModerationLive.Index do
  @moduledoc """
  Platform "Moderation Studio": a split view over products across all
  stores — a searchable, filterable queue on the left and a case panel
  for the selected product on the right, with large evidence imagery,
  an inline takedown reason (no modal), reinstate, and the product's
  moderation history from the platform audit log.

  Gated by RequirePermission (:manage_stores). No DB queries during the
  disconnected render. Takedown/reinstate run with `authorize?: false`
  (the Product policy forbids actor-based calls), re-check the
  permission per event, record a platform audit entry, and notify the
  merchant. Mutations only reach products in the currently loaded
  queue, so forged events cannot touch anything outside it.
  """
  use EmakolaWeb, :live_view
  require Logger
  require Ash.Query

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_stores}

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformPermissions
  alias Emakola.Catalog
  alias Emakola.Notifications.Workers.ProductModerationNotificationWorker
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Moderation")
      |> assign(:active_nav, :moderation)
      |> assign(:search, "")
      |> assign(:search_form, to_form(%{"search" => ""}))
      |> assign(:filter, :all)
      |> assign(:takedown_form, to_form(%{"reason" => ""}))
      |> assign(:product_ids, MapSet.new())
      |> assign(:total_count, 0)
      |> assign(:taken_down_count, 0)
      |> assign(:products_count, 0)
      |> assign(:products_loaded?, false)
      |> assign(:selected, nil)
      |> assign(:history, [])
      |> assign(:history_actors, %{})
      |> stream(:products, [], dom_id: &"moderation-product-#{&1.id}")

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    {:noreply,
     socket
     |> assign(:search, query)
     |> assign(:search_form, to_form(%{"search" => query}))
     |> load()}
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    filter = if filter == "taken_down", do: :taken_down, else: :all
    {:noreply, socket |> assign(:filter, filter) |> load()}
  end

  def handle_event("select_product", %{"id" => id}, socket) do
    {:noreply, load(socket, select_id: id)}
  end

  def handle_event("confirm_takedown", %{"reason" => reason} = params, socket) do
    socket = assign(socket, :takedown_form, to_form(params))

    authorized(socket, fn socket ->
      reason = String.trim(reason || "")
      product = socket.assigns.selected && find_product(socket, socket.assigns.selected.id)

      cond do
        is_nil(product) ->
          {:noreply, socket}

        reason == "" ->
          {:noreply, put_flash(socket, :error, "A reason is required.")}

        true ->
          run(socket, Catalog.take_down_product(product, %{reason: reason}, authorize?: false),
            product: product,
            event: :product_taken_down,
            reason: reason,
            flash: "Product taken down."
          )
      end
    end)
  end

  def handle_event("reinstate", %{"id" => id}, socket) do
    authorized(socket, fn socket ->
      case find_product(socket, id) do
        nil ->
          {:noreply, socket}

        product ->
          run(socket, Catalog.reinstate_product(product, %{}, authorize?: false),
            product: product,
            event: :product_reinstated,
            reason: nil,
            flash: "Product reinstated."
          )
      end
    end)
  end

  defp run(socket, {:ok, _updated}, opts) do
    product = Keyword.fetch!(opts, :product)
    event = Keyword.fetch!(opts, :event)
    reason = Keyword.get(opts, :reason)

    PlatformAudit.log(event, socket.assigns.current_user, audit_metadata(product, reason))
    ProductModerationNotificationWorker.enqueue(product.id, event)

    {:noreply,
     socket
     |> assign(:takedown_form, to_form(%{"reason" => ""}))
     |> load(select_id: product.id)
     |> put_flash(:info, Keyword.fetch!(opts, :flash))}
  end

  defp run(socket, {:error, _}, _opts) do
    {:noreply, put_flash(socket, :error, "Could not update the product.")}
  end

  defp audit_metadata(product, reason) do
    base = %{
      "product_id" => product.id,
      "product_title" => product.title,
      "store_id" => product.store_id
    }

    if reason, do: Map.put(base, "reason", reason), else: base
  end

  # Only products in the currently loaded queue are reachable by events.
  defp find_product(socket, id) do
    if MapSet.member?(socket.assigns.product_ids, id) do
      case Catalog.get_product(id, authorize?: false) do
        {:ok, product} -> product
        _ -> nil
      end
    end
  end

  defp authorized(socket, fun) do
    if PlatformPermissions.allowed?(reload_current_user(socket), :manage_stores) do
      fun.(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to moderate content.")}
    end
  end

  defp reload_current_user(socket) do
    case Emakola.Accounts.get_user_by_id(socket.assigns.current_user.id, authorize?: false) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  defp load(socket, opts \\ []) do
    search = String.trim(socket.assigns.search)

    products =
      case Catalog.list_products_for_moderation(%{search: search, moderation: nil},
             authorize?: false
           ) do
        {:ok, list} -> list
        _ -> []
      end

    assign_products(socket, products, opts)
  rescue
    exception ->
      Logger.error(
        "[platform.moderation_live] load loading products raised: #{Exception.message(exception)}"
      )

      assign_products(socket, [], opts)
  end

  defp assign_products(socket, products, opts) do
    filtered = apply_filter(products, socket.assigns.filter)

    preferred_id =
      Keyword.get(opts, :select_id) ||
        (socket.assigns.selected && socket.assigns.selected.id)

    selected = Enum.find(filtered, &(&1.id == preferred_id)) || List.first(filtered)

    socket
    |> assign(:product_ids, MapSet.new(filtered, & &1.id))
    |> assign(:total_count, length(products))
    |> assign(:taken_down_count, Enum.count(products, &(&1.moderation_status == :taken_down)))
    |> assign(:products_count, length(filtered))
    |> assign(:products_loaded?, true)
    |> assign(:selected, selected)
    |> assign_history(selected)
    |> stream(:products, Enum.map(filtered, &product_row(&1, selected)), reset: true)
  end

  defp apply_filter(products, :taken_down),
    do: Enum.filter(products, &(&1.moderation_status == :taken_down))

  defp apply_filter(products, _all), do: products

  defp product_row(product, selected) do
    %{id: product.id, product: product, selected?: selected != nil && selected.id == product.id}
  end

  defp assign_history(socket, nil), do: assign(socket, history: [], history_actors: %{})

  defp assign_history(socket, product) do
    entries =
      case PlatformAuditLog
           |> Ash.Query.for_read(:list_for_product, %{product_id: product.id})
           |> Ash.read(authorize?: false) do
        {:ok, list} -> list
        _ -> []
      end

    assign(socket, history: entries, history_actors: actor_emails(entries))
  rescue
    exception ->
      Logger.error(
        "[platform.moderation_live] assign_history raised: #{Exception.message(exception)}"
      )

      assign(socket, history: [], history_actors: %{})
  end

  defp actor_emails(entries) do
    ids = entries |> Enum.map(& &1.actor_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    case ids do
      [] ->
        %{}

      ids ->
        case Emakola.Accounts.User
             |> Ash.Query.filter(id in ^ids)
             |> Ash.read(authorize?: false) do
          {:ok, users} -> Map.new(users, &{&1.id, &1.email})
          _ -> %{}
        end
    end
  end

  defp thumb(%{images: [%{url: url} | _]}) when is_binary(url), do: url
  defp thumb(_), do: nil

  defp photo_count(%{images: images}) when is_list(images), do: length(images)
  defp photo_count(_), do: 0

  defp taken_down?(product), do: product.moderation_status == :taken_down

  defp price_label(product) do
    case Map.get(product, :min_price) do
      price when is_integer(price) ->
        currency = (product.store && Map.get(product.store, :currency)) || "GHS"
        Currency.format_price(price, currency)

      _ ->
        nil
    end
  end

  defp history_label(:product_taken_down), do: "Taken down"
  defp history_label(:product_reinstated), do: "Reinstated"

  defp history_label(action),
    do: action |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp history_chip_class(:product_taken_down), do: "bg-rose-100 text-rose-600"
  defp history_chip_class(:product_reinstated), do: "bg-green-100 text-green-700"
  defp history_chip_class(_), do: "bg-slate-100 text-slate-500"

  defp history_icon(:product_taken_down), do: "hero-no-symbol"
  defp history_icon(:product_reinstated), do: "hero-arrow-path"
  defp history_icon(_), do: "hero-pencil-square"

  defp filter_chip_classes(active?) do
    [
      "inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11.5px] transition-colors cursor-pointer",
      if(active?,
        do: "bg-slate-900 text-white font-semibold",
        else:
          "bg-slate-50 text-slate-600 font-medium ring-1 ring-inset ring-slate-200 hover:bg-slate-100"
      )
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-6 flex items-end justify-between gap-4 flex-wrap">
        <div>
          <h1 class="text-2xl font-bold text-gray-900 tracking-tight">Moderation</h1>
          <p class="text-sm text-gray-500 mt-1">
            Review listings across all stores and take down policy violations
          </p>
        </div>
        <div :if={@products_loaded?} class="flex items-center gap-2">
          <.severity_pill label={"#{@total_count} products"} tone="blue" />
          <.severity_pill label={"#{@taken_down_count} taken down"} tone="rose" />
        </div>
      </div>

      <%!-- Split view: queue + case panel --%>
      <div class="flex flex-col lg:flex-row bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden lg:h-[calc(100vh-15rem)] lg:min-h-[560px]">
        <%!-- Product queue --%>
        <div class="w-full lg:w-[360px] shrink-0 border-b lg:border-b-0 lg:border-r border-gray-100 flex flex-col max-h-96 lg:max-h-none">
          <div class="p-4 border-b border-gray-100">
            <.form
              for={@search_form}
              id="moderation-search-form"
              phx-change="search"
              phx-debounce="300"
              class="relative"
            >
              <.icon
                name="hero-magnifying-glass"
                class="size-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none"
              />
              <.input
                field={@search_form[:search]}
                type="search"
                id="moderation-search"
                placeholder="Search by title or slug…"
                autocomplete="off"
                class="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-[10px] text-[13px] text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
              />
            </.form>
            <div class="flex items-center gap-1.5 mt-2.5">
              <button
                type="button"
                id="moderation-filter-all"
                phx-click="filter"
                phx-value-filter="all"
                class={filter_chip_classes(@filter == :all)}
              >
                All <span class="opacity-60 tabular-nums">{@total_count}</span>
              </button>
              <button
                type="button"
                id="moderation-filter-taken_down"
                phx-click="filter"
                phx-value-filter="taken_down"
                class={filter_chip_classes(@filter == :taken_down)}
              >
                Taken down <span class="opacity-60 tabular-nums">{@taken_down_count}</span>
              </button>
            </div>
          </div>
          <div
            id="moderation-products"
            phx-update="stream"
            data-count={@products_count}
            class="flex-1 overflow-y-auto p-2"
          >
            <div
              :if={!@products_loaded?}
              id="moderation-products-loading"
              class="px-4 py-12 text-center text-sm text-gray-400"
            >
              Loading products…
            </div>
            <div
              :if={@products_loaded? && @products_count == 0}
              id="moderation-products-empty"
              class="px-4 py-12 text-center text-sm text-gray-400"
            >
              No products found
            </div>
            <div
              :for={{id, %{product: p, selected?: selected?}} <- @streams.products}
              id={id}
              role="button"
              tabindex="0"
              phx-click="select_product"
              phx-value-id={p.id}
              data-selected={selected?}
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-[10px] cursor-pointer transition-colors",
                if(selected?,
                  do: "bg-blue-50 shadow-[inset_3px_0_0_#3b82f6]",
                  else: "hover:bg-slate-50"
                )
              ]}
            >
              <img
                :if={thumb(p)}
                src={thumb(p)}
                alt=""
                loading="lazy"
                class="w-9 h-9 rounded-[9px] object-cover bg-slate-100 shrink-0"
              />
              <div
                :if={!thumb(p)}
                class="w-9 h-9 rounded-[9px] bg-slate-100 flex items-center justify-center shrink-0"
              >
                <.icon name="hero-photo" class="size-4 text-slate-300" />
              </div>
              <div class="min-w-0 flex-1">
                <p class={[
                  "text-[13.5px] font-semibold leading-tight truncate",
                  if(selected?, do: "text-gray-900", else: "text-slate-700")
                ]}>
                  {p.title}
                </p>
                <p class="text-[11px] text-gray-400 truncate leading-tight mt-0.5">
                  {p.store && p.store.name}
                </p>
              </div>
              <span class={[
                "w-2 h-2 rounded-full shrink-0",
                if(taken_down?(p), do: "bg-red-400", else: "bg-green-500")
              ]}>
              </span>
            </div>
          </div>
        </div>

        <%!-- Case panel --%>
        <div class="flex-1 min-w-0 overflow-y-auto">
          <div :if={@selected} id="moderation-panel" class="p-6 lg:p-7">
            <%!-- Evidence image --%>
            <div class="h-60 rounded-[14px] bg-gradient-to-br from-slate-100 to-slate-50 relative overflow-hidden flex items-center justify-center">
              <img
                :if={thumb(@selected)}
                src={thumb(@selected)}
                alt=""
                class="absolute inset-0 w-full h-full object-cover"
              />
              <.icon :if={!thumb(@selected)} name="hero-photo" class="size-10 text-slate-300" />
              <span
                :if={taken_down?(@selected)}
                class="absolute top-2.5 left-3 inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-600 text-white"
              >
                <.icon name="hero-no-symbol" class="size-2.5" /> TAKEN DOWN
              </span>
              <span
                :if={photo_count(@selected) > 1}
                class="absolute bottom-2.5 right-3 text-[11px] font-semibold text-slate-600 bg-white/85 px-2 py-0.5 rounded-full"
              >
                {photo_count(@selected)} photos
              </span>
            </div>

            <%!-- Identity --%>
            <div class="flex flex-wrap items-start gap-3 mt-5">
              <div class="min-w-0 flex-1">
                <div class="flex items-center gap-2 flex-wrap">
                  <h2 class="text-xl font-bold text-gray-900 tracking-tight truncate">
                    {@selected.title}
                  </h2>
                  <.severity_pill
                    label={if taken_down?(@selected), do: "Taken down", else: "OK"}
                    tone={if taken_down?(@selected), do: "rose", else: "green"}
                  />
                </div>
                <p class="text-[13px] text-gray-500 mt-0.5 truncate">
                  {"#{(@selected.store && @selected.store.name) || "Unknown store"}#{if price_label(@selected), do: " · #{price_label(@selected)}"} · Listed #{Calendar.strftime(@selected.inserted_at, "%b %d, %Y")}"}
                </p>
              </div>
              <a
                href={"/s/#{@selected.store && @selected.store.slug}/products/#{@selected.slug}"}
                target="_blank"
                class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-blue-600 bg-white ring-1 ring-inset ring-gray-200 hover:bg-slate-50 transition-colors shrink-0"
              >
                View listing <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
              </a>
            </div>

            <div class="h-px bg-gray-100 my-6"></div>

            <div class="flex flex-col xl:flex-row gap-7">
              <%!-- Takedown / status --%>
              <div class="flex-1 min-w-0">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  {if taken_down?(@selected), do: "Status", else: "Take down"}
                </p>
                <div
                  :if={!taken_down?(@selected)}
                  class="border border-gray-200 rounded-xl p-4"
                >
                  <.form
                    for={@takedown_form}
                    id="moderation-takedown-form"
                    phx-submit="confirm_takedown"
                  >
                    <.input
                      field={@takedown_form[:reason]}
                      type="textarea"
                      id="moderation-takedown-reason"
                      rows="3"
                      placeholder="Reason — shown to the merchant…"
                      class="w-full rounded-[10px] border border-slate-200 bg-slate-50 px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 focus:bg-white"
                    />
                    <div class="mt-3 flex items-center justify-between gap-3">
                      <p class="text-[11px] text-gray-400">
                        Hidden from customers immediately. The merchant is notified.
                      </p>
                      <button
                        type="submit"
                        class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-rose-600 hover:bg-rose-500 transition-colors shrink-0"
                      >
                        <.icon name="hero-no-symbol" class="size-3.5" /> Take down product
                      </button>
                    </div>
                  </.form>
                </div>
                <div
                  :if={taken_down?(@selected)}
                  id="panel-takedown-banner"
                  class="rounded-xl p-4 bg-rose-50 ring-1 ring-inset ring-rose-200"
                >
                  <div class="flex items-start gap-2.5">
                    <.icon
                      name="hero-exclamation-triangle"
                      class="size-4 text-rose-600 shrink-0 mt-0.5"
                    />
                    <div class="min-w-0">
                      <p class="text-[13px] font-bold text-rose-700">Taken down</p>
                      <p :if={@selected.moderation_reason} class="text-[13px] text-rose-900 mt-0.5">
                        {@selected.moderation_reason}
                      </p>
                    </div>
                  </div>
                  <div class="mt-3.5 flex items-center justify-between gap-3">
                    <p class="text-[11px] text-rose-700/75">
                      Hidden from customers. The merchant was notified with this reason.
                    </p>
                    <button
                      type="button"
                      id="panel-reinstate"
                      phx-click="reinstate"
                      phx-value-id={@selected.id}
                      class="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-[10px] text-[13px] font-semibold text-white bg-green-600 hover:bg-green-500 transition-colors shrink-0"
                    >
                      <.icon name="hero-arrow-path" class="size-3.5" /> Reinstate
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Moderation history --%>
              <div class="w-full xl:w-[260px] shrink-0">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-3">
                  Moderation history
                </p>
                <div id="panel-history" class="flex flex-col gap-3">
                  <p :if={@history == []} class="text-[13px] text-gray-400">
                    No moderation events yet.
                  </p>
                  <div :for={entry <- @history} class="flex items-start gap-2.5">
                    <span class={[
                      "flex w-7 h-7 items-center justify-center rounded-lg shrink-0",
                      history_chip_class(entry.action)
                    ]}>
                      <.icon name={history_icon(entry.action)} class="size-3.5" />
                    </span>
                    <div class="min-w-0">
                      <p class="text-[12.5px] font-semibold text-gray-900 leading-snug">
                        {history_label(entry.action)}
                      </p>
                      <p :if={entry.metadata["reason"]} class="text-xs text-gray-600 leading-snug">
                        {entry.metadata["reason"]}
                      </p>
                      <p class="text-[11px] text-gray-400 leading-snug mt-0.5">
                        {"#{Calendar.strftime(entry.inserted_at, "%b %d")} · #{Map.get(@history_actors, entry.actor_id, "system")}"}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div :if={@products_loaded? && is_nil(@selected)} class="p-6 lg:p-7">
            <.platform_empty_state
              icon="hero-shield-check"
              title="No product selected"
              description="Choose a listing from the queue to review it."
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
