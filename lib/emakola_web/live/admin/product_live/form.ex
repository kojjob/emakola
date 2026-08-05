defmodule EmakolaWeb.Admin.ProductLive.Form do
  @moduledoc """
  Create and edit product form with inline validation.
  Supports "Save as Draft" and "Save & Activate" actions.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias EmakolaWeb.Admin.ProductLive.Shared

  @upload_opts [
    accept: ~w(.jpg .jpeg .png .webp),
    max_entries: 5,
    max_file_size: 10_000_000
  ]

  @impl true
  def mount(params, _session, socket) do
    store_id = get_store_id(socket)

    case socket.assigns.live_action do
      :edit ->
        product = load_product(params["id"], socket)

        if is_nil(product) || product.store_id != store_id do
          {:ok,
           socket
           |> put_flash(:error, "Product not found.")
           |> redirect(to: ~p"/admin/products")}
        else
          categories = load_store_categories(store_id)

          socket =
            socket
            |> assign(
              page_title: "Edit Product",
              active_nav: :products,
              product: product,
              form_data: product_to_form_data(product),
              form: to_form(product_to_form_data(product), as: :product),
              errors: %{},
              categories: categories,
              store_id: store_id,
              is_edit: true,
              show_price_field: product.variants == [],
              existing_images: product.images
            )
            |> allow_upload(:product_images, @upload_opts)

          {:ok, socket}
        end

      :new ->
        categories = load_store_categories(store_id)

        socket =
          socket
          |> assign(
            page_title: "New Product",
            active_nav: :products,
            product: nil,
            form_data: empty_form_data(),
            form: to_form(empty_form_data(), as: :product),
            errors: %{},
            categories: categories,
            store_id: store_id,
            is_edit: false,
            show_price_field: true,
            existing_images: []
          )
          |> allow_upload(:product_images, @upload_opts)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"product" => params}, socket) do
    errors = validate_form(params)

    {:noreply,
     assign(socket,
       form_data: params,
       form: to_form(params, as: :product),
       errors: errors
     )}
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
      <.form
        for={@form}
        id="product-form"
        phx-change="validate"
        phx-submit="save_product"
        class="space-y-6"
      >
        <%!-- Basic Info --%>
        <div class="bg-white rounded-lg p-5 space-y-4">
          <h2 class="text-base font-semibold">Basic Information</h2>

          <div>
            <label for="product_title" class="block text-sm font-medium mb-1.5">
              Title <span class="text-red-500">*</span>
            </label>
            <.input
              field={@form[:title]}
              type="text"
              id="product_title"
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
            <.input
              field={@form[:description]}
              type="textarea"
              id="product_description"
              rows="4"
              placeholder="Describe your product..."
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>

          <div>
            <label for="product_category_id" class="block text-sm font-medium mb-1.5">
              Category
            </label>
            <.input
              field={@form[:category_id]}
              type="select"
              id="product_category_id"
              prompt="No category"
              options={Enum.map(@categories, &{&1.name, &1.id})}
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>

          <div>
            <label for="product_product_type" class="block text-sm font-medium mb-1.5">
              Product type
            </label>
            <select
              id="product_product_type"
              name="product[product_type]"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            >
              <option
                :for={type <- Shared.allowed_product_types(@current_store)}
                value={to_string(type)}
                selected={@form_data["product_type"] == to_string(type)}
              >
                {product_type_label(type)}
              </option>
            </select>
            <p
              :if={Shared.allowed_product_types(@current_store) == [:physical]}
              class="text-xs text-slate-400 mt-1.5"
            >
              Selling files instead? Turn on digital downloads in <.link
                navigate={~p"/admin/settings"}
                class="underline"
              >settings</.link>.
            </p>
            <p
              :if={@is_edit && @form_data["product_type"] == "digital_download"}
              class="text-xs text-slate-500 mt-1.5"
            >
              <.link
                navigate={~p"/admin/products/#{@product.id}/files"}
                class="text-primary font-medium underline"
              >
                Digital files
              </.link>
              — upload what the buyer downloads.
            </p>
          </div>

          <div>
            <label for="product_tags" class="block text-sm font-medium mb-1.5">
              Tags
            </label>
            <.input
              field={@form[:tags]}
              type="text"
              id="product_tags"
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
            <.input
              field={@form[:price]}
              type="text"
              id="product_price"
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
            <.input
              field={@form[:seo_title]}
              type="text"
              id="product_seo_title"
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
            <.input
              field={@form[:seo_description]}
              type="textarea"
              id="product_seo_description"
              rows="2"
              maxlength="160"
              placeholder="Brief description for search results"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-200
                     bg-white focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
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
            name={@form[:_action].name}
            value="draft"
            class="flex-1 px-4 py-2.5 rounded-lg text-sm font-semibold border-2 border-emerald-600
                   text-emerald-700 hover:bg-emerald-50 active:scale-95 transition-all"
          >
            Save as Draft
          </button>
          <button
            type="submit"
            name={@form[:_action].name}
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
      </.form>
    </div>
    """
  end

  # ── Private ──

  defp save_product(socket, params, action) do
    {price_str, product_params} = Map.pop(params, "price")
    price_result = Shared.parse_price_input(price_str)
    errors = validate_form(product_params) |> apply_price_error(price_result)

    if map_size(errors) > 0 do
      {:noreply,
       assign(socket,
         form_data: params,
         form: to_form(params, as: :product),
         errors: errors
       )}
    else
      # Resolved from assigns at handle-event time, never from a value carried
      # in the form. The allowlist is UX; ProductTypeAcceptedByStore on the
      # resource is the security boundary.
      attrs =
        product_params
        |> build_attrs(socket.assigns.store_id)
        |> Shared.put_product_type(product_params, socket.assigns[:current_store])

      pesewas = pesewas_from_price_result(price_result)

      result =
        if socket.assigns.is_edit do
          Shared.update_product_with_price(socket.assigns.product, attrs, pesewas, action)
        else
          Shared.create_product_with_price(attrs, pesewas, action)
        end

      case result do
        {:ok, product, result_atom} ->
          {_ok, upload_failed} = Shared.save_uploaded_images(socket, product)
          Emakola.Catalog.CachedCatalog.invalidate_store(socket.assigns.store_id)

          socket =
            socket
            |> put_flash(:info, save_success_msg(result_atom))
            |> maybe_flash_upload_failure(upload_failed)

          {:noreply, push_navigate(socket, to: ~p"/admin/products")}

        {:error, error} ->
          {:noreply,
           socket
           |> assign(form_data: params, form: to_form(params, as: :product))
           |> put_flash(:error, format_error(error))}
      end
    end
  end

  defp apply_price_error(errors, :error),
    do: Map.put(errors, :price, "must be a valid amount, e.g. 25.00")

  defp apply_price_error(errors, :zero),
    do: Map.put(errors, :price, "must be greater than 0.00")

  defp apply_price_error(errors, _), do: errors

  defp pesewas_from_price_result({:ok, p}), do: p
  defp pesewas_from_price_result(_), do: nil

  defp save_success_msg(:activated), do: "Product published — it's live on your store."
  defp save_success_msg(:activation_failed), do: "Saved as draft — add a price to publish it."
  defp save_success_msg(:draft_requested), do: "Product saved successfully"

  defp maybe_flash_upload_failure(socket, 0), do: socket

  defp maybe_flash_upload_failure(socket, _failed) do
    put_flash(
      socket,
      :error,
      "Some images failed to upload — you can add them by editing the product."
    )
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

  defp load_product(id, socket) do
    store_id = get_store_id(socket)

    opts = [
      actor: socket.assigns[:current_merchant],
      tenant: store_id,
      load: [:variants, :images]
    ]

    case Emakola.Catalog.get_product_for_store(id, store_id, opts) do
      {:ok, product} -> product
      _ -> nil
    end
  end

  defp load_store_categories(store_id) do
    try do
      Emakola.Catalog.list_categories_by_store!(store_id)
    rescue
      exception ->
        Logger.error(
          "[product_live.form] load_store_categories loading store categories raised: #{Exception.message(exception)}"
        )

        []
    end
  end

  defp product_to_form_data(product) do
    %{
      "title" => product.title || "",
      "description" => product.description || "",
      "category_id" => if(product.category_id, do: to_string(product.category_id), else: ""),
      "tags" => Enum.join(product.tags || [], ", "),
      "seo_title" => product.seo_title || "",
      "seo_description" => product.seo_description || "",
      "product_type" => to_string(product.product_type),
      "price" => ""
    }
  end

  defp empty_form_data do
    %{
      "title" => "",
      "description" => "",
      "category_id" => "",
      "tags" => "",
      "seo_title" => "",
      "seo_description" => "",
      "price" => ""
    }
  end

  defp product_type_label(:physical), do: "Physical — you ship it"
  defp product_type_label(:digital_download), do: "Digital download — buyer downloads a file"
  defp product_type_label(type), do: type |> to_string() |> String.replace("_", " ")

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
      _other -> "Something went wrong. Please try again."
    end)
    |> Enum.join(", ")
  end

  defp format_error(_error), do: "Something went wrong. Please try again."
end
