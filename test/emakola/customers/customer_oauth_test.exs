defmodule Emakola.Customers.CustomerOAuthTest do
  @moduledoc """
  Verifies the multitenant core of storefront social login: register_with_oauth2
  resolves the store from the request tenant and upserts the per-store customer
  by :unique_store_email (no shared identity table). This is the load-bearing
  assumption behind SP3 — that customer OAuth stays correctly store-scoped.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Customers.Customer

  defp register_oauth(email, store_id, name \\ "Ama") do
    Customer
    |> Ash.Changeset.for_create(
      :register_with_oauth2,
      %{
        user_info: %{"email" => email, "name" => name},
        oauth_tokens: %{"access_token" => "tok"}
      },
      tenant: store_id
    )
    |> Ash.create(authorize?: false)
  end

  test "creates a customer scoped to the request tenant (store)" do
    {_merchant, store} = Emakola.Factory.create_merchant_with_store!()

    {:ok, customer} = register_oauth("shopper@example.com", store.id)

    assert to_string(customer.email) == "shopper@example.com"
    assert customer.store_id == store.id
    assert customer.name == "Ama"
  end

  test "the same email registers as separate customers in different stores" do
    {_m1, store_a} = Emakola.Factory.create_merchant_with_store!()
    {_m2, store_b} = Emakola.Factory.create_merchant_with_store!()

    {:ok, customer_a} = register_oauth("dup@example.com", store_a.id)
    {:ok, customer_b} = register_oauth("dup@example.com", store_b.id)

    assert customer_a.id != customer_b.id
    assert customer_a.store_id == store_a.id
    assert customer_b.store_id == store_b.id
  end

  test "re-registering the same email in the same store upserts (no duplicate)" do
    {_merchant, store} = Emakola.Factory.create_merchant_with_store!()

    {:ok, first} = register_oauth("repeat@example.com", store.id)
    {:ok, second} = register_oauth("repeat@example.com", store.id)

    assert first.id == second.id

    matching =
      Customer
      |> Ash.read!(tenant: store.id, authorize?: false)
      |> Enum.filter(&(to_string(&1.email) == "repeat@example.com"))

    assert length(matching) == 1
  end
end
