defmodule EmakolaWeb.Admin.SupplyNetworkLive.CollaborationComponents do
  @moduledoc false

  use EmakolaWeb, :html

  import EmakolaWeb.Admin.SupplyNetworkLive.Presentation

  attr :collaboration_owned_offers, :list, required: true
  attr :commerce_passport, :any, required: true
  attr :current_store, :any, required: true
  attr :franchise_form, :any, required: true
  attr :group_buy_form, :any, required: true
  attr :hustle_listings, :list, required: true
  attr :inventory_policy_form, :any, required: true
  attr :inventory_reservation_forms, :map, required: true
  attr :passport_appeal_forms, :map, required: true
  attr :sales_team_form, :any, required: true
  attr :streams, :map, required: true

  def collaboration(assigns) do
    ~H"""
    <section
      id="collaborative-commerce"
      aria-labelledby="collaborative-commerce-heading"
      class="space-y-6 rounded-3xl border border-fuchsia-200 bg-fuchsia-50/40 p-6 shadow-sm sm:p-8"
    >
      <div>
        <span class="text-xs font-bold uppercase tracking-[0.18em] text-fuchsia-700">
          Collaborative Commerce
        </span>
        <h2 id="collaborative-commerce-heading" class="mt-1 text-2xl font-bold text-slate-950">
          Contribute demand, skills, or a proven playbook—not recruitment
        </h2>
        <p class="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
          Group buys have visible thresholds and refund dates. Team earnings total exactly 100% and require personal consent. Micro-franchises reward product sales only—never downlines.
        </p>
      </div>

      <div class="grid gap-5 xl:grid-cols-3">
        <div class="rounded-2xl border border-fuchsia-100 bg-white p-5 shadow-sm">
          <h3 class="font-bold text-slate-900">Open a group buy</h3>
          <p class="mt-1 text-xs text-slate-500">
            Customers commit to one variant at a locked price.
          </p>
          <.form
            for={@group_buy_form}
            id="group-buy-form"
            phx-submit="create_group_buy"
            class="mt-4 space-y-3"
          >
            <.input
              field={@group_buy_form[:listing_variant_id]}
              type="select"
              label="Product variant"
              prompt="Choose a product"
              options={group_buy_options(@hustle_listings)}
              required
            />
            <.input field={@group_buy_form[:title]} type="text" label="Campaign name" required />
            <div class="grid grid-cols-2 gap-3">
              <.input
                field={@group_buy_form[:threshold_quantity]}
                type="number"
                min="2"
                max="1000"
                label="Threshold"
                required
              /><.input
                field={@group_buy_form[:unit_price]}
                type="number"
                min="0.01"
                step="0.01"
                label="Price (GH₵)"
                required
              />
            </div>
            <.input
              field={@group_buy_form[:deadline]}
              type="datetime-local"
              label="Commitment deadline"
              required
            />
            <.input
              field={@group_buy_form[:refund_deadline]}
              type="datetime-local"
              label="Refund completed by"
              required
            />
            <button
              id="create-group-buy"
              type="submit"
              class="w-full rounded-xl bg-fuchsia-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-fuchsia-800"
            >
              Open protected group buy
            </button>
          </.form>
          <div id="group-buy-campaigns" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, campaign} <- @streams.group_buys}
              id={dom_id}
              class="rounded-xl bg-fuchsia-50 p-3 text-xs"
            >
              <p class="font-bold text-fuchsia-900">{campaign.title}</p>
              <p class="mt-1 text-fuchsia-800">
                {campaign.committed_quantity}/{campaign.threshold_quantity} paid · {money(
                  campaign.unit_price
                )} · {campaign.status}
              </p>
              <p class="mt-1 text-fuchsia-700">
                Refund by {Calendar.strftime(campaign.refund_deadline, "%d %b %Y %H:%M UTC")} if threshold is missed.
              </p>
            </article>
          </div>
        </div>

        <div class="rounded-2xl border border-fuchsia-100 bg-white p-5 shadow-sm">
          <h3 class="font-bold text-slate-900">Create a flat sales team</h3>
          <p class="mt-1 text-xs text-slate-500">
            One collaborator, declared role, exact split; expandable through the service boundary.
          </p>
          <.form
            for={@sales_team_form}
            id="sales-team-form"
            phx-submit="create_sales_team"
            class="mt-4 space-y-3"
          >
            <.input field={@sales_team_form[:name]} type="text" label="Team name" required />
            <.input
              field={@sales_team_form[:collaborator_email]}
              type="email"
              label="Collaborator's Makola email"
              required
            />
            <.input
              field={@sales_team_form[:collaborator_role]}
              type="select"
              label="Declared role"
              options={[
                {"Seller", "seller"},
                {"Content", "content"},
                {"Customer support", "support"}
              ]}
            />
            <div class="grid grid-cols-2 gap-3">
              <.input
                field={@sales_team_form[:owner_percent]}
                type="number"
                min="1"
                max="99"
                step="0.01"
                label="Your %"
                required
              /><.input
                field={@sales_team_form[:collaborator_percent]}
                type="number"
                min="1"
                max="99"
                step="0.01"
                label="Their %"
                required
              />
            </div>
            <button
              id="create-sales-team"
              type="submit"
              class="w-full rounded-xl bg-slate-950 px-4 py-3 text-sm font-bold text-white transition hover:bg-fuchsia-800"
            >
              Send consent invitation
            </button>
          </.form>
          <div id="sales-team-invitations" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, member} <- @streams.sales_team_invitations}
              id={dom_id}
              class="rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs"
            >
              <p class="font-bold text-amber-900">
                {member.team.name}: {member.role} · {member.split_bps / 100}%
              </p>
              <button
                id={"accept-sales-team-#{member.id}"}
                phx-click="accept_sales_team"
                phx-value-id={member.id}
                class="mt-2 rounded-lg bg-amber-700 px-3 py-1.5 font-bold text-white"
              >
                Accept role and split
              </button>
            </article>
          </div>
          <div id="sales-teams" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, team} <- @streams.sales_teams}
              id={dom_id}
              class="rounded-xl bg-slate-50 p-3 text-xs"
            >
              <p class="font-bold text-slate-800">{team.name}</p>
              <p class="mt-1 text-slate-500">{length(team.members)} flat members · {team.status}</p>
              <p class="mt-2 break-all rounded-lg bg-white px-2 py-1.5 font-mono text-[10px] text-emerald-700">
                {EmakolaWeb.Endpoint.url()}/s/{@current_store.slug}?sales_team={team.id}
              </p>
            </article>
          </div>
        </div>

        <div class="rounded-2xl border border-fuchsia-100 bg-white p-5 shadow-sm">
          <h3 class="font-bold text-slate-900">Package a micro-franchise</h3>
          <p class="mt-1 text-xs text-slate-500">
            For suppliers: training, rules, channels, territory, and sales commission.
          </p>
          <.form
            for={@franchise_form}
            id="franchise-package-form"
            phx-submit="create_franchise_package"
            class="mt-4 space-y-3"
          >
            <.input field={@franchise_form[:name]} type="text" label="Package name" required />
            <.input
              field={@franchise_form[:offer_id]}
              type="select"
              prompt="Choose your published offer"
              label="Product offer"
              options={franchise_offer_options(@collaboration_owned_offers)}
              required
            />
            <.input
              field={@franchise_form[:training]}
              type="textarea"
              label="Required training"
              required
            />
            <.input
              field={@franchise_form[:brand_rules]}
              type="textarea"
              label="Brand and claims rules"
              required
            />
            <.input field={@franchise_form[:territory]} type="text" label="Territory (optional)" />
            <.input
              field={@franchise_form[:commission_bps]}
              type="number"
              min="1"
              max="10000"
              label="Commission (basis points)"
              required
            />
            <input type="hidden" name="franchise[channel_permissions][]" value="storefront" /><input
              type="hidden"
              name="franchise[channel_permissions][]"
              value="whatsapp"
            />
            <button
              id="create-franchise-package"
              type="submit"
              class="w-full rounded-xl bg-fuchsia-700 px-4 py-3 text-sm font-bold text-white transition hover:bg-fuchsia-800"
            >
              Publish product-sales package
            </button>
          </.form>
          <div id="owned-franchise-packages" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, package} <- @streams.owned_franchise_packages}
              id={dom_id}
              class="rounded-xl border border-fuchsia-100 bg-fuchsia-50 p-3 text-xs"
            >
              <p class="font-bold text-fuchsia-950">{package.name}</p>
              <div id={"franchise-enrollments-#{package.id}"} class="mt-2 space-y-2">
                <div
                  :for={enrollment <- package.enrollments}
                  id={"franchise-enrollment-#{enrollment.id}"}
                  class="flex items-center justify-between gap-3 rounded-lg bg-white p-2"
                >
                  <span>{enrollment.reseller_store.name} · {enrollment.status}</span>
                  <button
                    :if={enrollment.status == :applied}
                    id={"approve-franchise-#{enrollment.id}"}
                    phx-click="approve_franchise"
                    phx-value-id={enrollment.id}
                    class="rounded-lg bg-fuchsia-700 px-3 py-1.5 font-bold text-white transition hover:bg-fuchsia-600"
                  >
                    Approve and activate catalog
                  </button>
                  <span :if={enrollment.status == :approved} class="font-bold text-emerald-700">
                    {length(enrollment.activated_listing_ids)} products active
                  </span>
                </div>
              </div>
            </article>
          </div>
          <div id="available-franchise-packages" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, package} <- @streams.available_franchise_packages}
              id={dom_id}
              class="rounded-xl bg-emerald-50 p-3 text-xs"
            >
              <p class="font-bold text-emerald-900">{package.name}</p>
              <p class="mt-1 text-emerald-800">
                {package.commission_bps / 100}% product-sales commission · {package.territory ||
                  "Open territory"}
              </p>
              <button
                id={"apply-franchise-#{package.id}"}
                phx-click="apply_franchise"
                phx-value-id={package.id}
                class="mt-2 rounded-lg bg-emerald-700 px-3 py-1.5 font-bold text-white"
              >
                Accept terms and apply
              </button>
            </article>
          </div>
        </div>
      </div>
    </section>

    <section
      :if={@commerce_passport}
      id="commerce-passport"
      class="rounded-3xl border border-indigo-200 bg-gradient-to-br from-indigo-950 to-slate-950 p-6 text-white shadow-xl sm:p-8"
    >
      <div class="flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <p class="text-xs font-bold uppercase tracking-[0.2em] text-indigo-300">
            Portable commerce passport
          </p>
          <div class="mt-2 flex items-end gap-3">
            <span id="passport-score" class="text-5xl font-black">{@commerce_passport.score}</span>
            <span
              id="passport-tier"
              class="mb-1 rounded-full bg-white/10 px-3 py-1 text-sm font-bold capitalize"
            >
              {@commerce_passport.tier}
            </span>
          </div>
          <p class="mt-3 max-w-2xl text-sm leading-6 text-indigo-100">
            Built only from fulfilled orders, service outcomes, refunds, and verified supplier training. Every signal below has evidence, a reason code, and an expiry date.
          </p>
        </div>
        <button
          id="refresh-commerce-passport"
          phx-click="refresh_commerce_passport"
          class="rounded-xl bg-indigo-300 px-4 py-2.5 text-sm font-black text-indigo-950 transition hover:-translate-y-0.5 hover:bg-indigo-200"
        >
          Refresh evidence
        </button>
      </div>

      <div id="commerce-signals" phx-update="stream" class="mt-6 grid gap-3 lg:grid-cols-2">
        <article
          :for={{dom_id, signal} <- @streams.commerce_signals}
          id={dom_id}
          class="rounded-2xl border border-white/10 bg-white/5 p-4"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <p class="font-bold capitalize">
                {signal.kind |> Atom.to_string() |> String.replace("_", " ")}
              </p>
              <p class="mt-1 font-mono text-[11px] text-indigo-300">{signal.reason_code}</p>
            </div>
            <span class={[
              "rounded-full px-2 py-1 text-[10px] font-bold uppercase",
              if(signal.impact >= 0,
                do: "bg-emerald-400/15 text-emerald-200",
                else: "bg-rose-400/15 text-rose-200"
              )
            ]}>
              {if(signal.impact >= 0, do: "+", else: "")}{signal.impact} pts
            </span>
          </div>
          <p class="mt-3 text-xs text-indigo-100">Evidence: {Jason.encode!(signal.evidence)}</p>
          <p class="mt-1 text-[11px] text-indigo-300">
            Expires {Calendar.strftime(signal.expires_at, "%d %b %Y")}
          </p>
          <.form
            :if={signal.status == :active}
            for={Map.fetch!(@passport_appeal_forms, signal.id)}
            id={"passport-appeal-form-#{signal.id}"}
            phx-submit="appeal_reputation_signal"
            class="mt-3 flex items-end gap-2"
          >
            <.input field={Map.fetch!(@passport_appeal_forms, signal.id)[:signal_id]} type="hidden" />
            <.input
              field={Map.fetch!(@passport_appeal_forms, signal.id)[:reason]}
              type="text"
              label="Challenge this evidence"
              placeholder="Explain what is wrong or missing"
              class="min-w-0 flex-1 rounded-lg border border-white/20 bg-white px-3 py-2 text-xs text-slate-950"
            />
            <button class="rounded-lg border border-indigo-300 px-3 py-2 text-xs font-bold text-indigo-100 hover:bg-white/10">
              Appeal
            </button>
          </.form>
          <p :if={signal.status == :appealed} class="mt-3 text-xs font-bold text-amber-200">
            Appeal open — this signal is flagged for review.
          </p>
        </article>
      </div>
    </section>

    <section
      id="inventory-eligibility"
      class="rounded-3xl border border-amber-200 bg-amber-50/70 p-6 shadow-sm sm:p-8"
    >
      <div class="grid gap-6 xl:grid-cols-2">
        <div>
          <p class="text-xs font-bold uppercase tracking-[0.18em] text-amber-700">Supplier rules</p>
          <h2 class="mt-1 text-2xl font-black text-slate-950">Reserve stock by transparent tier</h2>
          <p class="mt-2 text-sm leading-6 text-slate-600">
            Publish the minimum passport tier, exact unit cap, reason code, and automatic expiry. Held stock is removed atomically and unused units return automatically.
          </p>
          <.form
            for={@inventory_policy_form}
            id="inventory-policy-form"
            phx-submit="create_inventory_policy"
            class="mt-5 grid gap-3 sm:grid-cols-2"
          >
            <.input
              field={@inventory_policy_form[:offer_variant_id]}
              type="select"
              label="Offer variant"
              prompt="Choose tracked stock"
              options={inventory_policy_options(@collaboration_owned_offers)}
              required
            />
            <.input
              field={@inventory_policy_form[:minimum_tier]}
              type="select"
              label="Minimum tier"
              options={[{"Starter", "starter"}, {"Reliable", "reliable"}, {"Proven", "proven"}]}
            />
            <.input
              field={@inventory_policy_form[:max_quantity_per_reseller]}
              type="number"
              min="1"
              label="Unit cap per reseller"
            />
            <.input
              field={@inventory_policy_form[:reservation_hours]}
              type="number"
              min="1"
              max="720"
              label="Hold duration (hours)"
            />
            <button
              id="publish-inventory-policy"
              class="sm:col-span-2 rounded-xl bg-amber-600 px-4 py-2.5 text-sm font-black text-white transition hover:bg-amber-500"
            >
              Publish eligibility rule
            </button>
          </.form>
          <div id="owned-inventory-policies" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, policy} <- @streams.owned_inventory_policies}
              id={dom_id}
              class="rounded-xl bg-white p-3 text-xs text-slate-700"
            >
              <p class="font-bold text-slate-950">{policy.reason_code}</p>
              <p class="mt-1 capitalize">
                {policy.minimum_tier}+ · up to {policy.max_quantity_per_reseller} units · {policy.reservation_hours}h
              </p>
            </article>
          </div>
        </div>

        <div>
          <p class="text-xs font-bold uppercase tracking-[0.18em] text-emerald-700">
            Your eligible holds
          </p>
          <div id="eligible-inventory-policies" phx-update="stream" class="mt-3 space-y-3">
            <p
              id="eligible-inventory-empty"
              class="hidden only:block rounded-xl border border-dashed border-emerald-200 bg-white p-4 text-sm text-slate-500"
            >
              No connected supplier rule currently matches your passport tier.
            </p>
            <article
              :for={{dom_id, policy} <- @streams.eligible_inventory_policies}
              id={dom_id}
              class="rounded-2xl border border-emerald-200 bg-white p-4"
            >
              <p class="text-sm font-black text-slate-950">
                {policy.offer_variant.offer.source_product.title}
              </p>
              <p class="mt-1 font-mono text-[11px] text-emerald-700">{policy.reason_code}</p>
              <p class="mt-1 text-xs text-slate-500 capitalize">
                Requires {policy.minimum_tier}+ · cap {policy.max_quantity_per_reseller} · expires after {policy.reservation_hours}h
              </p>
              <.form
                for={Map.fetch!(@inventory_reservation_forms, policy.id)}
                id={"reserve-inventory-form-#{policy.id}"}
                phx-submit="reserve_eligible_inventory"
                class="mt-3 flex items-end gap-2"
              >
                <.input
                  field={Map.fetch!(@inventory_reservation_forms, policy.id)[:policy_id]}
                  type="hidden"
                />
                <.input
                  field={Map.fetch!(@inventory_reservation_forms, policy.id)[:quantity]}
                  type="number"
                  min="1"
                  max={policy.max_quantity_per_reseller}
                  label="Units"
                  class="w-24 rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm"
                />
                <button class="rounded-lg bg-emerald-700 px-3 py-2.5 text-xs font-bold text-white hover:bg-emerald-600">
                  Hold stock
                </button>
              </.form>
            </article>
          </div>
          <div id="inventory-reservations" phx-update="stream" class="mt-4 space-y-2">
            <article
              :for={{dom_id, reservation} <- @streams.inventory_reservations}
              id={dom_id}
              class="flex items-center justify-between gap-3 rounded-xl bg-slate-950 p-3 text-xs text-white"
            >
              <div>
                <p class="font-bold">
                  {reservation.quantity - reservation.consumed_quantity} of {reservation.quantity} held · {reservation.status}
                </p>
                <p class="mt-1 text-slate-400">
                  {reservation.reason_code} · until {Calendar.strftime(
                    reservation.expires_at,
                    "%d %b %H:%M"
                  )}
                </p>
              </div>
              <button
                :if={reservation.status == :active}
                id={"release-inventory-#{reservation.id}"}
                phx-click="release_inventory_reservation"
                phx-value-id={reservation.id}
                class="rounded-lg border border-slate-600 px-3 py-1.5 font-bold hover:bg-slate-800"
              >
                Release
              </button>
            </article>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
