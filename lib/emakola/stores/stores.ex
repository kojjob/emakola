defmodule Emakola.Stores do
  @moduledoc """
  The Stores domain — the multi-tenant anchor.

  Extracted from `Emakola.Accounts` on 2026-04-26. The `Store` resource
  itself moved here; `StoreMembership` (the merchant↔store bridge)
  stays in Accounts since it's identity-related.

  See `docs/PLAN-domain-restructuring-2026-04-26.md` Step 3 for the
  rationale and call-site list.

  The `stores` database table is unchanged; only the resource module
  namespace moves.
  """

  use Ash.Domain

  resources do
    resource Emakola.Stores.Store do
      define(:create_store, action: :create)
      define(:get_store, action: :read, get_by: [:id])
      define(:get_store_by_slug, action: :get_by_slug, args: [:slug])
      define(:update_store_settings, action: :update_settings)
      define(:update_store_directory_meta, action: :update_directory_meta)
      define(:list_stores_by_slugs, action: :list_by_slugs, args: [:slugs])
      define(:list_stores_for_admin, action: :list_for_admin, args: [:search])
      # Platform lifecycle — call with `authorize?: false` (gated in the LiveView).
      define(:suspend_store, action: :suspend)
      define(:block_store, action: :block)
      define(:archive_store, action: :archive)
      define(:reactivate_store, action: :reactivate)
    end

    resource(Emakola.Stores.DirectoryStanding)

    resource Emakola.Stores.StorePayoutAccount do
      define(:get_payout_account, action: :get_by_store, args: [:store_id])
      define(:create_payout_account, action: :create)
      define(:update_payout_account, action: :update)
      define(:record_payout_subaccount, action: :record_subaccount)
    end

    resource Emakola.Stores.StorePageContent do
      define(:get_page_content, action: :get_by_store, args: [:store_id])
      define(:create_page_content, action: :create)
      define(:update_page_content, action: :update)
    end

    resource Emakola.Stores.StoreVerification do
      define(:get_store_verification, action: :get_by_store, args: [:store_id])
      define(:list_verifications_for_review, action: :list_for_review)
      define(:submit_store_verification, action: :submit)
      define(:resubmit_store_verification, action: :resubmit)
      # Platform-only review actions — call with `authorize?: false` (gated in the LiveView).
      define(:approve_store_verification, action: :approve)
      define(:reject_store_verification, action: :reject)
    end

    resource Emakola.Stores.StoreDomain do
      define(:create_store_domain, action: :create)
      define(:get_store_domain_by_host, action: :get_by_host, args: [:host])
      define(:list_store_domains, action: :list_for_store, args: [:store_id])
      define(:update_store_domain, action: :update)
      define(:destroy_store_domain, action: :destroy)

      define(:claim_custom_domain, action: :claim_custom)
      define(:claim_custom_domain_alias, action: :claim_custom_alias)
      define(:request_domain_verification, action: :request_verification)
      define(:record_domain_check, action: :record_check)
      define(:mark_domain_active, action: :mark_active)
      define(:expire_store_domain, action: :expire)
      define(:make_domain_primary, action: :make_primary)
      define(:list_verifying_domains, action: :list_verifying)
      define(:list_custom_domains_for_review, action: :list_custom_for_review)
      define(:get_primary_custom_domain_by_slug, action: :get_primary_by_slug, args: [:slug])
    end
  end

  @doc """
  Active-store counts per theme, for the marketplace directory's filter
  chips — `%{"market" => 12, "atelier" => 4, ...}`.

  One GROUP BY instead of one COUNT per theme (the directory previously ran
  ~11 sequential counts on every unguarded public-page mount). A store with
  no `theme_config["theme"]` set falls back to `"market"`, mirroring
  `Store.list_with_filters`'s theme-argument fallback. A theme with zero
  active stores is simply absent — callers already treat a missing key the
  same as zero (`Map.get(counts, id) && count > 0`).
  """
  @spec theme_counts() :: %{String.t() => pos_integer()}
  def theme_counts do
    import Ecto.Query

    from(s in Emakola.Stores.Store,
      where: s.active == true and s.status == :active,
      group_by: fragment("COALESCE(?->>'theme', 'market')", s.theme_config),
      select: {fragment("COALESCE(?->>'theme', 'market')", s.theme_config), count(s.id)}
    )
    |> Emakola.Repo.all()
    |> Map.new()
  end

  @doc """
  Active-store counts per Ghanaian region, for the directory's map picker —
  `%{"Greater Accra" => 6, "Ashanti" => 1, ...}`.

  One GROUP BY over the whole directory. The map previously counted the
  stores the page had paginated in so far, which made the numbers a function
  of how far the shopper had scrolled, and looked them up under a snake_case
  slug that `Store.region` never holds — so every region read "0 stores"
  however many shops were in it.

  Keyed by the canonical region name, the same string `list_with_filters`
  matches on, so a key here can be handed straight to the region filter.
  A region with no active stores is simply absent; callers treat a missing
  key as zero.
  """
  @spec region_counts() :: %{String.t() => pos_integer()}
  def region_counts do
    import Ecto.Query

    from(s in Emakola.Stores.Store,
      where: s.active == true and s.status == :active and not is_nil(s.region),
      group_by: s.region,
      select: {s.region, count(s.id)}
    )
    |> Emakola.Repo.all()
    |> Map.new()
  end

  @featuring_floor_flag "directory_featuring_floor"

  @doc """
  Whether the merit floor under the directory's featured slots is being
  enforced tonight.

  A platform switch, not a deploy: it reads the `#{@featuring_floor_flag}`
  feature flag, so the project owner turns the floor on and off from
  /platform/settings and the next nightly featuring run obeys.

  Off is the young-marketplace setting and the reason the switch exists. The
  floor (`DirectoryEligibility`) asks for a verified payout account, and
  payout verification runs on the payout rail — while that rail is dark no
  shop can clear the bar. Production ran a nightly pass where 40 of 41 live
  shops failed `:no_payout`, every featured slot emptied, and /stores lost
  its hero: a floor enforcing a condition the platform has not shipped does
  not protect buyers, it blanks the shop window. Turn it on once merchants
  can actually clear it.

  A missing flag row reads as off, which is the state a directory this young
  wants. The verdicts are unaffected either way — `DirectoryStanding` still
  records every disqualifier, so a merchant is told what to fix and the floor
  can be switched back on knowing exactly who it would bar.
  """
  @spec featuring_floor_enforced?() :: boolean()
  def featuring_floor_enforced?, do: Emakola.FeatureFlags.enabled?(@featuring_floor_flag)
end
