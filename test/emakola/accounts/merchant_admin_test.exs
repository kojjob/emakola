defmodule Emakola.Accounts.MerchantAdminTest do
  use Emakola.DataCase, async: true

  alias Emakola.Accounts
  alias Emakola.Factory

  describe "list_merchants_for_admin/1" do
    test "returns all merchants when search is blank" do
      Factory.create_merchant!(%{name: "Ama Mensah", email: "ama@example.com"})
      Factory.create_merchant!(%{name: "Kofi Boateng", email: "kofi@example.com"})

      assert {:ok, merchants} = Accounts.list_merchants_for_admin("", authorize?: false)
      assert length(merchants) == 2
    end

    test "filters by name (case-insensitive)" do
      Factory.create_merchant!(%{name: "Ama Mensah", email: "ama@example.com"})
      Factory.create_merchant!(%{name: "Kofi Boateng", email: "kofi@example.com"})

      assert {:ok, [m]} = Accounts.list_merchants_for_admin("%ama%", authorize?: false)
      assert m.name == "Ama Mensah"
    end

    test "filters by email" do
      Factory.create_merchant!(%{name: "Ama", email: "ama@example.com"})
      Factory.create_merchant!(%{name: "Kofi", email: "kofi@example.com"})

      assert {:ok, [m]} = Accounts.list_merchants_for_admin("%kofi@%", authorize?: false)
      assert to_string(m.email) == "kofi@example.com"
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
