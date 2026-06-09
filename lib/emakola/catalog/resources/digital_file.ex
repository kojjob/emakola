defmodule Emakola.Catalog.DigitalFile do
  @moduledoc """
  Downloadable file attached to a product. Used by:

    * **digital_download / license_key / streaming / course** products —
      buyers receive a download grant for each non-preview file when their
      order is fulfilled.
    * **any product type, including `:physical`** — files with
      `is_preview: true` are publicly accessible samples (look books,
      demo PDFs, sample chapters) shown on the storefront before purchase.

  `byte_size` is bigint at the database layer: digital downloads can
  legitimately reach multi-GB (videos, software packages, design bundles).

  Storage objects live in S3-compatible storage; `storage_key` is the
  opaque path/key into the storage backend. Once a row is written, the
  `storage_key` is treated as immutable — re-uploading produces a new row.

  Multi-tenancy: `store_id` scoping, same pattern as every other catalog
  resource. The unique index on `(store_id, storage_key)` lets two
  different stores share an identical key string without collision.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("digital_files")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :store_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :product_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :file_name, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 500)
    end

    attribute :storage_key, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 1_024)
    end

    attribute :content_type, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :byte_size, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1)
    end

    attribute :position, :integer do
      default(0)
      allow_nil?(false)
      public?(true)
    end

    attribute :is_preview, :boolean do
      default(false)
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :product, Emakola.Catalog.Product do
      define_attribute?(false)
      public?(true)
    end

    belongs_to :store, Emakola.Stores.Store do
      define_attribute?(false)
      public?(true)
    end
  end

  identities do
    identity(:unique_storage_key_per_store, [:store_id, :storage_key])
  end

  policies do
    # Internal/system calls (nil actor) are allowed
    bypass always() do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :store_id,
        :product_id,
        :file_name,
        :storage_key,
        :content_type,
        :byte_size,
        :position,
        :is_preview
      ])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :file_name})
      validate({Emakola.Catalog.Validations.NotBlank, attribute: :storage_key})
    end

    update :update do
      require_atomic?(false)
      # storage_key intentionally absent — once uploaded, the row's
      # storage_key is immutable. Re-uploading produces a new row.
      accept([:file_name, :position, :is_preview])

      validate({Emakola.Catalog.Validations.NotBlank, attribute: :file_name})
    end
  end
end
