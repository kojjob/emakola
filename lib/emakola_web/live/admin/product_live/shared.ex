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
  - `parse_price_input/1` / `format_pesewas/1` — GHS ↔ pesewas conversions at
    the presentation boundary.
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

  Returns the list of `{:ok, url}` values from `consume_uploaded_entries/3`.
  Call after a successful product save; a no-op when there are no pending entries.
  """
  def save_uploaded_images(socket, product) do
    store_id = socket.assigns.store_id

    Phoenix.LiveView.consume_uploaded_entries(socket, :product_images, fn %{path: tmp_path},
                                                                          entry ->
      ext = Path.extname(entry.client_name)
      filename = "#{Ecto.UUID.generate()}#{ext}"
      s3_path = "stores/#{store_id}/products/#{filename}"
      binary = File.read!(tmp_path)

      {:ok, url} =
        Emakola.Storage.upload(binary, s3_path, content_type: entry.client_type)

      Emakola.Catalog.create_image(
        %{
          url: url,
          product_id: product.id,
          store_id: store_id,
          content_type: entry.client_type,
          file_size_bytes: entry.client_size,
          alt_text: Path.rootname(entry.client_name)
        },
        authorize?: false
      )

      {:ok, url}
    end)
  end

  @doc """
  Parses a GHS decimal string into integer pesewas.

  Returns `{:ok, pesewas}` on success, `:skip` for blank input,
  `:error` for non-empty but unparseable input.

      iex> parse_price_input("25.00")
      {:ok, 2500}
      iex> parse_price_input("")
      :skip
      iex> parse_price_input("abc")
      :error
  """
  def parse_price_input(value) do
    case Regex.run(~r/^\s*(\d+)(?:\.(\d{1,2}))?\s*$/, value || "") do
      [_, major] ->
        {:ok, String.to_integer(major) * 100}

      [_, major, minor] ->
        {:ok,
         String.to_integer(major) * 100 + String.to_integer(String.pad_trailing(minor, 2, "0"))}

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

  # ── Private ────────────────────────────────────────────────────────────────

  defp upload_error_to_string(:too_large), do: "File is too large"

  defp upload_error_to_string(:not_accepted),
    do: "Only image files are accepted (.jpg, .png, .webp)"

  defp upload_error_to_string(:too_many_files), do: "Only one file at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"
end
