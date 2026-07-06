defmodule Emakola.Accounts.MerchantAdminTest do
  use Emakola.DataCase, async: true

  alias Emakola.Accounts
  alias Emakola.Factory

  describe "list_merchants_for_admin/1" do
    # list_merchants_for_admin is a GLOBAL read (merchants aren't store-scoped),
    # so these tests use unique tokens and assert on the merchants they created
    # rather than exact totals — a concurrent async test's merchants would
    # otherwise leak into the result and flake the assertion.

    test "returns all merchants when search is blank" do
      t = System.unique_integer([:positive])
      m1 = Factory.create_merchant!(%{name: "Ama Mensah", email: "ama-#{t}@example.com"})
      m2 = Factory.create_merchant!(%{name: "Kofi Boateng", email: "kofi-#{t}@example.com"})

      assert {:ok, merchants} = Accounts.list_merchants_for_admin("", authorize?: false)
      ids = Enum.map(merchants, & &1.id)
      assert m1.id in ids
      assert m2.id in ids
    end

    test "filters by name (case-insensitive)" do
      t = System.unique_integer([:positive])
      ama = Factory.create_merchant!(%{name: "Ama#{t} Mensah", email: "ama-#{t}@example.com"})
      _kofi = Factory.create_merchant!(%{name: "Kofi#{t}", email: "kofi-#{t}@example.com"})

      assert {:ok, results} = Accounts.list_merchants_for_admin("%ama#{t}%", authorize?: false)
      assert Enum.map(results, & &1.id) == [ama.id]
    end

    test "filters by email" do
      t = System.unique_integer([:positive])
      _ama = Factory.create_merchant!(%{name: "Ama", email: "ama-#{t}@example.com"})
      kofi = Factory.create_merchant!(%{name: "Kofi", email: "kofi-#{t}@example.com"})

      assert {:ok, results} = Accounts.list_merchants_for_admin("%kofi-#{t}@%", authorize?: false)
      assert Enum.map(results, & &1.id) == [kofi.id]
    end

    test "loads stores association" do
      {merchant, _store} = Factory.create_merchant_with_store!()
      {:ok, merchants} = Accounts.list_merchants_for_admin("", authorize?: false)
      found = Enum.find(merchants, &(&1.id == merchant.id))
      assert length(found.stores) == 1
    end
  end

  describe "create_merchant! factory enhancement" do
    test "applies name/business/phone and confirmed_at when given" do
      ts = DateTime.utc_now()

      m =
        Factory.create_merchant!(%{
          name: "Ama",
          business_name: "Ama Foods",
          phone: "0244",
          confirmed_at: ts
        })

      assert m.name == "Ama"
      assert m.business_name == "Ama Foods"
      assert m.phone == "0244"
      refute is_nil(m.confirmed_at)
    end
  end

  describe "get_merchant/1" do
    test "returns merchant by id" do
      merchant = Factory.create_merchant!()
      assert {:ok, found} = Accounts.get_merchant(merchant.id, authorize?: false)
      assert found.id == merchant.id
    end

    test "returns error for unknown id" do
      assert {:error, _} = Accounts.get_merchant(Ecto.UUID.generate(), authorize?: false)
    end
  end
end
