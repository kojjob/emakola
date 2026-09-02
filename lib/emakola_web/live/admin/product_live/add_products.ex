defmodule EmakolaWeb.Admin.ProductLive.AddProducts do
  @moduledoc """
  `/admin/products/new` — photo cards.

  One photo or thirty: every photo becomes a card that needs exactly two
  things, what it is and how much. One button puts the finished cards in the
  shop; the rest stay on the page. Built for merchants who do not read well,
  so the page's state is carried by badges and counts rather than sentences
  (design/add-products, chosen 2026-09-02).

  Two upload configs back the two tiles: `:camera` opens the phone's camera
  through `capture="environment"`, `:photos` opens the gallery. Cards are
  keyed `"camera-0"` / `"photos-0"` because entry refs are only unique within
  one config. Both auto-upload so the publish button can gate on progress
  without deadlocking.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Admin.ProductLive.AddProductsComponents

  alias EmakolaWeb.Admin.ProductLive.Shared

  @max_photos 30
  @upload_names [:camera, :photos]

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    {:ok,
     socket
     |> assign(
       page_title: "Add products",
       active_nav: :products,
       store_id: store.id,
       currency: store.currency || "GHS",
       shop_url: EmakolaWeb.SEO.Canonical.store_url(store),
       max_photos: @max_photos,
       cards: %{},
       # The most recent valid price typed: offered to unpriced cards as a
       # chip, because a stall that prices everything alike should not type
       # the number thirty times.
       last_price: nil,
       # Keys of photos already attached to a product. The upload channel
       # drops a consumed entry from @uploads asynchronously, so the render
       # right after publishing would otherwise still show its card.
       consumed: MapSet.new(),
       card_form: to_form(%{}),
       publishing: false,
       published: []
     )
     |> allow_upload(:camera, upload_opts())
     |> allow_upload(:photos, upload_opts())}
  end

  defp upload_opts do
    [
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: @max_photos,
      max_file_size: 10_000_000,
      auto_upload: true
    ]
  end

  @impl true
  def render(assigns) do
    items = photo_items(assigns.uploads, assigns.cards, assigns.consumed)
    ready = Enum.count(items, &(&1.state == :ready))

    assigns =
      assign(assigns,
        items: items,
        stage: stage(assigns.published, items),
        ready: ready,
        remaining: length(items) - ready,
        uploading?: Enum.any?(items, &(&1.entry.progress < 100))
      )

    ~H"""
    <div class="max-w-[1600px] mx-auto">
      <.add_products_header :if={@stage != :done} stage={@stage} photo_count={length(@items)} />

      <.form for={@card_form} id="add-products-form" phx-change="validate" phx-submit="publish_all">
        <div :if={@stage != :done} class="mt-5">
          <.capture_tiles uploads={@uploads} compact={@stage == :cards} max_photos={@max_photos} />
          <.upload_problems uploads={@uploads} />
          <.entry_links :if={@stage == :capture} layout={:stack} />
        </div>

        <div :if={@stage == :cards} class="grid grid-cols-1 lg:grid-cols-3 gap-4 mt-5">
          <.photo_card
            :for={{item, number} <- Enum.with_index(@items, 1)}
            item={item}
            number={number}
            currency={@currency}
            last_price={@last_price}
          />
        </div>

        <.publish_bar
          :if={@stage == :cards}
          ready={@ready}
          remaining={@remaining}
          publishing={@publishing}
          uploading?={@uploading?}
        />
      </.form>

      <.done_screen
        :if={@stage == :done}
        published={@published}
        currency={@currency}
        shop_url={@shop_url}
      />
    </div>
    """
  end

  # ── Events ──

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("set_card", %{"upload" => upload, "ref" => ref} = params, socket) do
    case card_key(upload, ref) do
      {:ok, _name, key} ->
        field = Emakola.SafeAtom.to_atom_in(params["field"], [:name, :price], :name)
        value = params["value"] || ""

        cards =
          Map.update(socket.assigns.cards, key, %{field => value}, &Map.put(&1, field, value))

        {:noreply, socket |> assign(:cards, cards) |> remember_price(field, value)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_photo", %{"upload" => upload, "ref" => ref}, socket) do
    case card_key(upload, ref) do
      {:ok, name, key} ->
        {:noreply,
         socket
         |> cancel_upload(name, ref)
         |> update(:cards, &Map.delete(&1, key))}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("copy_price", %{"upload" => upload, "ref" => ref, "price" => price}, socket) do
    with {:ok, _name, key} <- card_key(upload, ref),
         {:ok, _pesewas} <- Shared.parse_price_input(price) do
      cards = Map.update(socket.assigns.cards, key, %{price: price}, &Map.put(&1, :price, price))
      {:noreply, assign(socket, :cards, cards)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("add_more", _params, socket) do
    {:noreply, assign(socket, :published, [])}
  end

  def handle_event("publish_all", _params, socket) do
    items = photo_items(socket.assigns.uploads, socket.assigns.cards, socket.assigns.consumed)

    cond do
      socket.assigns.publishing ->
        {:noreply, socket}

      Enum.any?(items, &(&1.entry.progress < 100)) ->
        {:noreply, put_flash(socket, :error, "Please wait for all photos to finish uploading.")}

      true ->
        publish_ready(socket, items)
    end
  end

  # ── Publishing ──

  # Authorization: store_id comes from the RequireAuth-mounted current_store,
  # never from anything the client sends.
  defp publish_ready(socket, items) do
    socket = assign(socket, :publishing, true)
    store_id = socket.assigns.store_id

    created =
      items
      |> Enum.filter(&(&1.state == :ready))
      |> Enum.flat_map(&create_product(&1, store_id))

    products_by_key = Map.new(created, fn {item, product} -> {item.key, product} end)
    attach_photos(socket, products_by_key, store_id)
    Emakola.Catalog.CachedCatalog.invalidate_store(store_id)

    remaining = Enum.reject(items, &Map.has_key?(products_by_key, &1.key))

    socket =
      socket
      |> assign(:publishing, false)
      |> update(:cards, &Map.drop(&1, Map.keys(products_by_key)))
      |> update(:consumed, &MapSet.union(&1, MapSet.new(Map.keys(products_by_key))))

    cond do
      created == [] ->
        {:noreply, put_flash(socket, :error, "Add a name and price to at least one product.")}

      remaining == [] ->
        {:noreply, assign(socket, :published, published_summary(created, store_id))}

      true ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "#{length(created)} published. #{still_need(length(remaining))}"
         )}
    end
  end

  defp create_product(item, store_id) do
    {:ok, pesewas} = Shared.parse_price_input(item.price)
    attrs = %{title: String.trim(item.name), store_id: store_id}

    case Shared.create_product_with_price(attrs, pesewas, :active) do
      {:ok, product, _result} -> [{item, product}]
      {:error, _error} -> []
    end
  end

  # Attach each published card's photo to its product; a card that was not
  # published keeps its photo on the page (postponed, not consumed).
  defp attach_photos(socket, products_by_key, store_id) do
    for name <- @upload_names do
      consume_uploaded_entries(socket, name, fn %{path: tmp_path}, entry ->
        case Map.get(products_by_key, "#{name}-#{entry.ref}") do
          nil ->
            {:postpone, :skipped}

          product ->
            Shared.store_product_image(store_id, product.id, tmp_path, entry)
            {:ok, :attached}
        end
      end)
    end
  end

  # What the done screen shows: the product as a buyer will see it.
  defp published_summary(created, store_id) do
    for {item, product} <- created do
      {:ok, pesewas} = Shared.parse_price_input(item.price)
      %{title: product.title, price: pesewas, image_url: first_image_url(product, store_id)}
    end
  end

  defp first_image_url(product, store_id) do
    opts = [tenant: store_id, authorize?: false, load: [:images]]

    case Emakola.Catalog.get_product_for_store(product.id, store_id, opts) do
      {:ok, %{images: [image | _]}} -> image.thumbnail_url || image.url
      _ -> nil
    end
  end

  defp still_need(1), do: "1 still needs a name and price."
  defp still_need(count), do: "#{count} still need a name and price."

  defp remember_price(socket, :price, value) do
    case Shared.parse_price_input(value) do
      {:ok, _pesewas} -> assign(socket, :last_price, String.trim(value))
      _not_a_price -> socket
    end
  end

  defp remember_price(socket, _field, _value), do: socket

  # ── Cards ──

  # One item per uploaded photo, across both inputs, with the card's state
  # worked out here so the template only renders it.
  defp photo_items(uploads, cards, consumed) do
    for name <- @upload_names,
        entry <- uploads[name].entries,
        key = "#{name}-#{entry.ref}",
        not MapSet.member?(consumed, key) do
      card = Map.get(cards, key)

      %{
        key: key,
        upload: name,
        ref: entry.ref,
        entry: entry,
        name: card_field(card, :name),
        price: card_field(card, :price),
        state: card_state(card),
        missing_name?: card != nil and card_name(card) == "",
        missing_price?: card != nil and not priced?(card),
        problems: Enum.map(upload_errors(uploads[name], entry), &upload_problem/1)
      }
    end
  end

  defp card_key(upload, ref) do
    case Emakola.SafeAtom.to_atom_in(upload, @upload_names, nil) do
      nil -> :error
      name -> {:ok, name, "#{name}-#{ref}"}
    end
  end

  defp card_field(nil, _field), do: ""
  defp card_field(card, field), do: Map.get(card, field, "")

  defp card_name(card), do: card |> card_field(:name) |> String.trim()

  defp priced?(card), do: match?({:ok, _}, Shared.parse_price_input(card_field(card, :price)))

  defp card_state(nil), do: :untouched

  defp card_state(card) do
    if card_name(card) != "" and priced?(card), do: :ready, else: :incomplete
  end

  defp stage([_ | _] = _published, [] = _items), do: :done
  defp stage(_published, [] = _items), do: :capture
  defp stage(_published, _items), do: :cards
end
