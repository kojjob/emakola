defmodule EmakolaWeb.Admin.VerificationLive do
  @moduledoc """
  Merchant page to submit store KYC and track its review status.

      /admin/verification

  Shows the current status (none → form, pending → under review, rejected →
  reason + resubmit form, approved → confirmation). Documents upload with a
  PRIVATE ACL (`Emakola.Storage.upload(..., acl: "private")`); reviewers view
  them via short-lived presigned URLs. On resubmit, the replaced document keys
  are cleaned up via `StorageCleanupWorker`.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Stores

  @id_types [:ghana_card, :passport, :drivers_license, :voter_id]
  # 10 MB per document — streamed through the LiveView socket (see DigitalFiles
  # moduledoc for why we cap socket uploads).
  @max_bytes 10 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      %{} = store ->
        {:ok,
         socket
         |> assign(:page_title, "Verification")
         |> assign(:active_nav, :verification)
         |> assign(:verification, load_verification(store))
         |> allow_upload(:id_document,
           accept: ~w(.jpg .jpeg .png .pdf),
           max_entries: 1,
           max_file_size: @max_bytes
         )
         |> allow_upload(:business_doc,
           accept: ~w(.jpg .jpeg .png .pdf),
           max_entries: 1,
           max_file_size: @max_bytes
         )}

      _ ->
        {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref, "slot" => slot}, socket) do
    slot_atom = Emakola.SafeAtom.to_atom_in(slot, [:id_document, :business_doc], :id_document)
    {:noreply, cancel_upload(socket, slot_atom, ref)}
  end

  def handle_event("submit", %{"verification" => params}, socket) do
    store = socket.assigns.current_store

    cond do
      blank?(params["business_name"]) or blank?(params["id_number"]) or blank?(params["id_type"]) ->
        {:noreply, put_flash(socket, :error, "Please fill in every field.")}

      socket.assigns.uploads.id_document.entries == [] ->
        {:noreply, put_flash(socket, :error, "Please attach a photo or PDF of your ID.")}

      true ->
        submit_verification(socket, store, params)
    end
  end

  # ── Submission ──────────────────────────────────────────────────

  defp submit_verification(socket, store, params) do
    id_key = consume_doc(socket, :id_document, store.id, "id")
    business_doc_key = consume_doc(socket, :business_doc, store.id, "business")

    if is_nil(id_key) do
      {:noreply, put_flash(socket, :error, "Upload failed. Please try again.")}
    else
      attrs = %{
        business_name: params["business_name"],
        id_type: Emakola.SafeAtom.to_atom_in(params["id_type"], @id_types, :ghana_card),
        id_number: params["id_number"],
        id_document_key: id_key,
        business_doc_key: business_doc_key
      }

      case persist(socket.assigns.verification, store, attrs) do
        {:ok, verification} ->
          {:noreply,
           socket
           |> assign(:verification, verification)
           |> put_flash(:info, "Verification submitted for review.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not submit. Please try again.")}
      end
    end
  end

  # Resubmit replaces a rejected submission (and cleans up its old documents);
  # otherwise create a fresh one.
  defp persist(%{status: :rejected} = existing, _store, attrs) do
    cleanup_keys([existing.id_document_key, existing.business_doc_key])
    Stores.resubmit_store_verification(existing, attrs, authorize?: false)
  end

  defp persist(_none, store, attrs) do
    Stores.submit_store_verification(Map.put(attrs, :store_id, store.id), authorize?: false)
  end

  defp consume_doc(socket, slot, store_id, prefix) do
    socket
    |> consume_uploaded_entries(slot, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      key = "verifications/#{store_id}/#{prefix}-#{Ecto.UUID.generate()}#{ext}"

      case Emakola.Storage.upload(File.read!(path), key,
             content_type: entry.client_type || "application/octet-stream",
             acl: "private"
           ) do
        {:ok, _url} -> {:ok, key}
        {:error, reason} -> {:postpone, reason}
      end
    end)
    |> List.first()
  end

  defp cleanup_keys(keys) do
    case Enum.reject(keys, &is_nil/1) do
      [] -> :ok
      keys -> %{"keys" => keys} |> Emakola.Workers.StorageCleanupWorker.new() |> Oban.insert()
    end
  end

  defp load_verification(store) do
    case Stores.get_store_verification(store.id, authorize?: false) do
      {:ok, verification} -> verification
      _ -> nil
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_), do: true

  # ── Render ──────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :status, assigns.verification && assigns.verification.status)

    ~H"""
    <section class="mx-auto max-w-2xl px-4 py-8 sm:px-6 lg:px-8">
      <header class="mb-6">
        <h1 class="text-2xl font-semibold text-slate-900">Store verification</h1>
        <p class="mt-1 text-sm text-slate-500">
          Verify your business to earn the verified badge on your storefront.
        </p>
      </header>

      <div
        :if={@status == :approved}
        class="rounded-lg border border-emerald-200 bg-emerald-50 p-5 text-emerald-800"
      >
        <p class="font-medium">Your store is verified ✓</p>
        <p class="mt-1 text-sm">The verified badge now shows on your storefront.</p>
      </div>

      <div
        :if={@status == :pending}
        class="rounded-lg border border-amber-200 bg-amber-50 p-5 text-amber-800"
      >
        <p class="font-medium">Your submission is under review</p>
        <p class="mt-1 text-sm">We'll notify you by SMS and email once it's been reviewed.</p>
      </div>

      <div
        :if={@status == :rejected}
        class="mb-6 rounded-lg border border-rose-200 bg-rose-50 p-5 text-rose-800"
      >
        <p class="font-medium">Your submission was not approved</p>
        <p :if={@verification.review_reason} class="mt-1 text-sm">{@verification.review_reason}</p>
        <p class="mt-1 text-sm">Please correct the details below and resubmit.</p>
      </div>

      <form
        :if={@status in [nil, :rejected]}
        id="verification-form"
        phx-submit="submit"
        phx-change="validate"
        class="space-y-5 rounded-lg border border-slate-200 bg-white p-6"
      >
        <div>
          <label class="block text-sm font-medium text-slate-700">Registered business name</label>
          <input
            type="text"
            name="verification[business_name]"
            value={@verification && @verification.business_name}
            class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
          />
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <label class="block text-sm font-medium text-slate-700">ID type</label>
            <select
              name="verification[id_type]"
              class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
            >
              <option value="ghana_card" selected={id_type_value(@verification) == :ghana_card}>
                Ghana Card
              </option>
              <option value="passport" selected={id_type_value(@verification) == :passport}>
                Passport
              </option>
              <option
                value="drivers_license"
                selected={id_type_value(@verification) == :drivers_license}
              >
                Driver's License
              </option>
              <option value="voter_id" selected={id_type_value(@verification) == :voter_id}>
                Voter ID
              </option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700">ID number</label>
            <input
              type="text"
              name="verification[id_number]"
              value={@verification && @verification.id_number}
              class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
            />
          </div>
        </div>

        <.doc_upload
          label="ID document (photo or PDF)"
          hint="Required. Stored privately."
          upload={@uploads.id_document}
          slot="id_document"
        />
        <.doc_upload
          label="Business registration (optional)"
          hint="Optional. Stored privately."
          upload={@uploads.business_doc}
          slot="business_doc"
        />

        <button
          type="submit"
          class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          {if @status == :rejected, do: "Resubmit for review", else: "Submit for review"}
        </button>
      </form>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :hint, :string, required: true
  attr :upload, :any, required: true
  attr :slot, :string, required: true

  defp doc_upload(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-slate-700">{@label}</label>
      <p class="text-xs text-slate-500">{@hint}</p>
      <.live_file_input
        upload={@upload}
        class="mt-1 block w-full text-sm text-slate-700 file:mr-4 file:rounded file:border-0 file:bg-slate-100 file:px-3 file:py-1.5 file:text-sm file:font-medium file:text-slate-700 hover:file:bg-slate-200"
      />
      <div :for={entry <- @upload.entries} class="mt-2 flex items-center gap-3 text-sm">
        <span class="truncate text-slate-700">{entry.client_name}</span>
        <button
          type="button"
          phx-click="cancel_upload"
          phx-value-ref={entry.ref}
          phx-value-slot={@slot}
          class="text-xs text-rose-600 underline"
        >
          remove
        </button>
      </div>
      <p :for={err <- upload_errors(@upload)} class="mt-1 text-sm text-rose-600">
        {upload_error_message(err)}
      </p>
    </div>
    """
  end

  defp id_type_value(nil), do: :ghana_card
  defp id_type_value(%{id_type: type}), do: type

  defp upload_error_message(:too_large), do: "File is larger than 10 MB."
  defp upload_error_message(:not_accepted), do: "Use a JPG, PNG, or PDF."
  defp upload_error_message(:too_many_files), do: "One file only."
  defp upload_error_message(_), do: "Upload error."
end
