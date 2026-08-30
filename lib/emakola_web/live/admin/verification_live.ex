defmodule EmakolaWeb.Admin.VerificationLive do
  @moduledoc """
  Merchant page to submit store business details and track their review status.

      /admin/verification

  Shows the current status (none → form, pending → under review, rejected →
  reason + resubmit form, approved → confirmation).

  **This page does not collect identity.** L.I. 2523 (in force 9 June 2026)
  makes requesting, retaining or visually inspecting a Ghana Card an offence,
  so the ID-type, ID-number and ID-document fields are gone. Identity comes
  from proving control of the payout wallet on `/admin/payouts`, which the
  telco has already KYC'd against a Ghana Card.

  What remains is a trading name plus an optional supporting business document
  (MMDA licence, tax receipt, certificate of incorporation) — lawful to collect,
  and what the BoG merchant-tier ladder actually asks for. It uploads with a
  PRIVATE ACL; on resubmit the replaced key is cleaned up via
  `StorageCleanupWorker`.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Stores

  # 10 MB per document — streamed through the LiveView socket (see DigitalFiles
  # moduledoc for why we cap socket uploads).
  @max_bytes 10 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      %{} = store ->
        {:ok,
         socket
         |> assign(:page_title, "Business details")
         |> assign(:active_nav, :verification)
         |> assign_verification(load_verification(store))
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
  def handle_event("validate", %{"verification" => params}, socket) do
    {:noreply, assign(socket, :verification_form, to_form(params, as: :verification))}
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :business_doc, ref)}
  end

  def handle_event("submit", %{"verification" => params}, socket) do
    store = socket.assigns.current_store

    if blank?(params["business_name"]) do
      {:noreply,
       socket
       |> assign(:verification_form, to_form(params, as: :verification))
       |> put_flash(:error, "Please enter your shop name.")}
    else
      submit_verification(socket, store, params)
    end
  end

  # ── Submission ──────────────────────────────────────────────────

  defp submit_verification(socket, store, params) do
    attrs = %{
      business_name: params["business_name"],
      business_doc_key: consume_doc(socket, store.id)
    }

    case persist(socket.assigns.verification, store, attrs) do
      {:ok, verification} ->
        {:noreply,
         socket
         |> assign(:verification, verification)
         |> put_flash(:info, "Sent for review.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send. Please try again.")}
    end
  end

  # Resubmit replaces a rejected submission (and cleans up its old business
  # document); otherwise create a fresh one. The retired `id_document_key` is
  # deliberately untouched here — vaulting and deleting those is the job of
  # `mix emakola.quarantine_id_documents`, which sweeps every row regardless
  # of status.
  defp persist(%{status: :rejected} = existing, _store, attrs) do
    cleanup_keys([existing.business_doc_key])
    Stores.resubmit_store_verification(existing, attrs, authorize?: false)
  end

  defp persist(_none, store, attrs) do
    Stores.submit_store_verification(Map.put(attrs, :store_id, store.id), authorize?: false)
  end

  defp consume_doc(socket, store_id) do
    socket
    |> consume_uploaded_entries(:business_doc, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      key = "verifications/#{store_id}/business-#{Ecto.UUID.generate()}#{ext}"

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
    <section class="max-w-[1600px] mx-auto px-4 sm:px-6 py-8 space-y-6">
      <.admin_page_header
        icon="hero-building-storefront"
        title="Business details"
        subtitle="Tell buyers who your shop is."
      />

      <%!-- The three beats, so a merchant can see where they are without
            reading the form first. --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <.verify_step
          icon="hero-building-storefront"
          title="Your shop name"
          hint="What buyers will see"
          state={if @status in [nil, :rejected], do: :current, else: :done}
        />
        <.verify_step
          icon="hero-document-arrow-up"
          title="Your paper"
          hint="Licence or receipt. Optional."
          state={if @status in [nil, :rejected], do: :todo, else: :done}
        />
        <.verify_step
          icon="hero-check-circle"
          title="We check it"
          hint="We reply by SMS"
          state={if @status == :approved, do: :done, else: :todo}
        />
      </div>

      <%!-- Identity now comes from the payout wallet, not from this page.
            Point merchants at the step that actually earns them trust. --%>
      <div class="rounded-lg border border-sky-200 bg-sky-50 p-5 text-sky-900">
        <p class="font-medium">Get paid to prove your shop is real</p>
        <p class="mt-1 text-sm">
          We send a code to your mobile money number. Nobody sends us an ID card.
        </p>
        <.link
          navigate={~p"/admin/payouts"}
          class="mt-3 inline-flex items-center gap-1.5 rounded-lg bg-sky-600 px-3 py-1.5 text-sm font-semibold text-white hover:bg-sky-700"
        >
          <.icon name="hero-device-phone-mobile" class="size-4" /> Set up mobile money
        </.link>
      </div>

      <div
        :if={@status == :approved}
        class="rounded-lg border border-emerald-200 bg-emerald-50 p-5 text-emerald-800"
      >
        <p class="font-medium">Your business details are approved ✓</p>
      </div>

      <div
        :if={@status == :pending}
        class="rounded-lg border border-amber-200 bg-amber-50 p-5 text-amber-800"
      >
        <p class="font-medium">We are checking your details</p>
        <p class="mt-1 text-sm">We'll notify you by SMS and email once it's been reviewed.</p>
      </div>

      <div
        :if={@status == :rejected}
        class="mb-6 rounded-lg border border-rose-200 bg-rose-50 p-5 text-rose-800"
      >
        <p class="font-medium">Your details were not approved</p>
        <p :if={@verification.review_reason} class="mt-1 text-sm">{@verification.review_reason}</p>
        <p class="mt-1 text-sm">Please correct the details below and send again.</p>
      </div>

      <.form
        :if={@status in [nil, :rejected]}
        for={@verification_form}
        id="verification-form"
        phx-submit="submit"
        phx-change="validate"
        class="space-y-5 rounded-lg border border-slate-200 bg-white p-6"
      >
        <div>
          <.input
            field={@verification_form[:business_name]}
            type="text"
            label="Your shop name"
            class="mt-1 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:border-emerald-400 focus:outline-none focus:ring-2 focus:ring-emerald-500/20"
          />
        </div>

        <.doc_upload
          label="Business paper (optional)"
          hint="Licence or tax receipt. Stored privately."
          upload={@uploads.business_doc}
        />

        <button
          type="submit"
          class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700"
        >
          {if @status == :rejected, do: "Send again", else: "Send for review"}
        </button>
      </.form>
    </section>
    """
  end

  defp assign_verification(socket, verification) do
    params = %{"business_name" => verification && verification.business_name}

    assign(socket,
      verification: verification,
      verification_form: to_form(params, as: :verification)
    )
  end

  attr :label, :string, required: true
  attr :hint, :string, required: true
  attr :upload, :any, required: true

  defp doc_upload(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-semibold text-slate-700 mb-2">{@label}</label>

      <%!-- A picture-first dropzone rather than a bare file input: these
            merchants are on phones, and `capture` opens the camera straight
            at the document. The input is a full-size opacity-0 overlay —
            an sr-only one will not open the picker on iOS Safari. --%>
      <div
        class="relative rounded-control border-2 border-dashed border-slate-300 bg-surface-subtle hover:border-primary transition-colors"
        phx-drop-target={@upload.ref}
      >
        <div
          :if={@upload.entries == []}
          class="flex flex-col items-center gap-2 px-4 py-8 text-center"
        >
          <div class="w-14 h-14 rounded-control bg-info-soft flex items-center justify-center">
            <.icon name="hero-camera" class="size-7 text-info" />
          </div>
          <p class="text-sm font-semibold text-slate-700">Take a photo or choose a file</p>
          <p class="text-xs text-slate-500">{@hint}</p>
        </div>

        <div :for={entry <- @upload.entries} class="flex items-center gap-4 p-4">
          <div class="w-16 h-16 rounded-control bg-primary-soft flex items-center justify-center shrink-0">
            <.icon name="hero-document-check" class="size-7 text-primary" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-semibold text-slate-900">{entry.client_name}</p>
            <p class="text-xs text-slate-500 mt-0.5">Only we can see it</p>
          </div>
          <button
            type="button"
            phx-click="cancel_upload"
            phx-value-ref={entry.ref}
            class="relative z-10 inline-flex items-center gap-1 rounded-control border border-border px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-50 cursor-pointer"
          >
            <.icon name="hero-x-mark" class="size-4" /> Remove
          </button>
        </div>

        <%!-- Always rendered: removing the input once an entry exists tears it
              out of the DOM mid-upload and the transfer dies. It just stops
              taking clicks while a file is attached. --%>
        <.live_file_input
          upload={@upload}
          capture="environment"
          class={[
            "absolute inset-0 h-full w-full opacity-0",
            if(@upload.entries == [], do: "cursor-pointer", else: "pointer-events-none")
          ]}
        />
      </div>

      <p :for={err <- upload_errors(@upload)} class="mt-1.5 text-sm text-rose-600">
        {upload_error_message(err)}
      </p>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :hint, :string, required: true
  attr :state, :atom, required: true, values: [:done, :current, :todo]

  defp verify_step(assigns) do
    ~H"""
    <div class="flex items-center gap-4 rounded-card border border-border bg-surface p-4 shadow-sm">
      <div class={[
        "w-12 h-12 rounded-control flex items-center justify-center shrink-0 text-white",
        step_tile(@state)
      ]}>
        <.icon name={if @state == :done, do: "hero-check", else: @icon} class="size-6" />
      </div>
      <div class="min-w-0">
        <p class={[
          "text-sm font-bold",
          if(@state == :todo, do: "text-slate-500", else: "text-slate-900")
        ]}>
          {@title}
        </p>
        <p class="text-xs text-slate-500 mt-0.5">{@hint}</p>
      </div>
    </div>
    """
  end

  defp step_tile(:done), do: "bg-success"
  defp step_tile(:current), do: "bg-primary"
  defp step_tile(:todo), do: "bg-slate-300"

  defp upload_error_message(:too_large), do: "File is larger than 10 MB."
  defp upload_error_message(:not_accepted), do: "Use a JPG, PNG, or PDF."
  defp upload_error_message(:too_many_files), do: "One file only."
  defp upload_error_message(_), do: "Upload error."
end
