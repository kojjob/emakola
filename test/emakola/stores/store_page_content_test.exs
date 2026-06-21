defmodule Emakola.Stores.StorePageContentTest do
  @moduledoc """
  Per-store editable prose for the storefront informational pages (About,
  Contact, FAQ, Policies). One row per store, kept off the publicly-readable
  Store resource so writes stay merchant-only — same split as StorePayoutAccount.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Stores.PageContent
  alias Emakola.Stores.StorePageContent

  setup do
    {:ok, store: create_store!()}
  end

  defp create_content!(store, attrs \\ %{}) do
    params = Map.merge(%{store_id: store.id}, Map.new(attrs))

    StorePageContent
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create!(authorize?: false)
  end

  describe "create" do
    test "defaults the list fields to empty and leaves text nil", %{store: store} do
      content = create_content!(store)

      assert content.store_id == store.id
      assert content.about_steps == []
      assert content.about_values == []
      assert content.faq_items == []
      assert is_nil(content.about_headline)
      assert is_nil(content.shipping_returns)
    end

    test "allows only one content row per store", %{store: store} do
      create_content!(store)

      assert {:error, _} =
               StorePageContent
               |> Ash.Changeset.for_create(:create, %{store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "rejects an over-long about headline", %{store: store} do
      assert {:error, _} =
               StorePageContent
               |> Ash.Changeset.for_create(:create, %{
                 store_id: store.id,
                 about_headline: String.duplicate("a", 201)
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "update" do
    test "persists about, faq, policy and contact fields", %{store: store} do
      content = create_content!(store)

      {:ok, updated} =
        content
        |> Ash.Changeset.for_update(:update, %{
          about_headline: "About Adwoa's Kitchen",
          about_intro: "Home-cooked Ghanaian meals.",
          about_story: "We started in 2020.\n\nNow we serve the whole city.",
          about_steps: [%{"number" => "01", "title" => "Browse", "description" => "Pick a dish"}],
          about_values: [%{"title" => "Freshness", "description" => "Cooked daily"}],
          about_cta_heading: "Hungry?",
          about_cta_text: "Order now.",
          faq_items: [%{"question" => "Do you deliver?", "answer" => "Yes, citywide."}],
          shipping_returns: "We deliver within 2 days.",
          privacy_policy: "We keep your data safe.",
          terms_of_service: "Be nice.",
          contact_note: "Reach us anytime.",
          contact_hours: "Mon-Sat 9-6"
        })
        |> Ash.update(authorize?: false)

      assert updated.about_headline == "About Adwoa's Kitchen"
      assert updated.about_story =~ "whole city"

      assert updated.about_steps == [
               %{"number" => "01", "title" => "Browse", "description" => "Pick a dish"}
             ]

      assert updated.about_values == [%{"title" => "Freshness", "description" => "Cooked daily"}]

      assert updated.faq_items == [
               %{"question" => "Do you deliver?", "answer" => "Yes, citywide."}
             ]

      assert updated.shipping_returns == "We deliver within 2 days."
      assert updated.contact_hours == "Mon-Sat 9-6"
    end
  end

  describe "get_by_store" do
    test "fetches the content row for a store", %{store: store} do
      create_content!(store, %{about_headline: "Hello"})

      {:ok, content} =
        StorePageContent
        |> Ash.Query.for_read(:get_by_store, %{store_id: store.id})
        |> Ash.read_one(authorize?: false)

      assert content.about_headline == "Hello"
    end

    test "returns nil when the store has no content row", %{store: store} do
      {:ok, content} =
        StorePageContent
        |> Ash.Query.for_read(:get_by_store, %{store_id: store.id})
        |> Ash.read_one(authorize?: false)

      assert is_nil(content)
    end
  end

  describe "PageContent.get_or_create/2" do
    test "creates a row when the store has none", %{store: store} do
      assert {:ok, content} = PageContent.get_or_create(store.id, authorize?: false)
      assert content.store_id == store.id
      assert count_rows(store.id) == 1
    end

    test "returns the existing row without creating a duplicate", %{store: store} do
      existing = create_content!(store, %{about_headline: "Existing"})

      assert {:ok, content} = PageContent.get_or_create(store.id, authorize?: false)
      assert content.id == existing.id
      assert count_rows(store.id) == 1
    end
  end

  describe "multitenant isolation" do
    test "a store's content is never returned for another store" do
      store_a = create_store!()
      store_b = create_store!()
      create_content!(store_a, %{about_headline: "A only"})

      {:ok, fetched_b} =
        StorePageContent
        |> Ash.Query.for_read(:get_by_store, %{store_id: store_b.id})
        |> Ash.read_one(authorize?: false)

      assert is_nil(fetched_b)
    end
  end

  describe "policies" do
    test "a merchant with store access may update its content" do
      {merchant, store} = create_merchant_with_store!()
      content = create_content!(store)

      assert {:ok, _} =
               Emakola.Stores.update_page_content(content, %{about_headline: "Mine"},
                 actor: merchant
               )
    end

    test "a merchant without store access may not update the content" do
      {_owner, store} = create_merchant_with_store!()
      outsider = create_merchant!()
      content = create_content!(store)

      assert {:error, _} =
               Emakola.Stores.update_page_content(content, %{about_headline: "Hijack"},
                 actor: outsider
               )
    end
  end

  defp count_rows(store_id) do
    StorePageContent
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(store_id == ^store_id)
    |> Ash.read!(authorize?: false)
    |> length()
  end
end
