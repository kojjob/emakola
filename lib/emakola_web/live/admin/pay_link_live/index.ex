defmodule EmakolaWeb.Admin.PayLinkLive.Index do
  @moduledoc """
  Merchant admin page for shareable pay links.

  Lists active/paid/cancelled links with funnel stats (opened, paid), a
  create modal for custom deals and catalog-variant links, per-link cancel,
  and copy/WhatsApp share affordances for the buyer-facing `/pay/:code` URL.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Orders.PayLink
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns[:current_store]
    merchant = socket.assigns[:current_merchant]

    case store do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Pay Links", active_nav: :pay_links)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        {links, item_variants} =
          if connected?(socket), do: load_links(store, merchant), else: {[], %{}}

        {:ok,
         socket
         |> assign(
           page_title: "Pay Links",
           active_nav: :pay_links,
           store: store,
           links: links,
           item_variants: item_variants,
           catalog_variants: [],
           show_create: false,
           create_type: "custom",
           created_link: nil,
           form_errors: %{}
         )}
    end
  end

  @impl true
  def handle_event("open_create", _params, socket) do
    {:noreply,
     assign(socket,
       show_create: true,
       create_type: "custom",
       created_link: nil,
       form_errors: %{},
       catalog_variants:
         load_catalog_variants(socket.assigns.store, socket.assigns.current_merchant)
     )}
  end

  @impl true
  def handle_event("close_create", _params, socket) do
    {:noreply, assign(socket, show_create: false, created_link: nil, form_errors: %{})}
  end

  @impl true
  def handle_event("set_create_type", %{"type" => type}, socket) do
    create_type = if type in ["custom", "catalog"], do: type, else: "custom"
    {:noreply, assign(socket, create_type: create_type, form_errors: %{})}
  end

  @impl true
  def handle_event("create", %{"pay_link" => params}, socket) do
    store = socket.assigns.store
    merchant = socket.assigns.current_merchant

    case build_create_attrs(params, store, merchant) do
      {:ok, attrs} ->
        case Emakola.Orders.create_pay_link(attrs, actor: merchant, tenant: store.id) do
          {:ok, link} ->
            {links, item_variants} = load_links(store, merchant)

            {:noreply,
             assign(socket,
               links: links,
               item_variants: item_variants,
               created_link: link,
               form_errors: %{}
             )}

          {:error, error} ->
            {:noreply, assign(socket, form_errors: %{base: create_error(error)})}
        end

      {:error, message} ->
        {:noreply, assign(socket, form_errors: %{base: message})}
    end
  end

  @impl true
  def handle_event("cancel_link", %{"id" => id}, socket) do
    store = socket.assigns.store
    merchant = socket.assigns.current_merchant

    with {:ok, link} <- Ash.get(PayLink, id, actor: merchant, tenant: store.id),
         {:ok, _cancelled} <-
           Emakola.Orders.cancel_pay_link(link, actor: merchant, tenant: store.id) do
      {links, item_variants} = load_links(store, merchant)

      {:noreply,
       socket
       |> assign(links: links, item_variants: item_variants)
       |> put_flash(:info, "Pay link cancelled")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Couldn't cancel that pay link")}
    end
  end

  # -- Render -----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6">
      <.admin_page_header
        title="Pay Links"
        subtitle="Share a checkout link for a custom deal or a catalog item"
      >
        <button
          type="button"
          phx-click="open_create"
          class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer focus-visible:ring-2 focus-visible:ring-emerald-500 focus-visible:ring-offset-2"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          New pay link
        </button>
      </.admin_page_header>

      <%!-- Stat tiles --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        <.stat_card
          label="Active Links"
          value={to_string(count_by_status(@links, :active))}
          icon_bg="bg-emerald-50"
        >
          <:icon><.icon name="hero-link" class="w-[18px] h-[18px] text-emerald-600" /></:icon>
        </.stat_card>
        <.stat_card label="Opened" value={to_string(total_opened(@links))} icon_bg="bg-violet-50">
          <:icon><.icon name="hero-eye" class="w-[18px] h-[18px] text-violet-600" /></:icon>
        </.stat_card>
        <.stat_card label="Paid" value={to_string(total_paid(@links))} icon_bg="bg-amber-50">
          <:icon><.icon name="hero-banknotes" class="w-[18px] h-[18px] text-amber-600" /></:icon>
        </.stat_card>
      </div>

      <%!-- Links table --%>
      <div class="bg-white rounded-2xl shadow-sm overflow-hidden mb-8">
        <div class="flex items-center justify-between px-6 py-5 border-b border-slate-100">
          <div>
            <h2 class="text-base font-bold text-slate-900">All Pay Links</h2>
            <p class="text-xs text-slate-400 mt-0.5">{length(@links)} pay links</p>
          </div>
        </div>

        <%= if @links == [] do %>
          <.empty_state
            icon="hero-link"
            title="No pay links yet"
            description="Create a pay link to share a custom deal or a catalog item over WhatsApp."
          />
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100">
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Item
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Amount
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Status
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Opened
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Paid orders
                  </th>
                  <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={link <- @links}
                  class="border-b border-slate-50 hover:bg-slate-50 transition-colors"
                >
                  <td class="px-6 py-4">
                    <p class="font-semibold text-slate-800">{item_label(link, @item_variants)}</p>
                    <p class="text-xs text-slate-400">
                      {if link.type == :catalog, do: "Catalog item", else: "Custom deal"}
                    </p>
                  </td>
                  <td class="px-6 py-4 font-mono text-slate-700">
                    {Currency.format_price(amount_for(link, @item_variants), @store.currency || "GHS")}
                  </td>
                  <td class="px-6 py-4"><.pay_link_status_pill status={link.status} /></td>
                  <td class="px-6 py-4 text-slate-600">{link.opened_count}</td>
                  <td class="px-6 py-4 text-slate-600">{link.paid_orders_count}</td>
                  <td class="px-6 py-4">
                    <div class="flex items-center justify-end gap-1">
                      <button
                        type="button"
                        phx-click={JS.dispatch("copy-to-clipboard", detail: %{text: share_url(link)})}
                        class="px-2.5 py-1.5 rounded-lg text-xs font-medium text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
                      >
                        Copy
                      </button>
                      <a
                        href={whatsapp_share_url(link, @store, @item_variants)}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="px-2.5 py-1.5 rounded-lg text-xs font-medium text-emerald-700 hover:bg-emerald-50 transition-colors cursor-pointer"
                      >
                        Share on WhatsApp
                      </a>
                      <button
                        :if={link.status == :active}
                        type="button"
                        id={"cancel-link-#{link.id}"}
                        phx-click="cancel_link"
                        phx-value-id={link.id}
                        data-confirm="Cancel this pay link? Buyers won't be able to pay it anymore."
                        class="px-2.5 py-1.5 rounded-lg text-xs font-medium text-red-600 hover:bg-red-50 transition-colors cursor-pointer"
                      >
                        Cancel
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <%!-- Create modal --%>
      <div :if={@show_create} class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-slate-900/40" phx-click="close_create"></div>

        <div class="relative bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-base font-bold text-slate-900">
              {if @created_link, do: "Pay link ready", else: "New pay link"}
            </h2>
            <button
              type="button"
              phx-click="close_create"
              class="text-slate-400 hover:text-slate-600 transition-colors cursor-pointer"
              aria-label="Close"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div :if={@created_link}>
            <p class="text-sm text-slate-600 mb-3">Share this link with your buyer:</p>
            <div class="flex items-center gap-2 mb-4">
              <input
                type="text"
                readonly
                value={share_url(@created_link)}
                class="flex-1 px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-700"
              />
              <button
                type="button"
                phx-click={
                  JS.dispatch("copy-to-clipboard", detail: %{text: share_url(@created_link)})
                }
                class="px-3 py-2 bg-slate-100 hover:bg-slate-200 rounded-xl text-xs font-semibold text-slate-700 transition-colors cursor-pointer"
              >
                Copy
              </button>
            </div>
            <a
              href={whatsapp_share_url(@created_link, @store, @item_variants)}
              target="_blank"
              rel="noopener noreferrer"
              class="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              Share on WhatsApp
            </a>
            <button
              type="button"
              phx-click="close_create"
              class="w-full mt-3 px-4 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
            >
              Done
            </button>
          </div>

          <form :if={!@created_link} id="pay-link-create-form" phx-submit="create" class="space-y-4">
            <input type="hidden" name="pay_link[type]" value={@create_type} />

            <div class="grid grid-cols-2 gap-2">
              <button
                type="button"
                phx-click="set_create_type"
                phx-value-type="custom"
                class={[
                  "px-3 py-2.5 rounded-xl text-sm font-medium border transition-colors cursor-pointer",
                  if(@create_type == "custom",
                    do: "bg-emerald-50 border-emerald-500 text-emerald-700",
                    else: "bg-slate-50 border-slate-200 text-slate-600 hover:border-slate-300"
                  )
                ]}
              >
                Custom deal
              </button>
              <button
                type="button"
                phx-click="set_create_type"
                phx-value-type="catalog"
                class={[
                  "px-3 py-2.5 rounded-xl text-sm font-medium border transition-colors cursor-pointer",
                  if(@create_type == "catalog",
                    do: "bg-emerald-50 border-emerald-500 text-emerald-700",
                    else: "bg-slate-50 border-slate-200 text-slate-600 hover:border-slate-300"
                  )
                ]}
              >
                From catalog
              </button>
            </div>

            <%= if @create_type == "custom" do %>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1.5" for="pay-link-title">
                  Title
                </label>
                <input
                  type="text"
                  id="pay-link-title"
                  name="pay_link[title]"
                  placeholder="e.g. Kente wrap dress"
                  class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1.5" for="pay-link-amount">
                  Amount (GH₵)
                </label>
                <input
                  type="text"
                  id="pay-link-amount"
                  name="pay_link[amount_ghs]"
                  placeholder="250.00"
                  class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm font-mono text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
                />
              </div>
            <% else %>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1.5" for="pay-link-variant">
                  Product
                </label>
                <select
                  id="pay-link-variant"
                  name="pay_link[variant_id]"
                  class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
                >
                  <option value="">Select a product…</option>
                  <option :for={variant <- @catalog_variants} value={variant.id}>
                    {variant_label(variant, @store.currency)}
                  </option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1.5" for="pay-link-quantity">
                  Quantity
                </label>
                <input
                  type="number"
                  id="pay-link-quantity"
                  name="pay_link[quantity]"
                  value="1"
                  min="1"
                  class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
                />
              </div>
            <% end %>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5" for="pay-link-expires-at">
                Expires on <span class="text-slate-400 font-normal">(optional)</span>
              </label>
              <input
                type="date"
                id="pay-link-expires-at"
                name="pay_link[expires_at]"
                class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
              <p class="text-xs text-slate-400 mt-1">
                Custom deals default to 7 days from creation if left blank.
              </p>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5" for="pay-link-note">
                Note <span class="text-slate-400 font-normal">(optional)</span>
              </label>
              <textarea
                id="pay-link-note"
                name="pay_link[note]"
                rows="2"
                maxlength="500"
                placeholder="Internal note about this link..."
                class="w-full px-3 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-700 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              ></textarea>
            </div>

            <label class="flex items-center gap-2 cursor-pointer">
              <input type="hidden" name="pay_link[collect_delivery]" value="false" />
              <input
                type="checkbox"
                name="pay_link[collect_delivery]"
                value="true"
                checked
                class="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
              />
              <span class="text-sm text-slate-600">Collect a delivery address at checkout</span>
            </label>

            <label
              :if={@store.buyer_protection_enabled}
              class="flex items-center gap-2 cursor-pointer"
            >
              <input type="hidden" name="pay_link[protected]" value="false" />
              <input
                type="checkbox"
                name="pay_link[protected]"
                value="true"
                checked
                class="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
              />
              <span class="text-sm text-slate-600">
                Buyer Protection — hold payment until delivery is confirmed
              </span>
            </label>

            <p :if={@form_errors[:base]} class="text-sm text-red-600">{@form_errors.base}</p>

            <div class="flex justify-end gap-3 pt-2">
              <button
                type="button"
                phx-click="close_create"
                class="px-4 py-2.5 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-xl transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
              >
                Create pay link
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # -- Components ---------------------------------------------------------

  attr :status, :atom, required: true

  defp pay_link_status_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full",
      pay_link_status_class(@status)
    ]}>
      <span class={["w-1.5 h-1.5 rounded-full", pay_link_status_dot(@status)]}></span>
      {pay_link_status_label(@status)}
    </span>
    """
  end

  defp pay_link_status_class(:active), do: "text-emerald-700 bg-emerald-50"
  defp pay_link_status_class(:paid), do: "text-blue-700 bg-blue-50"
  defp pay_link_status_class(:cancelled), do: "text-slate-500 bg-slate-100"
  defp pay_link_status_class(_), do: "text-slate-500 bg-slate-100"

  defp pay_link_status_dot(:active), do: "bg-emerald-500"
  defp pay_link_status_dot(:paid), do: "bg-blue-500"
  defp pay_link_status_dot(:cancelled), do: "bg-slate-400"
  defp pay_link_status_dot(_), do: "bg-slate-400"

  defp pay_link_status_label(:active), do: "Active"
  defp pay_link_status_label(:paid), do: "Paid"
  defp pay_link_status_label(:cancelled), do: "Cancelled"
  defp pay_link_status_label(_), do: "Unknown"

  # -- Data loading ---------------------------------------------------------

  defp load_links(store, merchant) do
    links = Emakola.Orders.list_pay_links_for_admin!(actor: merchant, tenant: store.id)
    {links, load_item_variants(links, store, merchant)}
  end

  # Batch-loads only the variants referenced by catalog-type links, keyed by
  # id, so the table and the post-create share block can render an item
  # name/price without a query per row.
  defp load_item_variants(links, store, merchant) do
    variant_ids =
      links
      |> Enum.filter(&(&1.type == :catalog))
      |> Enum.map(& &1.variant_id)
      |> Enum.uniq()

    case variant_ids do
      [] ->
        %{}

      ids ->
        Emakola.Catalog.Variant
        |> Ash.Query.filter(id in ^ids)
        |> Ash.Query.load(:product)
        |> Ash.read!(actor: merchant, tenant: store.id)
        |> Map.new(&{&1.id, &1})
    end
  end

  # v1 product picker: every available variant of an active product, no
  # search — the catalogs merchants run on this platform are small.
  defp load_catalog_variants(store, merchant) do
    Emakola.Catalog.list_variants_by_store!(store.id, actor: merchant, tenant: store.id)
    |> Enum.filter(&active_variant?/1)
  end

  defp active_variant?(%{available: true, product: %{status: :active}}), do: true
  defp active_variant?(_), do: false

  defp variant_label(%{product: %{title: title}} = variant, currency) do
    sku_suffix = if presence(variant.sku), do: " (#{variant.sku})", else: ""
    "#{title}#{sku_suffix} — #{Currency.format_price(variant.price, currency || "GHS")}"
  end

  # -- Create form helpers ---------------------------------------------------

  defp build_create_attrs(params, store, merchant) do
    type = Emakola.SafeAtom.to_atom_in(params["type"], [:custom, :catalog], :custom)
    attrs_for_type(type, params, store, merchant)
  end

  defp attrs_for_type(:custom, params, store, merchant) do
    with {:title, title} when not is_nil(title) <- {:title, presence(params["title"])},
         {:ok, pesewas} <- parse_ghs(params["amount_ghs"]),
         {:ok, expiry} <- parse_expiry(presence(params["expires_at"])) do
      {:ok,
       %{
         store_id: store.id,
         type: :custom,
         title: title,
         amount: pesewas,
         created_by_user_id: merchant.id
       }
       |> maybe_put(:expires_at, expiry)
       |> maybe_put(:note, presence(params["note"]))
       |> maybe_put_collect_delivery(params)
       |> maybe_put_protected(params)}
    else
      {:title, nil} -> {:error, "Enter a title for this deal."}
      {:error, message} -> {:error, message}
    end
  end

  defp attrs_for_type(:catalog, params, store, merchant) do
    with {:variant, variant_id} when not is_nil(variant_id) <-
           {:variant, presence(params["variant_id"])},
         {:ok, variant} <- fetch_store_variant(variant_id, store, merchant),
         {:ok, expiry} <- parse_expiry(presence(params["expires_at"])) do
      {:ok,
       %{
         store_id: store.id,
         type: :catalog,
         variant_id: variant.id,
         quantity: parse_quantity(params["quantity"]),
         created_by_user_id: merchant.id
       }
       |> maybe_put(:expires_at, expiry)
       |> maybe_put(:note, presence(params["note"]))
       |> maybe_put_collect_delivery(params)
       |> maybe_put_protected(params)}
    else
      {:variant, nil} -> {:error, "Choose a product for this pay link."}
      {:error, message} -> {:error, message}
    end
  end

  # Tenant-scoped lookup, not a bare pass-through of the submitted id — a
  # crafted `create` event (bypassing the rendered <select>, which only ever
  # lists this store's own variants) could otherwise point a catalog link at
  # another store's variant.
  defp fetch_store_variant(variant_id, store, merchant) do
    case Ash.get(Emakola.Catalog.Variant, variant_id, actor: merchant, tenant: store.id) do
      {:ok, variant} -> {:ok, variant}
      _ -> {:error, "Choose a valid product for this pay link."}
    end
  end

  # Better than `trunc(Decimal.to_float(...) * 100)` — stays in Decimal
  # arithmetic throughout, so a value like "250.10" can't drift to a
  # binary-float-rounded 25009 pesewas.
  defp parse_ghs(value) do
    pesewas =
      value
      |> to_string()
      |> String.trim()
      |> Decimal.new()
      |> Decimal.mult(100)
      |> Decimal.round(0)
      |> Decimal.to_integer()

    {:ok, pesewas}
  rescue
    _ -> {:error, "Enter a valid amount in GH₵, e.g. 250 or 250.00."}
  end

  defp parse_quantity(value) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_expiry(nil), do: {:ok, nil}

  defp parse_expiry(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, DateTime.new!(date, ~T[23:59:59], "Etc/UTC")}
      {:error, _} -> {:error, "Enter a valid expiry date."}
    end
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)

  defp maybe_put_collect_delivery(attrs, %{"collect_delivery" => value}),
    do: Map.put(attrs, :collect_delivery, value in ["true", "on"])

  defp maybe_put_collect_delivery(attrs, _params), do: attrs

  # Only present in params when the override checkbox was rendered (store's
  # buyer_protection_enabled is on); otherwise `protected` is left unset and
  # PayLink's :create change inherits the store setting.
  defp maybe_put_protected(attrs, %{"protected" => value}),
    do: Map.put(attrs, :protected, value in ["true", "on"])

  defp maybe_put_protected(attrs, _params), do: attrs

  defp create_error(error), do: Exception.message(error)

  defp presence(nil), do: nil

  defp presence(value) do
    trimmed = value |> to_string() |> String.trim()
    if trimmed == "", do: nil, else: trimmed
  end

  # -- Stats ------------------------------------------------------------------

  defp count_by_status(links, status), do: Enum.count(links, &(&1.status == status))
  defp total_opened(links), do: Enum.sum(Enum.map(links, & &1.opened_count))
  defp total_paid(links), do: Enum.sum(Enum.map(links, & &1.paid_orders_count))

  # -- Item/amount/share helpers ----------------------------------------------

  defp item_label(%PayLink{type: :custom, title: title}, _item_variants), do: title

  defp item_label(%PayLink{type: :catalog, variant_id: variant_id}, item_variants) do
    case Map.get(item_variants, variant_id) do
      %{product: %{title: title}} -> title
      _ -> "Unknown product"
    end
  end

  defp amount_for(%PayLink{type: :custom, amount: amount}, _item_variants), do: amount

  defp amount_for(%PayLink{type: :catalog, variant_id: variant_id, quantity: qty}, item_variants) do
    case Map.get(item_variants, variant_id) do
      %{price: price} -> price * qty
      _ -> 0
    end
  end

  defp share_url(link), do: "#{EmakolaWeb.Endpoint.url()}/pay/#{link.code}"

  defp whatsapp_share_url(link, store, item_variants) do
    text =
      "#{store.name}: #{item_label(link, item_variants)} — " <>
        "#{Currency.format_price(amount_for(link, item_variants), store.currency || "GHS")}. " <>
        "Pay securely: #{share_url(link)}"

    "https://wa.me/?text=#{URI.encode_www_form(text)}"
  end
end
