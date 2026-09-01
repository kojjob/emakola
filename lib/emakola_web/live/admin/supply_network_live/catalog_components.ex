defmodule EmakolaWeb.Admin.SupplyNetworkLive.CatalogComponents do
  @moduledoc false

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  attr :connection_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :current_store, :any, required: true
  attr :form, :any, required: true
  attr :listing_count, :integer, required: true
  attr :offer_count, :integer, required: true
  attr :streams, :map, required: true

  def catalog(assigns) do
    ~H"""
    <.connection_invite_panel
      connection_count={@connection_count}
      content_draft_count={@content_draft_count}
      current_store={@current_store}
      form={@form}
      listing_count={@listing_count}
      offer_count={@offer_count}
      streams={@streams}
    />
    <.connections
      connection_count={@connection_count}
      content_draft_count={@content_draft_count}
      current_store={@current_store}
      form={@form}
      listing_count={@listing_count}
      offer_count={@offer_count}
      streams={@streams}
    />
    <.earn_catalog
      connection_count={@connection_count}
      content_draft_count={@content_draft_count}
      current_store={@current_store}
      form={@form}
      listing_count={@listing_count}
      offer_count={@offer_count}
      streams={@streams}
    />
    <.earned_listings
      connection_count={@connection_count}
      content_draft_count={@content_draft_count}
      current_store={@current_store}
      form={@form}
      listing_count={@listing_count}
      offer_count={@offer_count}
      streams={@streams}
    />
    <.earn_content_studio
      connection_count={@connection_count}
      content_draft_count={@content_draft_count}
      current_store={@current_store}
      form={@form}
      listing_count={@listing_count}
      offer_count={@offer_count}
      streams={@streams}
    />
    """
  end

  attr :connection_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :current_store, :any, required: true
  attr :form, :any, required: true
  attr :listing_count, :integer, required: true
  attr :offer_count, :integer, required: true
  attr :streams, :map, required: true

  def connection_invite_panel(assigns) do
    ~H"""
    <section
      id="connection-invite-panel"
      class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7"
    >
      <div class="mb-5">
        <h2 class="text-lg font-semibold text-slate-900">Invite a store</h2>
        <p class="mt-1 text-sm text-slate-500">
          Enter the store name from its Makola address, for example <span class="font-medium">kente-kingdom</span>.
        </p>
      </div>

      <.form
        for={@form}
        id="supply-connection-form"
        phx-submit="request_connection"
        class="grid gap-4 md:grid-cols-[1fr_1fr_auto] md:items-end"
      >
        <.input
          field={@form[:partner_slug]}
          type="text"
          label="Store address"
          placeholder="store-name"
          required
        />
        <.input
          field={@form[:relationship]}
          type="select"
          label="What do you want to do?"
          options={[
            {"Sell their products", "resell"},
            {"Supply products to them", "supply"}
          ]}
        />
        <button
          id="send-connection-invite"
          type="submit"
          class="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-emerald-600 px-5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-emerald-700 hover:shadow-md"
        >
          <.icon name="hero-paper-airplane" class="size-4" /> Send invite
        </button>
      </.form>
    </section>
    """
  end

  attr :connection_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :current_store, :any, required: true
  attr :form, :any, required: true
  attr :listing_count, :integer, required: true
  attr :offer_count, :integer, required: true
  attr :streams, :map, required: true

  def connections(assigns) do
    ~H"""
    <section aria-labelledby="connections-heading" class="space-y-4">
      <div class="flex items-end justify-between gap-4">
        <div>
          <h2 id="connections-heading" class="text-xl font-semibold text-slate-900">
            Your connections
          </h2>
          <p class="mt-1 text-sm text-slate-500">
            Both stores must agree before products can be shared.
          </p>
        </div>
        <span
          id="connection-count"
          class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
        >
          {@connection_count}
        </span>
      </div>

      <div id="supply-connections" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
        <div
          id="connections-empty"
          class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-10 text-center"
        >
          <.icon name="hero-link" class="mx-auto size-9 text-slate-300" />
          <p class="mt-3 text-sm font-semibold text-slate-700">No network connections yet</p>
          <p class="mt-1 text-xs text-slate-500">
            Invite a trusted store to start building your supplier network.
          </p>
        </div>

        <article
          :for={{dom_id, connection} <- @streams.connections}
          id={dom_id}
          class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-slate-300 hover:shadow-md"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="flex min-w-0 items-center gap-3">
              <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
                <.icon name="hero-building-storefront" class="size-5" />
              </div>
              <div class="min-w-0">
                <h3 class="truncate font-semibold text-slate-900">
                  {partner(connection, @current_store.id).name}
                </h3>
                <p class="truncate text-xs text-slate-500">
                  @{partner(connection, @current_store.id).slug}
                </p>
              </div>
            </div>
            <span class={[
              "rounded-full px-2.5 py-1 text-[11px] font-semibold capitalize ring-1 ring-inset",
              status_classes(connection.status)
            ]}>
              {connection.status}
            </span>
          </div>

          <p class="mt-4 text-sm text-slate-600">
            {relationship_label(connection, @current_store.id)}
          </p>
          <p :if={connection.status_reason} class="mt-1 text-xs text-slate-400">
            {connection.status_reason}
          </p>

          <div class="mt-5 flex flex-wrap gap-2 border-t border-slate-100 pt-4">
            <%= if incoming?(connection, @current_store.id) do %>
              <button
                id={"approve-connection-#{connection.id}"}
                phx-click="approve_connection"
                phx-value-id={connection.id}
                class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
              >
                Accept
              </button>
              <button
                id={"reject-connection-#{connection.id}"}
                phx-click="reject_connection"
                phx-value-id={connection.id}
                class="rounded-lg border border-slate-200 px-3 py-2 text-xs font-semibold text-slate-600 transition hover:bg-slate-50"
              >
                Decline
              </button>
            <% end %>
            <button
              :if={connection.status == :active}
              id={"suspend-connection-#{connection.id}"}
              phx-click="suspend_connection"
              phx-value-id={connection.id}
              class="rounded-lg border border-amber-200 px-3 py-2 text-xs font-semibold text-amber-700 transition hover:bg-amber-50"
            >
              Pause
            </button>
            <button
              :if={connection.status == :suspended}
              id={"reactivate-connection-#{connection.id}"}
              phx-click="reactivate_connection"
              phx-value-id={connection.id}
              class="rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
            >
              Reactivate
            </button>
            <button
              :if={connection.status in [:pending, :active, :suspended]}
              id={"terminate-connection-#{connection.id}"}
              phx-click="terminate_connection"
              phx-value-id={connection.id}
              class="ml-auto rounded-lg px-3 py-2 text-xs font-semibold text-rose-600 transition hover:bg-rose-50"
            >
              End connection
            </button>
          </div>
        </article>
      </div>
    </section>
    """
  end

  attr :connection_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :current_store, :any, required: true
  attr :form, :any, required: true
  attr :listing_count, :integer, required: true
  attr :offer_count, :integer, required: true
  attr :streams, :map, required: true

  def earn_catalog(assigns) do
    ~H"""
    <section id="earn-catalog" aria-labelledby="earn-catalog-heading" class="space-y-5">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-600">
            Earn catalog
          </span>
          <h2
            id="earn-catalog-heading"
            class="mt-1 text-2xl font-bold tracking-tight text-slate-950"
          >
            Products you can sell today
          </h2>
          <p class="mt-1 max-w-2xl text-sm text-slate-500">
            No stock payment upfront. Add a partner product, share your storefront, and keep the displayed earning when it sells.
          </p>
        </div>
        <span
          id="available-offer-count"
          class="w-fit rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-bold text-emerald-700 ring-1 ring-emerald-600/15"
        >
          {@offer_count} available
        </span>
      </div>

      <p class="text-xs text-slate-500 mb-3">
        Browsing has moved:
        <.link navigate="/admin/supply/catalog" class="text-emerald-700 font-medium">
          Browse Suppliers
        </.link>
        · manage your own offers in
        <.link navigate="/admin/supply/offers" class="text-emerald-700 font-medium">
          My Offers
        </.link>
      </p>

      <div id="earn-offers" phx-update="stream" class="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
        <div
          id="offers-empty"
          class="hidden only:block rounded-3xl border border-dashed border-slate-300 bg-slate-50 p-10 text-center md:col-span-2 xl:col-span-3"
        >
          <.icon name="hero-shopping-bag" class="mx-auto size-9 text-slate-300" />
          <p class="mt-3 text-sm font-semibold text-slate-700">No new products available</p>
          <p class="mt-1 text-xs text-slate-500">
            Connect with a supplier or check back when partners publish new offers.
          </p>
        </div>

        <article
          :for={{dom_id, offer} <- @streams.offers}
          id={dom_id}
          class="group overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-sm transition duration-200 hover:-translate-y-1 hover:border-emerald-200 hover:shadow-xl hover:shadow-emerald-950/5"
        >
          <div class="relative aspect-[16/10] overflow-hidden bg-gradient-to-br from-emerald-50 to-slate-100">
            <img
              :if={lead_image(offer)}
              src={lead_image(offer).url}
              alt={lead_image(offer).alt_text || offer.source_product.title}
              class="size-full object-cover transition duration-500 group-hover:scale-[1.03]"
              loading="lazy"
            />
            <div
              :if={!lead_image(offer)}
              class="flex size-full items-center justify-center text-emerald-200"
            >
              <.icon name="hero-photo" class="size-12" />
            </div>
            <span class="absolute left-3 top-3 rounded-full bg-slate-950/85 px-3 py-1 text-[11px] font-bold text-white backdrop-blur">
              No upfront stock
            </span>
          </div>
          <div class="p-5">
            <p class="text-xs font-medium text-slate-400">{offer.wholesaler_store.name}</p>
            <h3 class="mt-1 line-clamp-2 text-lg font-bold text-slate-900">
              {offer.source_product.title}
            </h3>
            <div id={"offer-stock-badge-#{offer.id}"} class="mt-2">
              <.supplier_stock_badge status={offer_stock_status(offer)} />
            </div>
            <div class="mt-4 grid grid-cols-2 gap-3 rounded-2xl bg-slate-50 p-3">
              <div>
                <p class="text-[10px] font-bold uppercase tracking-wide text-slate-400">Sell for</p>
                <p class="mt-1 text-sm font-bold text-slate-800">{retail_range(offer)}</p>
              </div>
              <div class="border-l border-slate-200 pl-3">
                <p class="text-[10px] font-bold uppercase tracking-wide text-emerald-600">
                  You earn
                </p>
                <p class="mt-1 text-sm font-bold text-emerald-700">{earning_range(offer)}</p>
              </div>
            </div>
            <%!-- What the SUPPLIER will take back from you. Your shoppers are
                   quoted your own returns policy, not this — you are the seller
                   of record — so any promise you make beyond this line is one
                   you absorb yourself. Better to see it before you import. --%>
            <div class="mt-3 rounded-2xl border border-slate-100 bg-white px-3 py-2">
              <p class="text-[10px] font-bold uppercase tracking-wide text-slate-400">
                Supplier backs
              </p>
              <p class={[
                "mt-1 text-xs font-semibold",
                if(supplier_terms(offer) == [], do: "text-amber-700", else: "text-slate-700")
              ]}>
                {supplier_backing_line(offer)}
              </p>
              <p :if={offer.return_terms} class="mt-1 text-[11px] leading-snug text-slate-500">
                {offer.return_terms}
              </p>
            </div>
            <button
              id={"import-offer-#{offer.id}"}
              phx-click="import_offer"
              phx-value-id={offer.id}
              class="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 py-3 text-sm font-bold text-white shadow-sm transition hover:bg-emerald-700 active:scale-[0.98]"
            >
              <.icon name="hero-plus" class="size-4" /> Add to my store
            </button>
          </div>
        </article>
      </div>
    </section>
    """
  end

  attr :connection_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :current_store, :any, required: true
  attr :form, :any, required: true
  attr :listing_count, :integer, required: true
  attr :offer_count, :integer, required: true
  attr :streams, :map, required: true

  def earned_listings(assigns) do
    ~H"""
    <section id="earned-listings" aria-labelledby="earned-listings-heading" class="space-y-4">
      <div class="flex items-center justify-between gap-4">
        <div>
          <h2 id="earned-listings-heading" class="text-xl font-semibold text-slate-900">
            Added from partners
          </h2>
          <p class="mt-1 text-sm text-slate-500">
            These products behave like the rest of your catalog and fulfill through their supplier.
          </p>
        </div>
        <span
          id="listing-count"
          class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-600"
        >
          {@listing_count}
        </span>
      </div>
      <div id="reseller-listings" phx-update="stream" class="grid gap-3 sm:grid-cols-2">
        <div
          id="listings-empty"
          class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center sm:col-span-2"
        >
          <p class="text-sm font-semibold text-slate-700">
            You have not added a partner product yet.
          </p>
        </div>
        <article
          :for={{dom_id, listing} <- @streams.listings}
          id={dom_id}
          class="flex flex-wrap sm:flex-nowrap items-center gap-3 sm:gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm"
        >
          <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-700">
            <.icon name="hero-check" class="size-5" />
          </div>
          <div class="min-w-0 flex-1">
            <h3 class="truncate text-sm font-semibold text-slate-900">
              {listing.reseller_product.title}
            </h3>
            <p class="mt-0.5 text-xs capitalize text-slate-500">
              {listing.status} · Synced from partner
            </p>
            <div id={"listing-stock-badge-#{listing.id}"} class="mt-1.5">
              <.supplier_stock_badge status={listing_stock_status(listing)} />
            </div>
          </div>
          <button
            id={"create-content-draft-#{listing.id}"}
            phx-click="create_content_draft"
            phx-value-id={listing.id}
            phx-value-locale="en-GH"
            class="rounded-lg border border-violet-200 px-3 py-2 text-xs font-bold text-violet-700 transition hover:bg-violet-50"
          >
            Content
          </button>
          <button
            id={"create-twi-content-draft-#{listing.id}"}
            phx-click="create_content_draft"
            phx-value-id={listing.id}
            phx-value-locale="tw-GH"
            class="rounded-lg border border-amber-200 px-3 py-2 text-xs font-bold text-amber-700 transition hover:bg-amber-50"
          >
            Twi
          </button>
          <button
            id={"create-sales-kit-#{listing.id}"}
            phx-click="create_sales_kit"
            phx-value-id={listing.id}
            class="rounded-lg border border-emerald-200 px-3 py-2 text-xs font-bold text-emerald-700 transition hover:bg-emerald-50"
          >
            Sales kit
          </button>
          <.link
            navigate={~p"/admin/products/#{listing.reseller_product_id}/edit"}
            class="rounded-lg p-2 text-slate-400 transition hover:bg-slate-50 hover:text-slate-700"
            aria-label={"Edit #{listing.reseller_product.title}"}
          >
            <.icon name="hero-pencil-square" class="size-4" />
          </.link>
        </article>
      </div>
    </section>
    """
  end

  attr :connection_count, :integer, required: true
  attr :content_draft_count, :integer, required: true
  attr :current_store, :any, required: true
  attr :form, :any, required: true
  attr :listing_count, :integer, required: true
  attr :offer_count, :integer, required: true
  attr :streams, :map, required: true

  def earn_content_studio(assigns) do
    ~H"""
    <section id="earn-content-studio" aria-labelledby="content-studio-heading" class="space-y-4">
      <div class="flex items-end justify-between gap-4">
        <div>
          <span class="text-xs font-bold uppercase tracking-[0.18em] text-violet-600">
            Content Studio
          </span>
          <h2 id="content-studio-heading" class="mt-1 text-xl font-bold text-slate-950">
            Fact-grounded drafts you control
          </h2>
          <p class="mt-1 max-w-2xl text-sm text-slate-500">
            Every draft is constrained to the supplier's approved facts. Nothing is published until you review and approve it.
          </p>
        </div>
        <span
          id="content-draft-count"
          class="rounded-full bg-violet-50 px-3 py-1 text-xs font-bold text-violet-700"
        >
          {@content_draft_count}
        </span>
      </div>

      <div id="content-drafts" phx-update="stream" class="grid gap-4 lg:grid-cols-2">
        <div
          id="content-drafts-empty"
          class="hidden only:block rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center lg:col-span-2"
        >
          <p class="text-sm font-semibold text-slate-700">
            Create a draft from one of your partner products.
          </p>
        </div>
        <article
          :for={{dom_id, draft} <- @streams.content_drafts}
          id={dom_id}
          class="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="text-xs font-bold uppercase tracking-wide text-violet-600">
                {draft.locale} · {draft.generator}
              </p>
              <h3 class="mt-1 font-bold text-slate-900">{draft.source_facts["product_title"]}</h3>
            </div>
            <span class={[
              "rounded-full px-2.5 py-1 text-[11px] font-bold capitalize",
              content_status_classes(draft.status)
            ]}>
              {draft.status}
            </span>
          </div>
          <div class="mt-4 space-y-3">
            <img
              :if={draft.content["social_card_data_uri"]}
              id={"content-social-card-#{draft.id}"}
              src={draft.content["social_card_data_uri"]}
              alt={"Sales card for #{draft.source_facts["product_title"]}"}
              class="aspect-square w-full rounded-xl border border-slate-200 object-cover"
            />
            <div class="rounded-xl bg-emerald-50 p-3">
              <p class="text-[10px] font-bold uppercase text-emerald-700">WhatsApp</p>
              <p class="mt-1 text-sm leading-5 text-slate-700">{draft.content["whatsapp"]}</p>
            </div>
            <div class="rounded-xl bg-blue-50 p-3">
              <p class="text-[10px] font-bold uppercase text-blue-700">Facebook</p>
              <p class="mt-1 text-sm leading-5 text-slate-700">{draft.content["facebook"]}</p>
            </div>
            <details class="rounded-xl border border-slate-200 p-3">
              <summary class="cursor-pointer text-xs font-bold text-slate-700">
                View source facts
              </summary>
              <dl class="mt-3 space-y-2 text-xs">
                <div>
                  <dt class="text-slate-400">Supplier description</dt>
                  <dd class="text-slate-700">{draft.source_facts["supplier_description"]}</dd>
                </div>
                <div>
                  <dt class="text-slate-400">Return terms</dt>
                  <dd class="text-slate-700">{draft.source_facts["return_terms"]}</dd>
                </div>
              </dl>
            </details>
          </div>
          <div :if={draft.status == :draft} class="mt-4 flex gap-2 border-t border-slate-100 pt-4">
            <button
              id={"approve-content-draft-#{draft.id}"}
              phx-click="approve_content_draft"
              phx-value-id={draft.id}
              class="rounded-xl bg-emerald-600 px-4 py-2 text-xs font-bold text-white transition hover:bg-emerald-700"
            >
              Approve
            </button>
            <button
              id={"reject-content-draft-#{draft.id}"}
              phx-click="reject_content_draft"
              phx-value-id={draft.id}
              class="rounded-xl border border-rose-200 px-4 py-2 text-xs font-bold text-rose-700 transition hover:bg-rose-50"
            >
              Reject
            </button>
          </div>
        </article>
      </div>
    </section>
    """
  end
end
