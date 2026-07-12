defmodule Emakola.Customers.NewsletterSubscriberTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  require Ash.Query

  alias Emakola.Customers.NewsletterSubscriber

  setup do
    {:ok, store: create_store!()}
  end

  defp subscribe(store, email) do
    Emakola.Customers.subscribe_to_newsletter(
      %{email: email, store_id: store.id},
      authorize?: false
    )
  end

  defp subscribers_for(store) do
    NewsletterSubscriber
    |> Ash.Query.filter(store_id == ^store.id)
    |> Ash.read!(authorize?: false)
  end

  describe "subscribe" do
    test "persists a subscriber scoped to the store", %{store: store} do
      assert {:ok, subscriber} = subscribe(store, "ama@example.com")

      assert subscriber.store_id == store.id
      assert Ash.CiString.value(subscriber.email) == "ama@example.com"
      assert %DateTime{} = subscriber.subscribed_at
    end

    test "re-subscribing the same email is idempotent", %{store: store} do
      assert {:ok, first} = subscribe(store, "repeat@example.com")
      assert {:ok, second} = subscribe(store, "repeat@example.com")

      assert first.id == second.id
      assert length(subscribers_for(store)) == 1
    end

    test "re-subscribing with a different casing is idempotent", %{store: store} do
      assert {:ok, first} = subscribe(store, "case@example.com")
      assert {:ok, second} = subscribe(store, "CASE@EXAMPLE.COM")

      assert first.id == second.id
      assert length(subscribers_for(store)) == 1
    end

    test "the same email can subscribe to two different stores", %{store: store} do
      other_store = create_store!()

      assert {:ok, sub_a} = subscribe(store, "shared@example.com")
      assert {:ok, sub_b} = subscribe(other_store, "shared@example.com")

      assert sub_a.store_id == store.id
      assert sub_b.store_id == other_store.id
      assert length(subscribers_for(store)) == 1
      assert length(subscribers_for(other_store)) == 1
    end

    test "rejects an invalid email format", %{store: store} do
      assert {:error, %Ash.Error.Invalid{}} = subscribe(store, "not-an-email")
      assert subscribers_for(store) == []
    end

    test "rejects a blank email", %{store: store} do
      assert {:error, %Ash.Error.Invalid{}} = subscribe(store, "")
      assert subscribers_for(store) == []
    end
  end
end
