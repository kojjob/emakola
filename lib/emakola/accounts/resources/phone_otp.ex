defmodule Emakola.Accounts.PhoneOtp do
  @moduledoc """
  One-time codes issued for phone (WhatsApp/SMS) authentication. Codes are
  stored hashed; rows are short-lived (expiry), single-use (consumed_at), and
  attempt-capped. `purpose` distinguishes merchant vs customer; `store_id` is
  set for the (store-scoped) customer flow.
  """
  use Ash.Resource, domain: Emakola.Accounts, data_layer: AshPostgres.DataLayer

  postgres do
    table("phone_otps")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:phone, :string, allow_nil?: false, public?: false)
    attribute(:code_hash, :string, allow_nil?: false, sensitive?: true, public?: false)

    attribute(:purpose, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:merchant, :customer]]
    )

    attribute(:store_id, :uuid, public?: false)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: false, public?: false)
    attribute(:attempts, :integer, allow_nil?: false, default: 0, public?: false)
    attribute(:consumed_at, :utc_datetime_usec, public?: false)
    timestamps()
  end

  actions do
    defaults([:read])

    create :issue do
      accept([:phone, :code_hash, :purpose, :store_id, :expires_at])
    end

    update :record_attempt do
      require_atomic?(true)
      change(atomic_update(:attempts, expr(attempts + 1)))
    end

    update :consume do
      accept([])
      change(set_attribute(:consumed_at, &DateTime.utc_now/0))
    end

    read :live_for_phone do
      argument(:phone, :string, allow_nil?: false)
      argument(:purpose, :atom, allow_nil?: false)
      filter(expr(phone == ^arg(:phone) and purpose == ^arg(:purpose) and is_nil(consumed_at)))
      prepare(build(sort: [inserted_at: :desc], limit: 1))
    end
  end
end
