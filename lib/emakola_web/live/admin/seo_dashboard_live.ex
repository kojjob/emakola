defmodule EmakolaWeb.Admin.SEODashboardLive do
  @moduledoc """
  SEO quick-wins dashboard (Phase 3c).

  Surfaces content and accessibility gaps — products without
  descriptions, images without alt text — and fans the `ai_content` workers out
  to fix them in bulk. Product descriptions and image alt text are written
  directly to the catalog, so the UI tells merchants to review the generated
  text after processing. Ships dark: when AI isn't configured the actions are
  disabled.
  """
  use EmakolaWeb, :live_view

  require Ash.Query

  alias Emakola.Content.Workers.{ImageAltTextWorker, ProductSEOWorker}

  # Bounded by the per-store daily AI cap — no point queuing more than a day's worth.
  @batch 50

  # A merchant with no store has nothing to configure here yet. RequireActiveStore
  # lets them through on purpose (they are mid-onboarding), so send them where
  # the work actually is instead of rendering a page with no store behind it.
  @impl true
  def mount(_params, _session, %{assigns: %{current_store: nil}} = socket) do
    {:ok, Phoenix.LiveView.push_navigate(socket, to: "/onboarding")}
  end

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    {:ok,
     socket
     |> assign(
       page_title: "SEO",
       active_nav: :settings,
       store: store,
       ai_enabled: EmakolaWeb.AiGate.enabled?()
     )
     |> load_gaps()}
  end

  @impl true
  def handle_event("generate_descriptions", _params, socket) do
    products = missing_descriptions(socket.assigns.store.id)
    enqueue(products, fn p -> ProductSEOWorker.new(%{"product_id" => p.id}) end)

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Queued AI descriptions for #{length(products)} product(s). Review them after processing."
     )
     |> load_gaps()}
  end

  def handle_event("generate_alt_text", _params, socket) do
    images = missing_alt_text(socket.assigns.store.id)
    enqueue(images, fn i -> ImageAltTextWorker.new(%{"image_id" => i.id}) end)

    {:noreply,
     socket
     |> put_flash(:info, "Queued AI alt text for #{length(images)} image(s).")
     |> load_gaps()}
  end

  # ── helpers ──

  defp enqueue(records, job_fun) do
    records |> Enum.map(job_fun) |> Enum.each(&Oban.insert/1)
  end

  defp load_gaps(socket) do
    store_id = socket.assigns.store.id

    assign(socket,
      missing_descriptions: length(missing_descriptions(store_id)),
      missing_alt_text: length(missing_alt_text(store_id))
    )
  end

  defp missing_descriptions(store_id) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(is_nil(description) or description == "")
    |> Ash.Query.limit(@batch)
    |> Ash.read!(tenant: store_id, authorize?: false)
  end

  defp missing_alt_text(store_id) do
    Emakola.Catalog.Image
    |> Ash.Query.filter(is_nil(alt_text) or alt_text == "")
    |> Ash.Query.limit(@batch)
    |> Ash.read!(tenant: store_id, authorize?: false)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="seo-dashboard" class="max-w-[1200px] mx-auto px-4 sm:px-6 py-8">
      <.admin_page_header
        icon="hero-magnifying-glass-circle"
        title="SEO quick wins"
        subtitle="Fix content gaps that make products harder to find and understand."
      />

      <div
        :if={@ai_enabled}
        id="seo-direct-save-notice"
        class="mt-6 rounded-lg border border-blue-200 bg-blue-50 p-4 text-sm text-blue-800"
      >
        Generated descriptions and alt text are saved directly to your catalog.
        Review them after the jobs finish and replace generic wording with facts only you know.
      </div>

      <div :if={not @ai_enabled} class="mt-6 rounded-lg border border-amber-200 bg-amber-50 p-4">
        <p class="text-sm font-medium text-amber-800">AI generation isn't switched on yet</p>
        <p class="mt-1 text-sm text-amber-700">
          These quick wins light up once AI content is enabled for the platform.
        </p>
      </div>

      <div class="mt-6 grid gap-4 sm:grid-cols-2">
        <.gap_card
          title="Products without descriptions"
          count={@missing_descriptions}
          action="generate_descriptions"
          cta="Generate and save"
          enabled={@ai_enabled}
        />
        <.gap_card
          title="Images without alt text"
          count={@missing_alt_text}
          action="generate_alt_text"
          cta="Generate and save"
          enabled={@ai_enabled}
        />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :action, :string, required: true
  attr :cta, :string, required: true
  attr :enabled, :boolean, required: true

  defp gap_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-stone-200 bg-white p-5">
      <p class="text-sm text-stone-500">{@title}</p>
      <p class="mt-1 text-3xl font-bold text-stone-900">{@count}</p>
      <button
        :if={@count > 0 and @enabled}
        phx-click={@action}
        class="mt-4 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700"
      >
        {@cta}
      </button>
      <p :if={@count == 0} class="mt-4 text-sm text-emerald-700">All set.</p>
    </div>
    """
  end
end
