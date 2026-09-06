defmodule Emakola.Analytics.StoreVisit do
  @moduledoc """
  One row per storefront visit, so a merchant can be told how many people came
  and not merely how many bought.

  Reports carried a conversion rate and a sales-by-channel breakdown that were
  invented, and both were removed rather than faked
  (`EmakolaWeb.Admin.ReportLive.Index`). Neither could come back, because
  nothing counted traffic. This is the missing denominator.

  ## What is stored, and what deliberately is not

  A visit records the store, the moment, the source, and a **hash of the
  `cart_session_id` the app already sets** for every request
  (`EmakolaWeb.Plugs.CartSession`). That gives honest unique-visitor counts
  while collecting nothing new: the id existed already, it is stored hashed, it
  identifies nobody outside this app, and it dies with the cookie.

  No IP address. No user-agent fingerprint. Both would identify people who never
  opted into anything, and in several of the markets this platform serves that
  is personal data whether it is hashed or not. Counting visitors does not
  require knowing who they are.

  ## Why the source is a small closed set

  `source` is derived from the referrer and UTM tags into a handful of known
  channels, not stored raw. A raw referrer is a URL, and URLs carry query
  strings that people put surprising things in.
  """

  use Ash.Resource,
    domain: Emakola.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("store_visits")
    repo(Emakola.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:store_id, :uuid, allow_nil?: false, public?: true)

    # SHA-256 of the cart_session_id. Hashed so a database read cannot be used
    # to hijack the cart it came from.
    attribute(:visitor_hash, :string, allow_nil?: false, public?: true)

    attribute :source, :atom do
      allow_nil?(false)
      default(:direct)
      public?(true)

      constraints(
        one_of: [
          :direct,
          :search,
          :instagram,
          :tiktok,
          :whatsapp,
          :facebook,
          :x,
          :qr,
          :other
        ]
      )
    end

    attribute(:occurred_at, :utc_datetime_usec, allow_nil?: false, public?: true)

    attribute :page, :atom do
      allow_nil?(false)
      default(:home)
      public?(true)
      constraints(one_of: [:home, :product, :pay_link])
    end

    attribute(:product_id, :uuid, allow_nil?: true, public?: true)

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :record do
      accept([:store_id, :visitor_hash, :source, :occurred_at, :page, :product_id])
    end
  end
end
