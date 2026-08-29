defmodule Emakola.Catalog.Image do
  @moduledoc """
  Image resource — product and variant images for storefronts.

  Images are uploaded to S3-compatible storage and processed asynchronously
  by the ImageProcessorWorker to generate thumbnail and medium variants.

  All monetary/size values are integers. file_size_bytes is the raw byte count.
  content_type is validated to only allow image formats.

  Multi-tenancy: store_id scoping, same pattern as other catalog resources.
  """

  use Ash.Resource,
    domain: Emakola.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type("image")
  end

  multitenancy do
    strategy(:attribute)
    attribute(:store_id)
    global?(true)
  end

  postgres do
    table("images")
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

    attribute :variant_id, :uuid do
      public?(true)
    end

    attribute :url, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 2_048)
    end

    attribute :thumbnail_url, :string do
      public?(true)
      constraints(max_length: 2_048)
    end

    attribute :medium_url, :string do
      public?(true)
      constraints(max_length: 2_048)
    end

    attribute :alt_text, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :position, :integer do
      default(0)
      public?(true)
    end

    attribute :content_type, :string do
      allow_nil?(false)
      public?(true)
      constraints(max_length: 255)
    end

    attribute :file_size_bytes, :integer do
      public?(true)
    end

    attribute :processing_status, :atom do
      constraints(one_of: [:pending, :completed, :failed])
      default(:pending)
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

  policies do
    # Reads are public — storefront renders images without an actor.
    bypass action_type(:read) do
      authorize_unless(actor_present())
    end

    # Merchant actors: verify store membership for writes
    policy actor_attribute_equals(:__struct__, Emakola.Accounts.Merchant) do
      authorize_if(Emakola.Policies.Checks.ActorHasStoreAccess)
    end
  end

  actions do
    defaults([:read])

    destroy :destroy do
      primary?(true)
      # DeleteImageFiles enqueues object-storage cleanup (a side effect), so the
      # destroy can't run atomically — opt out of the atomic requirement.
      require_atomic?(false)
      # Enqueue object-storage cleanup so the deleted row's files aren't orphaned.
      change(Emakola.Catalog.Changes.DeleteImageFiles)
      # A removed image can uncover a different one at position 0 — revoke.
      change(Emakola.Catalog.Changes.RevokeSnapVerified)
    end

    create :create do
      accept([
        :url,
        :alt_text,
        :content_type,
        :file_size_bytes,
        :product_id,
        :variant_id,
        :store_id
      ])

      validate(
        {Emakola.Catalog.Validations.OneOf,
         attribute: :content_type, values: ["image/jpeg", "image/png", "image/webp"]}
      )

      validate(
        {Emakola.Catalog.Validations.MaxValue, attribute: :file_size_bytes, max: 10_000_000}
      )

      # A new image can take position 0 — revoke.
      change(Emakola.Catalog.Changes.RevokeSnapVerified)

      # Kick off webp variant generation. after_transaction, not
      # after_action: the job row must not sit inside the image's own
      # transaction, and a queue failure must not roll back the upload.
      change(
        after_transaction(fn
          _changeset, {:ok, image}, _context ->
            Emakola.Workers.ImageProcessorWorker.enqueue(image.id)
            {:ok, image}

          _changeset, error, _context ->
            error
        end)
      )
    end

    update :update do
      require_atomic?(false)
      accept([:alt_text, :position])
      # Reordering (a :position change) revokes; alt_text-only edits — e.g.
      # the AI alt-text backfill worker — must not.
      change({Emakola.Catalog.Changes.RevokeSnapVerified, only_if_changing: :position})
    end

    update :mark_processed do
      require_atomic?(false)
      accept([:thumbnail_url, :medium_url])

      # Badge-safety invariant (snap-verified "Real photo" badge): the
      # thumbnail/medium URLs written here must stay derived from this same
      # image's own immutable :url (currently enforced by worker discipline —
      # ImageProcessorWorker computes them deterministically from image.url,
      # nothing external is ever accepted). If this action is ever changed to
      # accept externally-supplied URLs, it must also fire
      # Emakola.Catalog.Changes.RevokeSnapVerified — otherwise a merchant
      # could swap a verified product's rendered photo without losing the
      # badge.
      change(set_attribute(:processing_status, :completed))
    end

    update :mark_failed do
      require_atomic?(false)
      accept([])

      change(set_attribute(:processing_status, :failed))
    end
  end
end
