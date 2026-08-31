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

  describe "page_merchants_for_admin/3" do
    # Paging, filtering and sorting all happen in the database now — the
    # platform queue used to pull every merchant on the platform into memory
    # and slice it there.

    test "returns one page at a time with the full count beside it" do
      t = System.unique_integer([:positive])

      for i <- 1..3 do
        Factory.create_merchant!(%{
          name: "Paged#{t} #{i}",
          email: "paged-#{t}-#{i}@example.com"
        })
      end

      assert {:ok, page} =
               Accounts.page_merchants_for_admin("%Paged#{t}%", :all,
                 page: [limit: 2, offset: 0, count: true],
                 authorize?: false
               )

      assert length(page.results) == 2
      assert page.count == 3

      assert {:ok, second} =
               Accounts.page_merchants_for_admin("%Paged#{t}%", :all,
                 page: [limit: 2, offset: 2, count: true],
                 authorize?: false
               )

      assert length(second.results) == 1
    end

    test "filters confirmed and unconfirmed in the query" do
      t = System.unique_integer([:positive])

      confirmed =
        Factory.create_merchant!(%{
          name: "Conf#{t}",
          email: "conf-#{t}@example.com",
          confirmed_at: DateTime.utc_now()
        })

      pending =
        Factory.create_merchant!(%{
          name: "Pend#{t}",
          email: "pend-#{t}@example.com",
          confirmed_at: nil
        })

      assert {:ok, %{results: [only]}} =
               Accounts.page_merchants_for_admin("%#{t}%", :confirmed,
                 page: [limit: 10, count: true],
                 authorize?: false
               )

      assert only.id == confirmed.id

      assert {:ok, %{results: [other]}} =
               Accounts.page_merchants_for_admin("%#{t}%", :unconfirmed,
                 page: [limit: 10, count: true],
                 authorize?: false
               )

      assert other.id == pending.id
    end

    test "sorts by store count in the database" do
      t = System.unique_integer([:positive])
      {with_store, _store} = Factory.create_merchant_with_store!()

      with_store =
        Ash.update!(
          Ash.Changeset.for_update(with_store, :update_profile, %{name: "Stocked#{t}"}),
          authorize?: false
        )

      Factory.create_merchant!(%{name: "Barren#{t}", email: "barren-#{t}@example.com"})

      assert {:ok, %{results: [first | _]}} =
               Accounts.page_merchants_for_admin("%#{t}%", :all,
                 query: [sort: [stores_count: :desc]],
                 page: [limit: 10, count: true],
                 authorize?: false
               )

      assert first.id == with_store.id
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
