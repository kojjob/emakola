defmodule EmakolaWeb.Admin.ProductLive.BulkUploadModal do
  @moduledoc """
  Slide-over modal for bulk-uploading products via CSV.

  Stateless function component — the parent LiveView
  (`EmakolaWeb.Admin.ProductLive.Index`) owns the upload state
  (`:uploads.csv_file`, `:csv_preview`, `:csv_errors`, `:bulk_importing`)
  and dispatches the events (`validate_csv`, `parse_csv`, `cancel_upload`,
  `import_products`, `cancel_bulk_upload`).

  CSV parsing/import logic lives in `Emakola.Catalog.CsvImporter`
  (extracted in commit 8f5c42e).
  """

  use Phoenix.Component

  import EmakolaWeb.CoreComponents
  alias Phoenix.LiveView.JS

  attr :uploads, :map, required: true, doc: "the live uploads struct (must contain :csv_file)"
  attr :csv_preview, :list, default: [], doc: "rows parsed and ready to import"
  attr :csv_errors, :list, default: [], doc: "user-readable error strings"
  attr :bulk_importing, :boolean, default: false, doc: "true while import is running"

  def bulk_upload_modal(assigns) do
    ~H"""
    <.modal
      id="bulk-upload-modal"
      title="Bulk Upload Products"
      kind={:slide_over}
      on_cancel={JS.push("cancel_bulk_upload")}
    >
      <div class="space-y-5">
        <%!-- CSV Template Download --%>
        <div class="bg-slate-50 rounded-lg p-4 space-y-2">
          <h3 class="text-sm font-semibold text-slate-700">CSV Template</h3>
          <p class="text-xs text-slate-500">
            Download the template, fill in your products, then upload below.
          </p>
          <a
            href={"data:text/csv;charset=utf-8,#{URI.encode(Emakola.Catalog.CsvImporter.template_header() <> "\n")}"}
            download="emakola_products_template.csv"
            class="inline-flex items-center gap-2 text-sm font-medium text-emerald-600
                   hover:text-emerald-700 transition-colors"
          >
            <.icon name="hero-arrow-down-tray" class="size-4" /> Download Template (.csv)
          </a>
          <p class="text-xs text-slate-400 font-mono mt-1">
            {Emakola.Catalog.CsvImporter.template_header()}
          </p>
        </div>

        <%!-- File Upload Area --%>
        <form phx-change="validate_csv" phx-submit="parse_csv" id="csv-upload-form">
          <div class="space-y-3">
            <label class="block text-sm font-medium text-slate-700">Upload CSV File</label>
            <div
              class="border-2 border-dashed border-slate-300 rounded-lg p-6 text-center
                     hover:border-emerald-400 transition-colors"
              phx-drop-target={@uploads.csv_file.ref}
            >
              <.icon name="hero-cloud-arrow-up" class="size-8 mx-auto text-slate-400 mb-2" />
              <p class="text-sm text-slate-600">
                Drag and drop your CSV file here, or click below to browse
              </p>
              <.live_file_input upload={@uploads.csv_file} class="mt-2" />
            </div>

            <%!-- Selected file --%>
            <div
              :for={entry <- @uploads.csv_file.entries}
              class="flex items-center justify-between bg-white border border-slate-200 rounded-lg p-3"
            >
              <div class="flex items-center gap-2">
                <.icon name="hero-document-text" class="size-5 text-slate-500" />
                <div>
                  <p class="text-sm font-medium text-slate-700">{entry.client_name}</p>
                  <p class="text-xs text-slate-500">{format_bytes(entry.client_size)}</p>
                </div>
              </div>
              <button
                type="button"
                phx-click="cancel_upload"
                phx-value-ref={entry.ref}
                class="text-slate-400 hover:text-red-600 transition-colors"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>

            <%!-- Upload errors --%>
            <div :for={err <- upload_errors(@uploads.csv_file)} class="text-xs text-red-600">
              {upload_error_to_string(err)}
            </div>

            <button
              type="submit"
              disabled={@uploads.csv_file.entries == []}
              class="w-full px-4 py-2 bg-slate-900 text-white text-sm font-medium rounded-lg
                     hover:bg-slate-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Parse CSV
            </button>
          </div>
        </form>

        <%!-- CSV Errors --%>
        <div :if={@csv_errors != []} class="bg-red-50 border border-red-200 rounded-lg p-3">
          <h3 class="text-sm font-semibold text-red-700 mb-2">Issues Found</h3>
          <ul class="space-y-1">
            <li :for={error <- @csv_errors} class="text-xs text-red-600 list-disc list-inside">
              {error}
            </li>
          </ul>
        </div>

        <%!-- CSV Preview Table --%>
        <div :if={@csv_preview != []} class="space-y-2">
          <h3 class="text-sm font-semibold text-slate-700">
            Preview ({length(@csv_preview)} products)
          </h3>
          <div class="overflow-x-auto bg-white border border-slate-200 rounded-lg">
            <table class="min-w-full text-xs">
              <thead class="bg-slate-50 border-b border-slate-200">
                <tr>
                  <th class="px-3 py-2 text-left font-semibold text-slate-700">Title</th>
                  <th class="px-3 py-2 text-left font-semibold text-slate-700">Category</th>
                  <th class="px-3 py-2 text-left font-semibold text-slate-700">SKU</th>
                  <th class="px-3 py-2 text-right font-semibold text-slate-700">Price</th>
                  <th class="px-3 py-2 text-right font-semibold text-slate-700">Stock</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-200">
                <tr :for={row <- @csv_preview}>
                  <td class="px-3 py-2 text-slate-900 font-medium">{row["title"]}</td>
                  <td class="px-3 py-2 text-slate-600">{row["category"] || "-"}</td>
                  <td class="px-3 py-2 text-slate-600 font-mono">{row["sku"] || "-"}</td>
                  <td class="px-3 py-2 text-right text-slate-600">{row["price"] || "-"}</td>
                  <td class="px-3 py-2 text-right text-slate-600">{row["stock_quantity"] || "-"}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <:footer>
        <div class="flex justify-end gap-3">
          <button
            type="button"
            phx-click="cancel_bulk_upload"
            class="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-200
                   rounded-lg hover:bg-slate-50 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            phx-click="import_products"
            disabled={@csv_preview == [] or @bulk_importing}
            class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700
                   disabled:opacity-50 disabled:cursor-not-allowed rounded-lg transition-colors"
          >
            <%= if @bulk_importing do %>
              Importing...
            <% else %>
              Import {length(@csv_preview)} Products
            <% end %>
          </button>
        </div>
      </:footer>
    </.modal>
    """
  end

  defp upload_error_to_string(:too_large), do: "File is too large"
  defp upload_error_to_string(:not_accepted), do: "Only .csv files are accepted"
  defp upload_error_to_string(:too_many_files), do: "Only one file at a time"
  defp upload_error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp format_bytes(bytes) when is_integer(bytes) and bytes < 1024, do: "#{bytes} B"

  defp format_bytes(bytes) when is_integer(bytes) and bytes < 1_048_576,
    do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when is_integer(bytes),
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(_), do: "?"
end
