defmodule Emakola.Customers.CustomerIdentityTest do
  @moduledoc """
  Customer social identities are per-store.

  A merchant identity is globally unique on `(strategy, uid)` — one person, one
  Makola merchant account (GHSA-777c-2fxx-qr28). A *shopper* is the opposite: the
  same Google account is a different customer at every shop they buy from, so the
  identity has to be unique per store, not platform-wide.

  Ash gives us that: an identity on a multitenant resource defaults to
  `all_tenants?: false`, so `(uid, strategy)` becomes `(store_id, uid, strategy)`
  in the index. That is what makes the extension usable here at all.
  """
  use Emakola.DataCase, async: true

  require Ash.Query

  alias Emakola.Customers.Customer

  defp register_oauth(email, store_id, uid) do
    Customer
    |> Ash.Changeset.for_create(
      :register_with_oauth2,
      %{
        user_info: %{"email" => email, "name" => "Ama", "sub" => uid},
        oauth_tokens: %{"access_token" => "tok"}
      },
      tenant: store_id
    )
    |> Ash.create(authorize?: false)
  end

  test "the same social account shops at two different stores" do
    {_m1, store_a} = Emakola.Factory.create_merchant_with_store!()
    {_m2, store_b} = Emakola.Factory.create_merchant_with_store!()

    assert {:ok, at_a} = register_oauth("ama@example.com", store_a.id, "google-ama")
    assert {:ok, at_b} = register_oauth("ama@example.com", store_b.id, "google-ama")

    # Two separate customers — one per shop — not a collision.
    refute at_a.id == at_b.id
    assert at_a.store_id == store_a.id
    assert at_b.store_id == store_b.id
  end

  test "the identity row is scoped to its store" do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()

    assert {:ok, customer} = register_oauth("kofi@example.com", store.id, "google-kofi")

    identities =
      Emakola.Customers.CustomerIdentity
      |> Ash.Query.filter(user_id: customer.id)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert [identity] = identities
    assert identity.store_id == store.id
    assert identity.uid == "google-kofi"

    # `strategy` is not asserted: :register_with_oauth2 is shared by all three
    # providers and the name comes from the strategy context a real request
    # carries, which a direct Ash.create/1 does not. What matters here is that
    # the row exists and is scoped to this store.
    assert identity.strategy in ~w(google facebook apple)
  end
end
