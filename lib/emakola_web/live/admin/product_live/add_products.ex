defmodule EmakolaWeb.Admin.ProductLive.AddProducts do
  @moduledoc """
  `/admin/products/new` — the one door.

  One photo or thirty, or no photo at all: every product is a card that
  needs exactly two things, what it is and how much. One button puts the
  finished cards in the shop; the rest stay on the page. Built for merchants
  who do not read well, so the page's state is carried by badges and counts
  rather than sentences (design/add-products-one-door, 2026-09-04).

  Two upload configs back the one tile: `:camera` opens the phone's camera
  through `capture="environment"`, `:photos` (the Gallery pill) opens the
  library. Cards are keyed `"camera-0"` / `"photos-0"` because entry refs
  are only unique within one config; a typed card is `"typed-1"`. Both
  uploads auto-upload so the publish button can gate on progress without
  deadlocking.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Admin.ProductLive.AddProductsComponents

  alias EmakolaWeb.Admin.ProductLive.Shared

  @max_photos 30
  @upload_names [:camera, :photos]
  @sources @upload_names ++ [:typed]
  @card_fields [:name, :price, :category_id, :description]

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
       categories: Shared.load_store_categories(store.id),
       ai_enabled: EmakolaWeb.AiGate.enabled?(),
       cards: %{},
       # Keys of the cards whose More row is open.
       open: MapSet.new(),
       # The most recent valid price typed: offered to unpriced cards as a
       # chip, because a stall that prices everything alike should not type
       # the number thirty times.
       last_price: nil,
       # Keys of photos already attached to a product. The upload channel
       # drops a consumed entry from @uploads asynchronously, so the render
       # right after publishing would otherwise still show its card.
       consumed: MapSet.new(),
       # Typed cards, in the order they were added, and the counter that
       # names them; unlike a photo they have no upload entry behind them.
       typed: [],
       typed_seq: 0,
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
    items = card_items(assigns)
    ready = Enum.count(items, &(&1.state == :ready))

    assigns =
      assign(assigns,
        items: items,
        stage: stage(assigns.published, items),
        ready: ready,
        remaining: length(items) - ready,
        uploading?: Enum.any?(items, &(&1.entry && &1.entry.progress < 100))
      )

    ~H"""
    <div class="max-w-[1600px] mx-auto">
      <.add_products_header :if={@stage != :done} stage={@stage} item_count={length(@items)} />

      <.form for={@card_form} id="add-products-form" phx-change="validate" phx-submit="publish_all">
        <div :if={@stage != :done} class="mt-5">
          <.capture_tiles uploads={@uploads} compact={@stage == :cards} max_photos={@max_photos} />
          <.upload_problems uploads={@uploads} />
        </div>

        <div :if={@stage == :cards} class="grid grid-cols-1 lg:grid-cols-3 gap-4 mt-5">
          <.photo_card
            :for={{item, number} <- Enum.with_index(@items, 1)}
            item={item}
            number={number}
            currency={@currency}
            last_price={@last_price}
            categories={@categories}
            ai_enabled={@ai_enabled}
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
        field = Emakola.SafeAtom.to_atom_in(params["field"], @card_fields, :name)
        value = card_value(field, params["value"] || "", socket.assigns.categories)

        cards =
          Map.update(socket.assigns.cards, key, %{field => value}, &Map.put(&1, field, value))

        {:noreply, socket |> assign(:cards, cards) |> remember_price(field, value)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_more", %{"upload" => upload, "ref" => ref}, socket) do
    case card_key(upload, ref) do
      {:ok, _name, key} ->
        open = socket.assigns.open

        open =
          if MapSet.member?(open, key), do: MapSet.delete(open, key), else: MapSet.put(open, key)

        {:noreply, assign(socket, :open, open)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("add_typed_card", _params, socket) do
    seq = socket.assigns.typed_seq + 1

    {:noreply,
     socket
     |> assign(:typed_seq, seq)
     |> update(:typed, &(&1 ++ ["typed-#{seq}"]))}
  end

  def handle_event("remove_photo", %{"upload" => upload, "ref" => ref}, socket) do
    case card_key(upload, ref) do
      {:ok, :typed, key} ->
        {:noreply,
         socket
         |> update(:typed, &List.delete(&1, key))
         |> update(:cards, &Map.delete(&1, key))}

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
    items = card_items(socket.assigns)

    cond do
      socket.assigns.publishing ->
        {:noreply, socket}

      Enum.any?(items, &(&1.entry && &1.entry.progress < 100)) ->
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

    published_keys = Map.keys(products_by_key)

    socket =
      socket
      |> assign(:publishing, false)
      |> update(:cards, &Map.drop(&1, published_keys))
      |> update(:typed, &(&1 -- published_keys))
      |> update(:consumed, &MapSet.union(&1, MapSet.new(published_keys)))

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

    attrs = %{
      title: String.trim(item.name),
      store_id: store_id,
      description: blank_to_nil(item.description),
      category_id: blank_to_nil(item.category_id)
    }

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

  # A category id is only ever one of this store's own; anything else reads
  # as "no category", so a crafted event cannot file a product under another
  # store's category.
  defp card_value(:category_id, value, categories) do
    if Enum.any?(categories, &(&1.id == value)), do: value, else: ""
  end

  defp card_value(_field, value, _categories), do: value

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  # ── Cards ──

  # One item per card: every uploaded photo across both inputs, then every
  # typed card, with the card's state worked out here so the template only
  # renders it.
  defp card_items(%{uploads: uploads, consumed: consumed, typed: typed} = assigns) do
    photo_items =
      for name <- @upload_names,
          entry <- uploads[name].entries,
          key = "#{name}-#{entry.ref}",
          not MapSet.member?(consumed, key) do
        card_item(key, name, entry.ref, entry, assigns, %{
          problems: Enum.map(upload_errors(uploads[name], entry), &upload_problem/1)
        })
      end

    typed_items =
      for key <- typed do
        "typed-" <> ref = key
        card_item(key, :typed, ref, nil, assigns, %{problems: []})
      end

    photo_items ++ typed_items
  end

  defp card_item(key, source, ref, entry, %{cards: cards, open: open} = assigns, extra) do
    card = Map.get(cards, key)
    category_id = card_field(card, :category_id)

    Map.merge(
      %{
        key: key,
        upload: source,
        ref: ref,
        entry: entry,
        name: card_field(card, :name),
        price: card_field(card, :price),
        description: card_field(card, :description),
        category_id: category_id,
        category_name: category_name(assigns.categories, category_id),
        open?: MapSet.member?(open, key),
        state: card_state(card),
        missing_name?: card != nil and card_name(card) == "",
        missing_price?: card != nil and not priced?(card)
      },
      extra
    )
  end

  defp category_name(_categories, ""), do: nil

  defp category_name(categories, id) do
    case Enum.find(categories, &(&1.id == id)) do
      nil -> nil
      category -> category.name
    end
  end

  defp card_key(upload, ref) do
    case Emakola.SafeAtom.to_atom_in(upload, @sources, nil) do
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
