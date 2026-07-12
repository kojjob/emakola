defmodule EmakolaWeb.Hooks.NewsletterSubscriptionTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  require Ash.Query

  alias Emakola.Customers.NewsletterSubscriber
  alias Emakola.Factory

  defp subscribers_for(store) do
    NewsletterSubscriber
    |> Ash.Query.filter(store_id == ^store.id)
    |> Ash.read!(authorize?: false)
  end

  describe "subscribe_newsletter on the storefront home page" do
    test "persists a subscriber scoped to the store and confirms", %{conn: conn} do
      store = Factory.create_store!()
      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      html = render_submit(view, "subscribe_newsletter", %{"email" => "ama@example.com"})

      assert html =~ "Thanks for subscribing"
      assert [subscriber] = subscribers_for(store)
      assert subscriber.store_id == store.id
      assert Ash.CiString.value(subscriber.email) == "ama@example.com"
    end

    test "re-submitting the same email is idempotent and still confirms", %{conn: conn} do
      store = Factory.create_store!()
      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      render_submit(view, "subscribe_newsletter", %{"email" => "repeat@example.com"})
      html = render_submit(view, "subscribe_newsletter", %{"email" => "repeat@example.com"})

      assert html =~ "Thanks for subscribing"
      refute html =~ "valid email"
      assert length(subscribers_for(store)) == 1
    end

    test "an invalid email flashes a friendly error and does not crash", %{conn: conn} do
      store = Factory.create_store!()
      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      html = render_submit(view, "subscribe_newsletter", %{"email" => "not-an-email"})

      assert html =~ "valid email"
      assert subscribers_for(store) == []
      assert Process.alive?(view.pid)
    end

    test "malformed or crafted payloads do not crash the LiveView", %{conn: conn} do
      store = Factory.create_store!()
      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      render_submit(view, "subscribe_newsletter", %{})
      render_submit(view, "subscribe_newsletter", %{"email" => %{"nested" => "x"}})
      render_submit(view, "subscribe_newsletter", %{"email" => ["a@example.com"]})
      render_submit(view, "subscribe_newsletter", %{"other" => "value"})

      assert Process.alive?(view.pid)
      assert subscribers_for(store) == []
    end
  end

  describe "footer newsletter form (reachable beyond the home page)" do
    test "subscribes from a Bold store's cart page footer", %{conn: conn} do
      store = Factory.create_store!(%{theme_config: %{"theme" => "bold"}})
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/cart")

      html =
        view
        |> form("form[phx-submit=subscribe_newsletter]", %{"email" => "footer@example.com"})
        |> render_submit()

      assert html =~ "Thanks for subscribing"
      assert [subscriber] = subscribers_for(store)
      assert Ash.CiString.value(subscriber.email) == "footer@example.com"
    end
  end

  describe "tenant isolation" do
    test "the subscriber lands on the store being browsed, not another store", %{conn: conn} do
      store_a = Factory.create_store!()
      store_b = Factory.create_store!()

      {:ok, view, _html} = live(conn, "/s/#{store_a.slug}")

      # A crafted payload must not be able to target another store.
      render_submit(view, "subscribe_newsletter", %{
        "email" => "isolated@example.com",
        "store_id" => store_b.id
      })

      assert [subscriber] = subscribers_for(store_a)
      assert subscriber.store_id == store_a.id
      assert subscribers_for(store_b) == []
    end
  end
end
