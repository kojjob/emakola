defmodule Emakola.Orders.PayLink do
  @moduledoc """
  A shareable checkout link a merchant drops into a DM. Two flavors:

    * `:catalog` — points at a variant, reusable, no default expiry.
    * `:custom` — negotiated `title` + `amount` (minor units), single-use
      (consumed → `:paid` by the webhook claim), default expiry 7 days.

  Expiry is data — `usable?/1` compares against now; nothing sweeps links.
  """

  use Ash.Resource,
    domain: Emakola.Orders,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("pay_links")
    repo(Emakola.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:store_id, :uuid, allow_nil?: false, public?: true)
    attribute(:code, :string, allow_nil?: false, public?: true)

    attribute(:type, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:catalog, :custom]]
    )

    attribute(:variant_id, :uuid, public?: true)
    attribute(:quantity, :integer, allow_nil?: false, default: 1, public?: true)
    attribute(:title, :string, public?: true, constraints: [max_length: 200])
    attribute(:amount, :integer, public?: true)
    attribute(:collect_delivery, :boolean, allow_nil?: false, default: true, public?: true)

    attribute :status, :atom do
      allow_nil?(false)
      default(:active)
      public?(true)
      constraints(one_of: [:active, :paid, :cancelled])
    end

    attribute(:expires_at, :utc_datetime_usec, public?: true)
    attribute(:note, :string, public?: true, constraints: [max_length: 500])
    attribute(:opened_count, :integer, allow_nil?: false, default: 0, public?: true)
    attribute(:created_by_user_id, :uuid, public?: true)

    # Set by PayLinkClaim.claim_for_order/1 when the link transitions to
    # :paid. Distinguishes an idempotent retry of the SAME winning order's
    # webhook job (claimed_order_id matches, no-op) from a genuine second
    # order racing a just-consumed link (claimed_order_id differs, flag for
    # refund attention).
    attribute(:claimed_order_id, :uuid, public?: true)
    timestamps()
  end

  identities do
    # all_tenants?: true — code must be unique across every store, not just
    # within one. The buyer-facing lookup (get_by_code, below) has no store
    # context to disambiguate with; without this, ash_postgres would default
    # to a (store_id, code) index and two stores could mint the same code.
    identity(:unique_code, [:code], all_tenants?: true)
  end

  policies do
    bypass action_type(:action) do
      authorize_if(always())
    end

    # Merchant store-membership for create/cancel; public buyer reads and
    # webhook/internal updates opt in via authorize?: false at call sites —
    # the same posture as Order/LineItem.
    policy action_type([:create, :update]) do
      forbid_unless(actor_present())
      forbid_unless(actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant))
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end

    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  validations do
    validate(present([:variant_id]),
      where: [attribute_equals(:type, :catalog)],
      message: "catalog links need a product variant"
    )

    validate(present([:title, :amount]),
      where: [attribute_equals(:type, :custom)],
      message: "custom links need a title and amount"
    )

    validate(compare(:amount, greater_than_or_equal_to: 100),
      where: [present(:amount)],
      message: "must be at least 100 (GH₵1.00)"
    )

    validate(compare(:quantity, greater_than: 0))
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :store_id,
        :type,
        :variant_id,
        :quantity,
        :title,
        :amount,
        :collect_delivery,
        :expires_at,
        :note,
        :created_by_user_id
      ])

      change(Emakola.Orders.Changes.GeneratePayLinkCode)

      # Custom deals go stale: default 7-day expiry when none given.
      change(fn changeset, _ctx ->
        type = Ash.Changeset.get_attribute(changeset, :type)
        expires = Ash.Changeset.get_attribute(changeset, :expires_at)

        if type == :custom and is_nil(expires) do
          Ash.Changeset.force_change_attribute(
            changeset,
            :expires_at,
            DateTime.add(DateTime.utc_now(), 7, :day)
          )
        else
          changeset
        end
      end)
    end

    # No store context here by design — a buyer opens `/pay/:code` before
    # anything is known about which store it belongs to. `get?(true)` relies
    # on `code` being unique across every tenant (see the `all_tenants?: true`
    # identity above); without that, two stores minting the same code would
    # make this raise "expected at most one result" instead of resolving.
    read :get_by_code do
      get?(true)
      argument(:code, :string, allow_nil?: false)
      filter(expr(code == ^arg(:code)))
    end

    update :cancel do
      accept([])
      validate(attribute_in(:status, [:active]))
      change(set_attribute(:status, :cancelled))
    end

    update :mark_paid do
      accept([:claimed_order_id])
      validate(attribute_in(:status, [:active]))
      change(set_attribute(:status, :paid))
    end

    update :increment_opened do
      accept([])
      change(atomic_update(:opened_count, expr(opened_count + 1)))
    end
  end

  @doc "Is this link still payable? Checks status, then expiry."
  def usable?(%__MODULE__{status: :cancelled}), do: {:error, :cancelled}
  def usable?(%__MODULE__{status: :paid}), do: {:error, :consumed}

  def usable?(%__MODULE__{expires_at: %DateTime{} = at}) do
    if DateTime.compare(at, DateTime.utc_now()) == :lt, do: {:error, :expired}, else: :ok
  end

  def usable?(%__MODULE__{}), do: :ok
end
