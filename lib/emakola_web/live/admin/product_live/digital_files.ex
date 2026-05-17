defmodule EmakolaWeb.Admin.ProductLive.DigitalFiles do
  @moduledoc """
  Merchant admin page for managing a product's digital files.

      /admin/products/:id/files

  Used to upload purchaseable files (delivered via `DownloadGrant` when
  an order is paid) and preview files (publicly accessible samples).
  Per file the merchant can:

    * upload new files (private ACL, max 100 MB per file in v1)
    * mark/unmark as preview (toggles `is_preview`)
    * delete the row (storage object cleanup deferred to a reaper)

  ## Iron Law application

  Every `handle_event` re-verifies the file's `store_id` against the
  current merchant's store before mutating. Mount-time auth doesn't
  carry over — without per-event re-check, a crafted `phx-value-id`
  pointing at another store's file would mutate it. The check uses
  `Ash.get` with the file id; if the store_id doesn't match the
  merchant's session, we no-op with a flash.

  ## Why 100 MB cap in v1

  LiveView uploads stream through the WebSocket. 100 MB covers most
  practical digital products (PDFs, ebooks, audio bundles, smaller
  software). For multi-GB files (videos, large datasets) the next
  slice will add presigned PUT URLs so the browser uploads direct to
  S3, then POSTs the key back. Don't raise the cap further without
  switching to that pattern — large uploads through the WebSocket are
  fragile and tie up the LiveView process.
  """

  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Catalog.DigitalFile

  # 100 MB cap; see moduledoc for rationale.
  @max_bytes 100 * 1024 * 1024

  @impl true
  def mount(%{"id" => product_id}, _session, socket) do
    store_id = get_store_id(socket)

    case load_product(product_id, store_id) do
      {:ok, product} ->
        {:ok,
         socket
         |> assign(:store_id, store_id)
         |> assign(:product, product)
         |> assign(:page_title, "Digital files — #{product.title}")
         |> assign(:files, list_files(product.id, store_id))
         |> assign(:upload_error, nil)
         |> allow_upload(:digital_files,
           accept: :any,
           max_entries: 5,
           max_file_size: @max_bytes
         )}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Product not found")
         |> push_navigate(to: ~p"/admin/products")}
    end
  end

  # ── Events ─────────────────────────────────────────────────────

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save_files", _params, socket) do
    %{store_id: store_id, product: product} = socket.assigns

    saved =
      consume_uploaded_entries(socket, :digital_files, fn %{path: tmp_path}, entry ->
        create_digital_file(tmp_path, entry, store_id, product.id)
      end)

    flash =
      case Enum.count(saved) do
        0 -> {:info, "No files uploaded."}
        n -> {:info, "Uploaded #{n} #{pluralize("file", n)}."}
      end

    {:noreply,
     socket
     |> put_flash(elem(flash, 0), elem(flash, 1))
     |> assign(:files, list_files(product.id, store_id))}
  end

  @impl true
  def handle_event("delete_file", %{"id" => id}, socket) do
    with {:ok, file} <- get_owned_file(id, socket.assigns.store_id),
         :ok <- destroy_file(file) do
      {:noreply,
       socket
       |> put_flash(:info, "File deleted.")
       |> assign(:files, list_files(socket.assigns.product.id, socket.assigns.store_id))}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not delete file.")}
    end
  end

  @impl true
  def handle_event("toggle_preview", %{"id" => id}, socket) do
    with {:ok, file} <- get_owned_file(id, socket.assigns.store_id),
         {:ok, _} <- update_preview(file, !file.is_preview) do
      {:noreply,
       assign(socket, :files, list_files(socket.assigns.product.id, socket.assigns.store_id))}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Could not update file.")}
    end
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :digital_files, ref)}
  end

  # ── Render ─────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-4xl px-4 py-8 sm:px-6 lg:px-8">
      <header class="mb-6 flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold text-slate-900">Digital files</h1>
          <p class="mt-1 text-sm text-slate-500">
            {@product.title} — files delivered after purchase, plus public previews.
          </p>
        </div>
        <.link
          navigate={~p"/admin/products/#{@product.id}/edit"}
          class="text-sm text-slate-600 underline"
        >
          ← Back to product
        </.link>
      </header>

      <form
        id="digital-files-upload"
        phx-submit="save_files"
        phx-change="validate"
        class="mb-8 rounded-lg border border-slate-200 bg-white p-6"
      >
        <h2 class="mb-3 text-sm font-medium text-slate-900">Upload files</h2>
        <p class="mb-4 text-xs text-slate-500">
          Up to 5 files at once, 100 MB each. Files are stored privately and delivered via short-lived signed URLs.
        </p>

        <.live_file_input
          upload={@uploads.digital_files}
          class="block w-full text-sm text-slate-700 file:mr-4 file:rounded file:border-0 file:bg-amber-50 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-amber-700 hover:file:bg-amber-100"
        />

        <ul :if={@uploads.digital_files.entries != []} class="mt-4 space-y-2">
          <li
            :for={entry <- @uploads.digital_files.entries}
            class="flex items-center justify-between rounded border border-slate-200 px-3 py-2 text-sm"
          >
            <span class="truncate text-slate-700">{entry.client_name}</span>
            <span class="ml-3 text-xs text-slate-500">{format_size(entry.client_size)}</span>
            <button
              type="button"
              phx-click="cancel_upload"
              phx-value-ref={entry.ref}
              class="ml-3 text-xs text-rose-600 underline"
            >
              cancel
            </button>
          </li>
        </ul>

        <p :for={err <- upload_errors(@uploads.digital_files)} class="mt-2 text-sm text-rose-600">
          {error_message(err)}
        </p>

        <button
          type="submit"
          disabled={@uploads.digital_files.entries == []}
          class="mt-4 rounded-md bg-amber-600 px-4 py-2 text-sm font-medium text-white hover:bg-amber-700 disabled:bg-slate-200 disabled:text-slate-400"
        >
          Upload
        </button>
      </form>

      <h2 class="mb-3 text-sm font-medium text-slate-900">Files</h2>

      <%= if @files == [] do %>
        <div class="rounded-lg border border-dashed border-slate-300 bg-white p-8 text-center">
          <p class="text-slate-600">No files yet.</p>
          <p class="mt-1 text-xs text-slate-500">Upload above to attach files to this product.</p>
        </div>
      <% else %>
        <ul role="list" class="divide-y divide-slate-200 rounded-lg border border-slate-200 bg-white">
          <li :for={file <- @files} class="flex items-center justify-between gap-4 p-4">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-medium text-slate-900">{file.file_name}</p>
              <p class="mt-0.5 text-xs text-slate-500">
                {format_size(file.byte_size)} • {file.content_type}
              </p>
            </div>

            <div class="flex items-center gap-3">
              <span
                :if={file.is_preview}
                class="inline-flex items-center rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-medium text-amber-800"
              >
                Preview
              </span>
              <span
                :if={!file.is_preview}
                class="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700"
              >
                Paid
              </span>

              <button
                type="button"
                phx-click="toggle_preview"
                phx-value-id={file.id}
                class="text-xs text-slate-600 underline"
              >
                {if file.is_preview, do: "Make paid", else: "Make preview"}
              </button>

              <button
                type="button"
                phx-click="delete_file"
                phx-value-id={file.id}
                data-confirm="Delete this file? The storage object will be reaped later."
                class="text-xs text-rose-600 underline"
              >
                Delete
              </button>
            </div>
          </li>
        </ul>
      <% end %>
    </section>
    """
  end

  # ── Data loading ───────────────────────────────────────────────

  defp load_product(product_id, store_id) when is_binary(store_id) do
    case Ash.get(Emakola.Catalog.Product, product_id, authorize?: false) do
      {:ok, %{store_id: ^store_id} = product} -> {:ok, product}
      _ -> {:error, :not_found}
    end
  end

  defp load_product(_product_id, _), do: {:error, :not_found}

  defp list_files(product_id, store_id) do
    DigitalFile
    |> Ash.Query.filter(product_id == ^product_id and store_id == ^store_id)
    |> Ash.Query.sort(position: :asc, inserted_at: :asc)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  # Re-authorization: never mutate a file without first confirming it
  # belongs to the merchant's store. Mount-time auth doesn't carry over.
  defp get_owned_file(file_id, store_id) do
    case Ash.get(DigitalFile, file_id, authorize?: false) do
      {:ok, %{store_id: ^store_id} = file} -> {:ok, file}
      _ -> :error
    end
  end

  # ── Mutations ──────────────────────────────────────────────────

  defp create_digital_file(tmp_path, entry, store_id, product_id) do
    storage_key = build_storage_key(store_id, product_id, entry.client_name)
    binary = File.read!(tmp_path)

    case Emakola.Storage.upload(binary, storage_key,
           content_type: entry.client_type || "application/octet-stream",
           acl: "private"
         ) do
      {:ok, _url} ->
        DigitalFile
        |> Ash.Changeset.for_create(:create, %{
          store_id: store_id,
          product_id: product_id,
          file_name: entry.client_name,
          storage_key: storage_key,
          content_type: entry.client_type || "application/octet-stream",
          byte_size: entry.client_size
        })
        |> Ash.create(authorize?: false)
        |> case do
          {:ok, file} -> {:ok, file}
          {:error, reason} -> {:postpone, reason}
        end

      {:error, reason} ->
        {:postpone, reason}
    end
  end

  defp destroy_file(file) do
    case file
         |> Ash.Changeset.for_destroy(:destroy)
         |> Ash.destroy(authorize?: false) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  defp update_preview(file, new_value) do
    file
    |> Ash.Changeset.for_update(:update, %{is_preview: new_value})
    |> Ash.update(authorize?: false)
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp build_storage_key(store_id, product_id, client_name) do
    ext = Path.extname(client_name)
    "stores/#{store_id}/products/#{product_id}/files/#{Ecto.UUID.generate()}#{ext}"
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp format_size(bytes) when bytes >= 1_073_741_824,
    do: "#{Float.round(bytes / 1_073_741_824, 2)} GB"

  defp format_size(bytes) when bytes >= 1_048_576,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_size(bytes) when bytes >= 1_024, do: "#{Float.round(bytes / 1_024, 1)} KB"
  defp format_size(bytes), do: "#{bytes} B"

  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  defp error_message(:too_large), do: "File is larger than 100 MB."
  defp error_message(:too_many_files), do: "Too many files (max 5)."
  defp error_message(:not_accepted), do: "File type not accepted."
  defp error_message(other), do: "Upload error: #{inspect(other)}"
end
