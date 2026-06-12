defmodule EmakolaWeb.Admin.ProductLive.Form do
  @moduledoc """
  Create and edit product form with inline validation.
  Supports "Save as Draft" and "Save & Activate" actions.
  """
  use EmakolaWeb, :live_view

  alias EmakolaWeb.Admin.ProductLive.Shared

  @impl true
  def mount(params, _session, socket) do
    store_id = get_store_id(socket)
    categories = load_store_categories(store_id)

    socket =
      case socket.assigns.live_action do
        :edit ->
          product = load_product(params["id"])

          socket
          |> assign(
            page_title: "Edit Product",
            product: product,
            form_data: product_to_form_data(product),
            errors: %{},
            categories: categories,
            store_id: store_id,
            is_edit: true,
            show_price_field: product != nil && product.variants == [],
            existing_images: if(product, do: product.images, else: [])
          )

        :new ->
          socket
          |> assign(
            page_title: "New Product",
            product: nil,
            form_data: %{
              "title" => "",
              "description" => "",
              "category_id" => "",
              "tags" => "",
              "seo_title" => "",
              "seo_description" => "",
              "price" => ""
            },
            errors: %{},
            categories: categories,
            store_id: store_id,
            is_edit: false,
            show_price_field: true,
            existing_images: []
          )
      end

    socket =
      allow_upload(socket, :product_images,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 5,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    errors = validate_form(params)
    {:noreply, assign(socket, form_data: params, errors: errors)}
  end

  @impl true
  def handle_event("save_product", %{"product" => params}, socket) do
    action = if params["_action"] == "activate", do: :active, else: :draft
    save_product(socket, Map.delete(params, "_action"), action)
  end

  @impl true
  def handle_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :product_images, ref)}
  end

  @impl true
  def handle_event("delete_image", %{"id" => image_id}, socket) do
    store_id = socket.assigns.store_id

    case Emakola.Catalog.get_image(image_id) do
      {:ok, image} when image.store_id == store_id ->
        Emakola.Catalog.destroy_image!(image, authorize?: false)

        updated_images =
          if product = socket.assigns.product do
            Ash.load!(product, [:images], authorize?: false).images
          else
            []
          end

        {:noreply, assign(socket, existing_images: updated_images)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto space-y-6">
      <%!-- Header --%>
      <div class="flex items-center gap-4">
        <.link
          navigate={~p"/admin/products"}
          class="p-2 rounded-lg hover:bg-slate-100 transition-colors"
          aria-label="Back to products"
        >
          <.icon name="hero-arrow-left" class="size-5 text-slate-500" />
        </.link>
        <div>
          <h1 class="text-2xl font-bold font-headline tracking-tight">
            {if @is_edit, do: "Edit Product", else: "New Product"}
          </h1>
          <p class="text-sm text-slate-500 mt-0.5">
            {if @is_edit, do: "Update product details", else: "Add a new product to your catalog"}
          </p>
        </div>
      </div>

      <%!-- Form --%>
      <form id="product-form" phx-change="validate" phx-submit="save_product" class="space-y-6">
        <%!-- Basic Info --%>
        <div class="bg-white rounded-lg p-5 space-y-4">
          <h2 class="text-base font-semibold">Basic Information</h2>

          <div>
            <label for="product_title" class="block text-sm font-medium mb-1.5">
              Title <span class="text-red-500">*</span>
            </label>
            <input
              type="text"
              id="product_title"
              name="product[title]"
              value={@form_data["title"]}
              placeholder="e.g., Ankara Print Fabric"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
                if(@errors[:title],
                  do: "border-red-300 bg-red-50",
                  else: "border-slate-200 bg-white"
                )
              ]}
            />
            <p :if={@errors[:title]} class="mt-1 text-xs text-red-600">{@errors[:title]}</p>
          </div>

          <div>
            <label for="product_description" class="block text-sm font-medium mb-1.5">
              Description
            </label>
            <textarea
              id="product_description"
              name="product[description]"
              rows="4"
              placeholder="Describe your product..."
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >{@form_data["description"]}</textarea>
          </div>

          <div>
            <label for="product_category_id" class="block text-sm font-medium mb-1.5">
              Category
            </label>
            <select
              id="product_category_id"
              name="product[category_id]"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >
              <option value="">No category</option>
              <option
                :for={cat <- @categories}
                value={cat.id}
                selected={@form_data["category_id"] == to_string(cat.id)}
              >
                {cat.name}
              </option>
            </select>
          </div>

          <div>
            <label for="product_tags" class="block text-sm font-medium mb-1.5">
              Tags
            </label>
            <input
              type="text"
              id="product_tags"
              name="product[tags]"
              value={@form_data["tags"]}
              placeholder="e.g., ankara, fabric, fashion (comma-separated)"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
            <p class="mt-1 text-xs text-slate-500">Separate tags with commas</p>
          </div>

          <%!-- Price field: always on :new; on :edit only when no variants yet --%>
          <div :if={@show_price_field}>
            <label for="product_price" class="block text-sm font-medium mb-1.5">
              Price (GHS)
            </label>
            <input
              type="text"
              id="product_price"
              name="product[price]"
              value={@form_data["price"]}
              placeholder="e.g. 25.00"
              class={[
                "w-full px-3 py-2.5 text-sm rounded-lg border focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500",
                if(@errors[:price],
                  do: "border-red-300 bg-red-50",
                  else: "border-slate-200 bg-white"
                )
              ]}
            />
            <p :if={@errors[:price]} class="mt-1 text-xs text-red-600">{@errors[:price]}</p>
            <p :if={!@errors[:price]} class="mt-1 text-xs text-slate-500">
              Required to publish. You can add more pricing options later.
            </p>
          </div>
        </div>

        <%!-- SEO --%>
        <div class="bg-white rounded-lg p-5 space-y-4">
          <h2 class="text-base font-semibold">SEO</h2>
          <p class="text-xs text-slate-500 -mt-2">
            Optimize how your product appears in search results
          </p>

          <div>
            <label for="product_seo_title" class="block text-sm font-medium mb-1.5">
              SEO Title
            </label>
            <input
              type="text"
              id="product_seo_title"
              name="product[seo_title]"
              value={@form_data["seo_title"]}
              placeholder="Custom title for search engines"
              maxlength="70"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
            <p class="mt-1 text-xs text-slate-500">
              {String.length(@form_data["seo_title"] || "")}/70 characters
            </p>
          </div>

          <div>
            <label for="product_seo_description" class="block text-sm font-medium mb-1.5">
              SEO Description
            </label>
            <textarea
              id="product_seo_description"
              name="product[seo_description]"
              rows="2"
              maxlength="160"
              placeholder="Brief description for search results"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >{@form_data["seo_description"]}</textarea>
            <p class="mt-1 text-xs text-slate-500">
              {String.length(@form_data["seo_description"] || "")}/160 characters
            </p>
          </div>
        </div>

        <%!-- Images --%>
        <div class="bg-white rounded-lg p-5">
          <Shared.upload_area uploads={@uploads} existing_images={@existing_images} />
        </div>

        <%!-- Actions --%>
        <div class="flex flex-col sm:flex-row gap-3 pt-2">
          <button
            type="submit"
            name="product[_action]"
            value="draft"
            class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 border-emerald-600
                   text-emerald-700 hover:bg-emerald-50 active:scale-95 transition-all"
          >
            Save as Draft
          </button>
          <button
            type="submit"
            name="product[_action]"
            value="activate"
            class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold bg-emerald-600 text-white
                   hover:bg-emerald-700 active:scale-95 transition-all shadow-sm"
            title={
              if @is_edit,
                do: "Save and activate this product",
                else: "Save and activate (requires variants)"
            }
          >
            Save &amp; Activate
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ── Private ──

  defp save_product(socket, params, action) do
    {price_str, product_params} = Map.pop(params, "price")
    price_result = Shared.parse_price_input(price_str)

    base_errors = validate_form(product_params)

    errors =
      if price_result == :error do
        Map.put(base_errors, :price, "must be a valid amount, e.g. 25.00")
      else
        base_errors
      end

    if map_size(errors) > 0 do
      {:noreply, assign(socket, form_data: params, errors: errors)}
    else
      pesewas =
        case price_result do
          {:ok, p} -> p
          :skip -> nil
        end

      attrs = build_attrs(product_params, socket.assigns.store_id)

      result =
        if socket.assigns.is_edit do
          update_and_maybe_variant(socket.assigns.product, attrs, action, pesewas)
        else
          create_and_maybe_variant(attrs, action, pesewas)
        end

      case result do
        {:ok, product, :activated} ->
          Shared.save_uploaded_images(socket, product)
          Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

          {:noreply,
           socket
           |> put_flash(:info, "Product published — it's live on your store.")
           |> push_navigate(to: ~p"/admin/products")}

        {:ok, product, :activation_failed} ->
          Shared.save_uploaded_images(socket, product)
          Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

          {:noreply,
           socket
           |> put_flash(:info, "Saved as draft — add a price to publish it.")
           |> push_navigate(to: ~p"/admin/products")}

        {:ok, product, :draft_requested} ->
          Shared.save_uploaded_images(socket, product)
          Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

          {:noreply,
           socket
           |> put_flash(:info, "Product saved successfully")
           |> push_navigate(to: ~p"/admin/products")}

        {:error, error} ->
          {:noreply,
           socket
           |> assign(form_data: params)
           |> put_flash(:error, format_error(error))}
      end
    end
  end

  defp create_and_maybe_variant(attrs, action, pesewas) do
    with {:ok, product} <- Emakola.Catalog.create_product(attrs, authorize?: false),
         :ok <- maybe_create_variant(product, pesewas) do
      attempt_activation(product, action, pesewas)
    end
  end

  defp update_and_maybe_variant(product, attrs, action, pesewas) do
    with {:ok, updated} <- Emakola.Catalog.update_product(product, attrs, authorize?: false),
         :ok <- maybe_create_variant(updated, pesewas) do
      attempt_activation(updated, action, pesewas)
    end
  end

  defp maybe_create_variant(_product, nil), do: :ok

  defp maybe_create_variant(product, pesewas) do
    sku = "SKU-" <> String.slice(Ecto.UUID.generate(), 0, 8)

    case Emakola.Catalog.create_variant(
           %{
             product_id: product.id,
             store_id: product.store_id,
             price: pesewas,
             sku: sku,
             position: 0
           },
           authorize?: false
         ) do
      {:ok, _variant} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  defp attempt_activation(product, :active, pesewas) when not is_nil(pesewas) do
    case Emakola.Catalog.activate_product(product, authorize?: false) do
      {:ok, activated} -> {:ok, activated, :activated}
      {:error, _} -> {:ok, product, :activation_failed}
    end
  end

  defp attempt_activation(product, :active, _nil_pesewas) do
    {:ok, product, :activation_failed}
  end

  defp attempt_activation(product, :draft, _pesewas) do
    {:ok, product, :draft_requested}
  end

  defp build_attrs(params, store_id) do
    tags =
      (params["tags"] || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    category_id =
      case params["category_id"] do
        "" -> nil
        nil -> nil
        id -> id
      end

    %{
      title: params["title"] || "",
      description: params["description"],
      category_id: category_id,
      tags: tags,
      seo_title: params["seo_title"],
      seo_description: params["seo_description"],
      store_id: store_id
    }
  end

  defp validate_form(params) do
    errors = %{}

    errors =
      if String.trim(params["title"] || "") == "" do
        Map.put(errors, :title, "Title is required")
      else
        errors
      end

    errors
  end

  defp load_product(id) do
    case Emakola.Catalog.get_product(id) do
      {:ok, product} -> Ash.load!(product, [:variants, :images], authorize?: false)
      _ -> nil
    end
  end

  defp load_store_categories(store_id) do
    try do
      Emakola.Catalog.list_categories_by_store!(store_id)
    rescue
      _ -> []
    end
  end

  defp product_to_form_data(nil), do: %{}

  defp product_to_form_data(product) do
    %{
      "title" => product.title || "",
      "description" => product.description || "",
      "category_id" => if(product.category_id, do: to_string(product.category_id), else: ""),
      "tags" => Enum.join(product.tags || [], ", "),
      "seo_title" => product.seo_title || "",
      "seo_description" => product.seo_description || "",
      "price" => ""
    }
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{message: msg} -> msg
      other -> inspect(other)
    end)
    |> Enum.join(", ")
  end

  defp format_error(error), do: inspect(error)
end
