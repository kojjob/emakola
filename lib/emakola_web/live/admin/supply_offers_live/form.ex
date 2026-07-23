defmodule EmakolaWeb.Admin.SupplyOffersLive.Form do
  @moduledoc """
  Create/edit a supplier offer: product picker (locked after creation),
  earning-model-dependent variant pricing, Ghana-region delivery areas with
  optional per-area dispatch fees, and supplier terms. All writes go through
  Emakola.Suppliers.Offers; prices parse via Emakola.Money.parse_price/1.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Money
  alias Emakola.Suppliers.{GhanaRegions, Offers}

  @term_fields ~w(return_terms returns_window_days warranty_months warranty_terms)
  @price_fields ~w(supplier suggested max commission)

  @impl true
  def mount(params, _session, socket) do
    socket = assign(socket, page_title: "Supplier offer", active_nav: :supply_offers)

    if connected?(socket) do
      init(socket, socket.assigns.live_action, params)
    else
      {:ok, assign(socket, loading: true, action: :new, offer: nil)}
    end
  end

  defp init(socket, :new, _params) do
    {:ok,
     socket
     |> base_assigns(:new)
     |> assign(products: load_products(socket), product: nil)}
  end

  defp init(socket, :edit, %{"id" => id}) do
    with %{id: store_id} <- socket.assigns[:current_store],
         {:ok, offers} <- Offers.list_owned(socket.assigns.current_merchant, store_id),
         %{} = offer <- Enum.find(offers, &(&1.id == id && &1.status != :archived)) do
      {:ok,
       socket
       |> base_assigns(:edit)
       |> assign(products: [], product: offer.source_product)
       |> hydrate(offer)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "That offer is not in your store.")
         |> push_navigate(to: ~p"/admin/supply/offers")}
    end
  end

  defp base_assigns(socket, action) do
    assign(socket,
      loading: false,
      action: action,
      offer: nil,
      product: nil,
      model: "markup",
      rows: %{},
      areas: MapSet.new(),
      fees: %{},
      terms: %{},
      errors: %{},
      locked?: false
    )
  end

  defp hydrate(socket, offer) do
    rows =
      Map.new(offer.offer_variants, fn terms ->
        {terms.source_variant_id,
         %{
           "supplier" => pesewas_to_input(terms.supplier_price),
           "suggested" => pesewas_to_input(terms.suggested_retail_price),
           "max" => pesewas_to_input(terms.max_retail_price),
           "commission" => pesewas_to_input(terms.fixed_commission_amount),
           terms_id: terms.id
         }}
      end)

    assign(socket,
      offer: offer,
      model: to_string(offer.earning_model),
      rows: rows,
      areas: MapSet.new(offer.delivery_areas),
      fees: Map.new(offer.dispatch_fees, fn {k, v} -> {k, pesewas_to_input(v)} end),
      terms: %{
        "return_terms" => offer.return_terms || "",
        "returns_window_days" => to_string(offer.returns_window_days || ""),
        "warranty_months" => to_string(offer.warranty_months || ""),
        "warranty_terms" => offer.warranty_terms || ""
      },
      locked?: offer.status == :published
    )
  end

  defp pesewas_to_input(nil), do: ""
  defp pesewas_to_input(pesewas), do: :erlang.float_to_binary(pesewas / 100, decimals: 2)

  # ── Events ──

  @impl true
  def handle_event("select_product", %{"product_id" => id}, socket) when is_binary(id) do
    case Enum.find(socket.assigns.products, &(&1.id == id)) do
      nil -> {:noreply, socket}
      product -> {:noreply, assign(socket, product: product, rows: %{})}
    end
  end

  def handle_event("select_model", %{"model" => model}, socket)
      when model in ["markup", "fixed_commission"] do
    if socket.assigns.offer do
      {:noreply, socket}
    else
      {:noreply, assign(socket, model: model)}
    end
  end

  def handle_event(
        "set_variant_price",
        %{"variant-id" => vid, "field" => f, "value" => v},
        socket
      )
      when is_binary(vid) and f in @price_fields and is_binary(v) do
    rows =
      Map.update(
        socket.assigns.rows,
        vid,
        %{"supplier" => "", "suggested" => "", "max" => "", "commission" => "", terms_id: nil}
        |> Map.put(f, v),
        &Map.put(&1, f, v)
      )

    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("toggle_region", %{"region" => region}, socket) when is_binary(region) do
    if region in GhanaRegions.all() do
      {areas, fees} =
        if MapSet.member?(socket.assigns.areas, region) do
          {MapSet.delete(socket.assigns.areas, region), Map.delete(socket.assigns.fees, region)}
        else
          {MapSet.put(socket.assigns.areas, region), socket.assigns.fees}
        end

      {:noreply, assign(socket, areas: areas, fees: fees)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_region_fee", %{"region" => region, "value" => v}, socket)
      when is_binary(region) and is_binary(v) do
    if MapSet.member?(socket.assigns.areas, region) do
      {:noreply, assign(socket, fees: Map.put(socket.assigns.fees, region, v))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_term", %{"field" => f, "value" => v}, socket)
      when f in @term_fields and is_binary(v) do
    {:noreply, assign(socket, terms: Map.put(socket.assigns.terms, f, v))}
  end

  def handle_event("save_draft", _params, socket) do
    save(socket)
  end

  def handle_event("publish", _params, socket) do
    case do_save(socket) do
      {:ok, offer} ->
        case Offers.publish(socket.assigns.current_merchant, offer) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Offer published — it is now live in the catalog.")
             |> push_navigate(to: ~p"/admin/supply/offers")}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, publish_error_message(reason))
             |> push_navigate(to: ~p"/admin/supply/offers/#{offer.id}/edit")}
        end

      {:error_socket, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_variant", %{"terms-id" => terms_id}, socket)
      when is_binary(terms_id) do
    offer = socket.assigns.offer
    variant = offer && Enum.find(offer.offer_variants, &(&1.id == terms_id))

    case variant && Offers.remove_variant(socket.assigns.current_merchant, offer, variant) do
      :ok ->
        {:noreply,
         assign(socket,
           offer: with_variants(offer),
           rows: Map.delete(socket.assigns.rows, variant.source_variant_id)
         )}

      _ ->
        {:noreply, put_flash(socket, :error, "That row could not be removed right now.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # ── Save ──

  defp save(socket) do
    case do_save(socket) do
      {:ok, offer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Draft saved.")
         |> push_navigate(to: ~p"/admin/supply/offers/#{offer.id}/edit")}

      {:error_socket, socket} ->
        {:noreply, socket}
    end
  end

  defp do_save(%{assigns: %{product: nil}} = socket),
    do: {:error_socket, assign(socket, errors: %{base: "Pick a product first."})}

  # Published offers: terms-only save — pricing rows are locked in the UI and
  # deliberately not written here either.
  defp do_save(%{assigns: %{locked?: true, offer: offer}} = socket) do
    case parse_fees(socket) do
      {:ok, fees} ->
        case Offers.update_terms(socket.assigns.current_merchant, offer, term_attrs(socket, fees)) do
          {:ok, offer} -> {:ok, offer}
          {:error, _} -> {:error_socket, put_flash(socket, :error, "Terms could not be saved.")}
        end

      {:error, errors} ->
        {:error_socket, assign(socket, errors: errors)}
    end
  end

  defp do_save(socket) do
    with {:ok, priced} <- parse_rows(socket),
         {:ok, fees} <- parse_fees(socket),
         {:ok, socket} <- upsert_offer(socket, priced, fees) do
      {:ok, socket.assigns.offer}
    else
      # `%{} = errors` also matches Ash error structs (they're maps too), so
      # this must be guarded to only catch our own plain validation-error maps
      # from parse_rows/parse_fees — otherwise a domain error (e.g. the
      # unique_product_offer identity violation) gets assigned to @errors
      # instead of flashed, and `@errors[:base]` crashes on the struct.
      {:error, errors} when is_map(errors) and not is_struct(errors) ->
        {:error_socket, assign(socket, errors: errors)}

      # upsert_offer/3 already created (or reused) the offer before its later
      # step failed — the 3rd element is the socket with that offer bound to
      # @offer, so a retry reuses it instead of calling create_draft again and
      # tripping the unique_product_offer identity.
      {:error, reason, socket} ->
        {:error_socket, put_flash(socket, :error, save_error_message(reason))}

      {:error, reason} ->
        {:error_socket, put_flash(socket, :error, save_error_message(reason))}
    end
  end

  defp publish_error_message(:source_product_not_sellable),
    do: "The source product must be active before publishing."

  defp publish_error_message(:offer_requires_variants),
    do: "Add at least one priced variant before publishing."

  defp publish_error_message(:offer_requires_available_variant),
    do: "The source product has no available stock to offer."

  defp publish_error_message(:invalid_offer_economics),
    do: "Fix the pricing first — every priced variant needs valid economics."

  defp publish_error_message(_), do: "The offer could not be published right now."

  defp save_error_message(:invalid_fixed_commission_terms),
    do: "Wholesale + commission must equal the customer price exactly."

  defp save_error_message(%Ash.Error.Invalid{} = error) do
    if duplicate_offer_error?(error) do
      "You already have an offer for this product — edit it from My Offers instead."
    else
      "The offer could not be saved right now."
    end
  end

  defp save_error_message(_), do: "The offer could not be saved right now."

  defp duplicate_offer_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn e -> Exception.message(e) =~ "already been taken" end)
  end

  # Rows with any input are parsed strictly; fully blank rows are skipped.
  defp parse_rows(socket) do
    model = socket.assigns.model

    {priced, errors} =
      Enum.reduce(socket.assigns.rows, {[], %{}}, fn {vid, row}, {acc, errs} ->
        if blank_row?(row) do
          {acc, errs}
        else
          case parse_row(model, vid, row) do
            {:ok, attrs} -> {[{vid, row[:terms_id], attrs} | acc], errs}
            {:error, field} -> {acc, Map.put(errs, {vid, field}, "must be a valid amount")}
          end
        end
      end)

    if errors == %{}, do: {:ok, priced}, else: {:error, errors}
  end

  defp blank_row?(row),
    do: Enum.all?(@price_fields, fn f -> String.trim(row[f] || "") == "" end)

  defp parse_row(model, _vid, row) do
    with {:ok, supplier} <- required_price(row["supplier"], "supplier"),
         {:ok, main} <- required_price(row["suggested"], "suggested"),
         {:ok, max} <- optional_price(row["max"], "max"),
         {:ok, commission} <- commission_for(model, row) do
      attrs =
        %{supplier_price: supplier, suggested_retail_price: main}
        |> maybe_put(:max_retail_price, max)
        |> maybe_put(:fixed_commission_amount, commission)

      {:ok, attrs}
    end
  end

  defp commission_for("markup", _row), do: {:ok, nil}

  defp commission_for("fixed_commission", row),
    do: required_price(row["commission"], "commission")

  defp required_price(value, field) do
    case Money.parse_price(value || "") do
      {:ok, pesewas} -> {:ok, pesewas}
      _ -> {:error, field}
    end
  end

  defp optional_price(value, field) do
    case Money.parse_price(value || "") do
      {:ok, pesewas} -> {:ok, pesewas}
      :skip -> {:ok, nil}
      _ -> {:error, field}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_fees(socket) do
    {fees, errors} =
      Enum.reduce(socket.assigns.fees, {%{}, %{}}, fn {region, value}, {acc, errs} ->
        case Money.parse_price(value || "") do
          {:ok, pesewas} -> {Map.put(acc, region, pesewas), errs}
          :zero -> {Map.put(acc, region, 0), errs}
          :skip -> {acc, errs}
          _ -> {acc, Map.put(errs, {:fee, region}, "must be a valid amount")}
        end
      end)

    if errors == %{}, do: {:ok, fees}, else: {:error, errors}
  end

  defp upsert_offer(socket, priced, fees) do
    actor = socket.assigns.current_merchant
    store = socket.assigns.current_store
    term_attrs = term_attrs(socket, fees)

    case ensure_offer(socket, actor, store, term_attrs) do
      {:ok, offer} ->
        # Bind the offer (with variants preloaded — @offer drives
        # source_variants/1 in this view) and the row state (successful
        # add_variant calls get their new terms_id recorded — see
        # save_rows/4) regardless of outcome: a retry after a partial
        # failure must find both via @offer/@rows rather than call
        # create_draft/add_variant again for rows already persisted, which
        # would trip the unique_product_offer/unique_offer_variant identities.
        case save_rows_and_terms(actor, offer, priced, socket.assigns.rows, term_attrs) do
          {:ok, offer, rows} ->
            {:ok, assign(socket, offer: with_variants(offer), rows: rows)}

          {:error, reason, offer, rows} ->
            {:error, reason, assign(socket, offer: with_variants(offer), rows: rows)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp save_rows_and_terms(actor, offer, priced, rows, term_attrs) do
    case save_rows(actor, offer, priced, rows) do
      {:ok, rows} ->
        case Offers.update_terms(actor, offer, term_attrs) do
          {:ok, offer} -> {:ok, offer, rows}
          {:error, reason} -> {:error, reason, offer, rows}
        end

      {:error, reason, rows} ->
        {:error, reason, offer, rows}
    end
  end

  defp with_variants(offer),
    do: Ash.load!(offer, [offer_variants: :source_variant], authorize?: false)

  defp term_attrs(socket, fees) do
    terms = socket.assigns.terms

    %{
      delivery_areas: MapSet.to_list(socket.assigns.areas),
      dispatch_fees: fees,
      return_terms: presence(terms["return_terms"]),
      returns_window_days: parse_int(terms["returns_window_days"]),
      warranty_months: parse_int(terms["warranty_months"]),
      warranty_terms: presence(terms["warranty_terms"])
    }
  end

  defp ensure_offer(%{assigns: %{offer: %{} = offer}}, _actor, _store, _terms), do: {:ok, offer}

  defp ensure_offer(socket, actor, store, term_attrs) do
    Offers.create_draft(
      actor,
      Map.merge(term_attrs, %{
        wholesaler_store_id: store.id,
        source_product_id: socket.assigns.product.id,
        earning_model: String.to_existing_atom(socket.assigns.model)
      })
    )
  end

  # Persists each row and returns `{:ok, rows}` | `{:error, reason, rows}`.
  # A row that persists this attempt via add_variant has its new terms_id
  # recorded in `rows` so a retry after a later row's failure goes through
  # update_variant instead of re-adding (and tripping unique_offer_variant).
  defp save_rows(actor, offer, priced, rows) do
    Enum.reduce_while(priced, {:ok, rows}, fn {vid, terms_id, attrs}, {:ok, rows} ->
      result =
        if terms_id do
          variant = Enum.find(offer.offer_variants, &(&1.id == terms_id))
          Offers.update_variant(actor, offer, variant, attrs)
        else
          Offers.add_variant(actor, offer, Map.put(attrs, :source_variant_id, vid))
        end

      case result do
        {:ok, terms} ->
          rows = if terms_id, do: rows, else: put_in(rows, [vid, :terms_id], terms.id)
          {:cont, {:ok, rows}}

        {:error, reason} ->
          {:halt, {:error, reason, rows}}
      end
    end)
  end

  defp presence(nil), do: nil
  defp presence(value), do: if(String.trim(value) == "", do: nil, else: value)

  defp parse_int(nil), do: nil

  defp parse_int(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp load_products(socket) do
    case socket.assigns[:current_store] do
      %{id: store_id} ->
        Emakola.Catalog.Product
        |> Ash.Query.for_read(:list_admin, %{store_id: store_id, search: nil, status: :active})
        |> Ash.Query.load(:variants)
        |> Ash.read!(authorize?: false)
        |> Enum.filter(&(&1.variants != []))

      _ ->
        []
    end
  end

  # ALL of the product's variants, priced or not — not just the ones with
  # persisted terms. Matching on `%{offer: %{}}` first used to hide any row
  # that hadn't (yet) persisted, so a partial-failure retry on :new lost the
  # failed rows' inputs, and :edit never offered unpriced product variants
  # for `add_variant`. Row pricing/terms_id still comes from `@rows`.
  defp source_variants(%{product: %{} = product}), do: product.variants
  defp source_variants(_assigns), do: []

  defp row_value(rows, vid, field), do: get_in(rows, [vid, field]) || ""
  defp row_terms_id(rows, vid), do: get_in(rows, [vid, :terms_id])

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 pb-16">
      <div :if={@loading} class="py-16 text-center text-sm text-slate-400">Loading…</div>

      <div :if={!@loading} class="space-y-6">
        <div class="pt-2">
          <.link
            navigate={~p"/admin/supply/offers"}
            class="text-sm text-slate-500 hover:text-slate-700"
          >
            ← My Offers
          </.link>
          <h1 class="text-2xl sm:text-3xl font-bold text-slate-900 mt-2">
            {if @action == :new, do: "New offer", else: "Edit offer"}
          </h1>
          <p :if={@errors[:base]} class="text-sm text-red-600 mt-1">{@errors[:base]}</p>
        </div>

        <%!-- Product picker (new only) --%>
        <div :if={@action == :new} class="rounded-2xl border border-slate-200 p-4">
          <label class="text-xs font-semibold uppercase tracking-wide text-slate-500">
            Product
          </label>
          <form phx-change="select_product">
            <select
              name="product_id"
              class="mt-2 w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
            >
              <option value="">Pick a product to offer…</option>
              <option :for={p <- @products} value={p.id} selected={@product && @product.id == p.id}>
                {p.title}
              </option>
            </select>
          </form>
          <p :if={@products == []} class="text-xs text-slate-500 mt-2">
            You need an active product with at least one variant before creating an offer.
          </p>
        </div>

        <%!-- Delivery areas + dispatch fees --%>
        <div class="rounded-2xl border border-slate-200 p-4">
          <p class="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-3">
            Delivery areas &amp; dispatch fees
          </p>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <div
              :for={region <- Emakola.Suppliers.GhanaRegions.all()}
              class="flex items-center gap-3"
            >
              <button
                phx-click="toggle_region"
                phx-value-region={region}
                class={[
                  "flex-1 text-left rounded-xl border px-3 py-2 text-sm",
                  if(MapSet.member?(@areas, region),
                    do: "border-emerald-600 bg-emerald-50 text-emerald-800",
                    else: "border-slate-200 text-slate-600"
                  )
                ]}
              >
                {region}
              </button>
              <form
                :if={MapSet.member?(@areas, region)}
                phx-change="set_region_fee"
                class="w-28"
              >
                <input type="hidden" name="region" value={region} />
                <input
                  type="text"
                  name="value"
                  value={@fees[region] || ""}
                  placeholder="Fee GH₵"
                  phx-debounce="300"
                  class="w-full rounded-xl border border-slate-300 px-2 py-1.5 text-sm"
                />
              </form>
              <p :if={@errors[{:fee, region}]} class="text-xs text-red-600">
                {@errors[{:fee, region}]}
              </p>
            </div>
          </div>
        </div>

        <div :if={@product} class="space-y-6">
          <%!-- Earning model --%>
          <div class="rounded-2xl border border-slate-200 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500 mb-2">
              Earning model
            </p>
            <div class="flex gap-4">
              <button
                :for={
                  {value, label} <- [{"markup", "Markup"}, {"fixed_commission", "Fixed commission"}]
                }
                phx-click="select_model"
                phx-value-model={value}
                disabled={@offer != nil}
                class={[
                  "rounded-xl border px-4 py-2 text-sm font-medium",
                  if(@model == value,
                    do: "border-emerald-600 bg-emerald-50 text-emerald-800",
                    else: "border-slate-300 text-slate-600"
                  ),
                  @offer != nil && "opacity-60"
                ]}
              >
                {label}
              </button>
            </div>
            <p class="text-xs text-slate-500 mt-2">
              <%= if @model == "markup" do %>
                Resellers keep the difference between their retail price and your wholesale price.
              <% else %>
                Wholesale + commission must equal the customer price exactly.
              <% end %>
            </p>
          </div>

          <%!-- Variant pricing --%>
          <div class="rounded-2xl border border-slate-200 overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-xs uppercase tracking-wide text-slate-500 bg-slate-50">
                  <th class="px-4 py-2.5">Variant</th>
                  <th class="px-4 py-2.5">Wholesale (GH₵)</th>
                  <%= if @model == "markup" do %>
                    <th class="px-4 py-2.5">Suggested retail</th>
                    <th class="px-4 py-2.5">Max retail (optional)</th>
                  <% else %>
                    <th class="px-4 py-2.5">Customer price</th>
                    <th class="px-4 py-2.5">Commission</th>
                  <% end %>
                  <th class="px-4 py-2.5"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr :for={variant <- source_variants(assigns)}>
                  <td class="px-4 py-3 text-slate-700">{variant.sku || "Default"}</td>
                  <td class="px-4 py-3">
                    <.price_input
                      variant_id={variant.id}
                      field="supplier"
                      value={row_value(@rows, variant.id, "supplier")}
                      error={@errors[{variant.id, "supplier"}]}
                      disabled={@locked?}
                    />
                  </td>
                  <%= if @model == "markup" do %>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="suggested"
                        value={row_value(@rows, variant.id, "suggested")}
                        error={@errors[{variant.id, "suggested"}]}
                        disabled={@locked?}
                      />
                    </td>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="max"
                        value={row_value(@rows, variant.id, "max")}
                        error={@errors[{variant.id, "max"}]}
                        disabled={@locked?}
                      />
                    </td>
                  <% else %>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="suggested"
                        value={row_value(@rows, variant.id, "suggested")}
                        error={@errors[{variant.id, "suggested"}]}
                        disabled={@locked?}
                      />
                    </td>
                    <td class="px-4 py-3">
                      <.price_input
                        variant_id={variant.id}
                        field="commission"
                        value={row_value(@rows, variant.id, "commission")}
                        error={@errors[{variant.id, "commission"}]}
                        disabled={@locked?}
                      />
                    </td>
                  <% end %>
                  <td class="px-4 py-3">
                    <button
                      :if={!@locked? && row_terms_id(@rows, variant.id)}
                      phx-click="remove_variant"
                      phx-value-terms-id={row_terms_id(@rows, variant.id)}
                      data-confirm="Remove this variant's pricing from the offer?"
                      class="text-xs font-medium text-red-600 hover:text-red-800"
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%!-- Terms --%>
          <div class="rounded-2xl border border-slate-200 p-4 space-y-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">
              Supplier terms
            </p>
            <form phx-change="set_term">
              <input type="hidden" name="field" value="return_terms" />
              <textarea
                name="value"
                rows="2"
                placeholder="Return terms you honour back to resellers…"
                phx-debounce="300"
                class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
              >{@terms["return_terms"]}</textarea>
            </form>
            <div class="grid grid-cols-2 gap-3">
              <form phx-change="set_term">
                <input type="hidden" name="field" value="returns_window_days" />
                <input
                  type="text"
                  name="value"
                  value={@terms["returns_window_days"]}
                  placeholder="Returns window (days)"
                  phx-debounce="300"
                  class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
              </form>
              <form phx-change="set_term">
                <input type="hidden" name="field" value="warranty_months" />
                <input
                  type="text"
                  name="value"
                  value={@terms["warranty_months"]}
                  placeholder="Warranty (months)"
                  phx-debounce="300"
                  class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
                />
              </form>
            </div>
            <form phx-change="set_term">
              <input type="hidden" name="field" value="warranty_terms" />
              <textarea
                name="value"
                rows="2"
                placeholder="Warranty terms…"
                phx-debounce="300"
                class="w-full rounded-xl border border-slate-300 px-3 py-2 text-sm"
              >{@terms["warranty_terms"]}</textarea>
            </form>
          </div>

          <%!-- Actions --%>
          <div class="flex items-center gap-3">
            <button
              phx-click="save_draft"
              class="rounded-xl bg-slate-800 hover:bg-slate-900 text-white text-sm font-semibold px-5 py-2.5"
            >
              {if @locked?, do: "Save terms", else: "Save draft"}
            </button>
            <button
              :if={!@locked?}
              phx-click="publish"
              class="rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-sm font-semibold px-5 py-2.5"
            >
              {if @offer && @offer.status == :paused, do: "Republish", else: "Publish"}
            </button>
            <p :if={@locked?} class="text-xs text-slate-500">
              Pricing is locked while the offer is live — pause it from
              <.link navigate={~p"/admin/supply/offers"} class="text-emerald-700">My Offers</.link>
              to edit prices. Terms, areas, and fees save normally.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :variant_id, :string, required: true
  attr :field, :string, required: true
  attr :value, :string, required: true
  attr :error, :string, default: nil
  attr :disabled, :boolean, default: false

  defp price_input(assigns) do
    ~H"""
    <form id={"variant-price-#{@variant_id}-#{@field}"} phx-change="set_variant_price">
      <input type="hidden" name="variant-id" value={@variant_id} />
      <input type="hidden" name="field" value={@field} />
      <input
        type="text"
        name="value"
        value={@value}
        disabled={@disabled}
        placeholder="0.00"
        phx-debounce="300"
        class={[
          "w-28 rounded-xl border px-2 py-1.5 text-sm",
          if(@error, do: "border-red-400", else: "border-slate-300"),
          @disabled && "bg-slate-50 text-slate-400"
        ]}
      />
      <p :if={@error} class="text-xs text-red-600 mt-1">{@error}</p>
    </form>
    """
  end
end
