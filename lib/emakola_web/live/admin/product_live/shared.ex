defmodule EmakolaWeb.Admin.ProductLive.Shared do
  @moduledoc """
  Shared helpers for admin product pages — reused by the Index slide-over
  and the Form page.

  Responsibilities:
  - `upload_area/1` — function component for the product-image upload UI
    (existing-image grid + drag-drop zone + previews + errors). Emits
    `"delete_image"` and `"cancel_image_upload"` events; the parent LiveView
    keeps the handlers.
  - `save_uploaded_images/2` — consume pipeline: uploads → Tigris → Catalog.Image.
    Returns `{ok_count, failed_count}`; callers flash a warning when failed > 0.
  - `parse_price_input/1` / `format_pesewas/1` — GHS ↔ pesewas conversions at
    the presentation boundary.
  - `create_product_with_price/3` — canonical create sequence (Form + Index).
  - `update_product_with_price/4` — canonical update sequence for the Form page.
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents

  # ── Component ──────────────────────────────────────────────────────────────

  attr :uploads, :map,
    required: true,
    doc: "the @uploads assign (must contain :product_images)"

  attr :existing_images, :list,
    default: [],
    doc: "images already persisted to the product; pass [] on create"

  def upload_area(assigns) do
    ~H"""
    <div class="space-y-4 border-t border-slate-200 pt-5">
      <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wide">
        Images
      </h3>
      <p class="text-xs text-slate-400 -mt-2">
        Upload up to 5 images (JPG, PNG, WebP, max 10MB each)
      </p>

      <%!-- Existing images (edit mode) --%>
      <%= if @existing_images != [] do %>
        <div class="grid grid-cols-3 gap-2">
          <%= for img <- @existing_images do %>
            <div class="relative group rounded-lg overflow-hidden bg-slate-100 aspect-square">
              <img
                src={img.thumbnail_url || img.url}
                alt={img.alt_text || ""}
                class="w-full h-full object-cover"
              />
              <button
                type="button"
                phx-click="delete_image"
                phx-value-id={img.id}
                class="absolute top-1 right-1 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity text-xs"
              >
                <.icon name="hero-x-mark" class="size-3.5" />
              </button>
            </div>
          <% end %>
        </div>
      <% end %>

      <%!-- Upload area --%>
      <div
        class="border-2 border-dashed border-slate-300 rounded-lg p-4 text-center hover:border-emerald-400 transition-colors"
        phx-drop-target={@uploads.product_images.ref}
      >
        <.icon name="hero-cloud-arrow-up" class="size-8 mx-auto text-slate-400 mb-2" />
        <p class="text-sm text-slate-600 font-medium">
          Drag & drop images here
        </p>
        <p class="text-xs text-slate-400 mt-1">or</p>
        <label class="inline-block mt-2 px-3 py-1.5 text-xs font-semibold bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg cursor-pointer transition-colors">
          Browse files <.live_file_input upload={@uploads.product_images} class="sr-only" />
        </label>
      </div>

      <%!-- Upload previews --%>
      <%= if @uploads.product_images.entries != [] do %>
        <div class="grid grid-cols-3 gap-2">
          <%= for entry <- @uploads.product_images.entries do %>
            <div class="relative rounded-lg overflow-hidden bg-slate-100 aspect-square">
              <.live_img_preview entry={entry} class="w-full h-full object-cover" />
              <button
                type="button"
                phx-click="cancel_image_upload"
                phx-value-ref={entry.ref}
                class="absolute top-1 right-1 w-6 h-6 bg-red-500 text-white rounded-full flex items-center justify-center text-xs"
              >
                <.icon name="hero-x-mark" class="size-3.5" />
              </button>
              <%!-- Progress bar --%>
              <div class="absolute bottom-0 left-0 right-0 h-1 bg-slate-200">
                <div
                  class="h-full bg-primary transition-all"
                  style={"width: #{entry.progress}%"}
                >
                </div>
              </div>
              <%!-- Errors --%>
              <%= for err <- upload_errors(@uploads.product_images, entry) do %>
                <p class="absolute bottom-1 left-1 right-1 text-[9px] text-red-500 bg-white/90 px-1 rounded">
                  {upload_error_to_string(err)}
                </p>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  @doc """
  Consumes uploaded product-image entries: uploads each to Tigris storage and
  creates a `Catalog.Image` record linked to the product.

  Returns `{ok_count, failed_count}`. Errors from storage or image creation are
  caught per-entry so a single failure does not crash the LiveView or abort
  remaining uploads. Callers should flash a warning when `failed_count > 0`.

  Call after a successful product save; a no-op when there are no pending entries.
  """
  def save_uploaded_images(socket, product) do
    store_id = socket.assigns.store_id

    results =
      Phoenix.LiveView.consume_uploaded_entries(socket, :product_images, fn %{path: tmp_path},
                                                                            entry ->
        ext = Path.extname(entry.client_name)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        s3_path = "stores/#{store_id}/products/#{filename}"
        binary = File.read!(tmp_path)

        case Emakola.Storage.upload(binary, s3_path, content_type: entry.client_type) do
          {:ok, url} ->
            case Emakola.Catalog.create_image(
                   %{
                     url: url,
                     product_id: product.id,
                     store_id: store_id,
                     content_type: entry.client_type,
                     file_size_bytes: entry.client_size,
                     alt_text: Path.rootname(entry.client_name)
                   },
                   authorize?: false
                 ) do
              {:ok, _image} -> {:ok, :ok}
              {:error, _} -> {:ok, :error}
            end

          {:error, _reason} ->
            {:ok, :error}
        end
      end)

    failed_count = Enum.count(results, &(&1 == :error))
    ok_count = length(results) - failed_count
    {ok_count, failed_count}
  end

  @doc """
  Parses a GHS decimal string into integer pesewas.

  Returns `{:ok, pesewas}` on success (pesewas > 0), `:skip` for blank input,
  `:zero` for a parseable but zero amount (rejected as invalid),
  `:error` for non-empty but unparseable input.

      iex> parse_price_input("25.00")
      {:ok, 2500}
      iex> parse_price_input("")
      :skip
      iex> parse_price_input("0")
      :zero
      iex> parse_price_input("0.00")
      :zero
      iex> parse_price_input("abc")
      :error
  """
  def parse_price_input(value) do
    case Regex.run(~r/^\s*(\d+)(?:\.(\d{1,2}))?\s*$/, value || "") do
      [_, major] ->
        pesewas = String.to_integer(major) * 100
        if pesewas == 0, do: :zero, else: {:ok, pesewas}

      [_, major, minor] ->
        pesewas =
          String.to_integer(major) * 100 +
            String.to_integer(String.pad_trailing(minor, 2, "0"))

        if pesewas == 0, do: :zero, else: {:ok, pesewas}

      nil ->
        if String.trim(value || "") == "", do: :skip, else: :error
    end
  end

  @doc """
  Formats integer pesewas as a GHS decimal string for display in price inputs.

      iex> format_pesewas(15050)
      "150.50"
      iex> format_pesewas(100)
      "1.00"
  """
  def format_pesewas(pesewas) do
    "#{div(pesewas, 100)}.#{pesewas |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  @doc """
  Creates a product with an optional default variant, then attempts activation.

  This is the canonical create sequence shared by the Form page and the Index
  slide-over to ensure consistent result-atom handling and flash feedback.

  Returns:
  - `{:ok, product, :activated}` — product created, default variant set, activated
  - `{:ok, product, :activation_failed}` — created (+ variant when price given), but
    activation failed; product remains draft
  - `{:ok, product, :draft_requested}` — created (+ variant when price given), draft action
  - `{:error, error}` — product or variant creation failed
  """
  def create_product_with_price(attrs, pesewas, action) do
    with {:ok, product} <- Emakola.Catalog.create_product(attrs, authorize?: false),
         :ok <- maybe_create_default_variant(product, pesewas) do
      attempt_create_activation(product, action, pesewas)
    end
  end

  @doc """
  Updates a product with an optional default variant, then attempts activation.

  Strips `:store_id` from attrs (the `:update` action does not accept it — tenancy
  is fixed at creation). When `pesewas` is non-nil and the product currently has
  no variants, a default variant is created (edit-rescue path for products with no
  pricing yet). Activation is always attempted when `action == :active` (the product
  may already have variants from a previous save).

  Returns the same result atoms as `create_product_with_price/3`.
  """
  def update_product_with_price(product, attrs, pesewas, action) do
    clean_attrs = Map.delete(attrs, :store_id)

    with {:ok, updated} <- Emakola.Catalog.update_product(product, clean_attrs, authorize?: false),
         :ok <- maybe_create_default_variant(updated, pesewas) do
      attempt_update_activation(updated, action)
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp maybe_create_default_variant(_product, nil), do: :ok

  defp maybe_create_default_variant(product, pesewas) do
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
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  # For the create path: only attempt activation when a variant was just
  # created (pesewas non-nil). Without a variant, activation would fail —
  # skip the call and report :activation_failed directly.
  defp attempt_create_activation(product, :active, pesewas) when not is_nil(pesewas) do
    case Emakola.Catalog.activate_product(product, authorize?: false) do
      {:ok, activated} -> {:ok, activated, :activated}
      {:error, _} -> {:ok, product, :activation_failed}
    end
  end

  defp attempt_create_activation(product, :active, _nil_pesewas) do
    {:ok, product, :activation_failed}
  end

  defp attempt_create_activation(product, :draft, _pesewas) do
    {:ok, product, :draft_requested}
  end

  # For the update path: always call activate_product when action is :active
  # because the product may already have variants from a previous save.
  defp attempt_update_activation(product, :active) do
    case Emakola.Catalog.activate_product(product, authorize?: false) do
      {:ok, activated} -> {:ok, activated, :activated}
      {:error, _} -> {:ok, product, :activation_failed}
    end
  end

  defp attempt_update_activation(product, :draft) do
    {:ok, product, :draft_requested}
  end

  defp upload_error_to_string(:too_large), do: "File is too large"

  defp upload_error_to_string(:not_accepted),
    do: "Only image files are accepted (.jpg, .png, .webp)"

  defp upload_error_to_string(:too_many_files), do: "Up to 5 images at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
