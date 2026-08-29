defmodule Emakola.Analytics.StoreVisitsTest do
  @moduledoc """
  Counting storefront traffic.

  The point of this is a denominator: reports lost their conversion rate and
  their sales-by-channel breakdown because nothing measured visits, and both
  were removed rather than invented. These tests pin down what "a visit" and
  "a visitor" mean, since a conversion rate is only as honest as those two.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Analytics.StoreVisits

  setup do
    store = Emakola.Factory.create_store!()
    {:ok, store: store}
  end

  describe "recording" do
    test "a visit is counted", %{store: store} do
      assert {:ok, _} = StoreVisits.record(store.id, "session-a", %{})

      assert StoreVisits.visits(store.id, 30) == 1
    end

    test "the session id is never stored in the clear", %{store: store} do
      {:ok, visit} = StoreVisits.record(store.id, "session-a", %{})

      # It is the key to that browser's cart. A database read must not hand it
      # over.
      refute visit.visitor_hash == "session-a"
      assert byte_size(visit.visitor_hash) == 64
    end

    test "one person browsing five pages is one visitor, not five", %{store: store} do
      for _ <- 1..5, do: StoreVisits.record(store.id, "session-a", %{})

      # This is the whole reason a visitor identity exists. Counting pageviews
      # here would inflate the denominator and quietly understate every
      # merchant's conversion rate.
      assert StoreVisits.visits(store.id, 30) == 5
      assert StoreVisits.visitors(store.id, 30) == 1
    end

    test "different people are different visitors", %{store: store} do
      StoreVisits.record(store.id, "session-a", %{})
      StoreVisits.record(store.id, "session-b", %{})

      assert StoreVisits.visitors(store.id, 30) == 2
    end

    test "one store's traffic is not another's", %{store: store} do
      other = Emakola.Factory.create_store!()
      StoreVisits.record(other.id, "session-a", %{})

      assert StoreVisits.visitors(store.id, 30) == 0
      assert StoreVisits.visitors(other.id, 30) == 1
    end
  end

  describe "where a visit came from" do
    test "a bare visit is direct", %{store: store} do
      {:ok, visit} = StoreVisits.record(store.id, "s", %{})
      assert visit.source == :direct
    end

    test "utm_source wins, since it is the explicit claim", %{store: store} do
      {:ok, visit} =
        StoreVisits.record(store.id, "s", %{
          "utm_source" => "instagram",
          "referrer" => "https://www.google.com/"
        })

      assert visit.source == :instagram
    end

    test "a referrer is read when there is no utm tag", %{store: store} do
      {:ok, v} = StoreVisits.record(store.id, "s", %{"referrer" => "https://l.instagram.com/x"})
      assert v.source == :instagram
    end

    test "search engines collapse to :search", %{store: store} do
      {:ok, v} = StoreVisits.record(store.id, "s", %{"referrer" => "https://www.google.com/"})
      assert v.source == :search
    end

    test "an unrecognised source is :other, never stored raw", %{store: store} do
      {:ok, v} = StoreVisits.record(store.id, "s", %{"referrer" => "https://weird.example/?q=hi"})

      # A raw referrer is a URL, and URLs carry query strings people put
      # surprising things in. Only the bucket is kept.
      assert v.source == :other
    end

    test "a scanned QR is its own channel", %{store: store} do
      {:ok, v} = StoreVisits.record(store.id, "s", %{"utm_source" => "qr"})
      assert v.source == :qr
    end

    test "a hostile utm_source cannot invent a channel", %{store: store} do
      # Guards against atom exhaustion and against a crafted link writing
      # arbitrary values into a merchant's report.
      {:ok, v} = StoreVisits.record(store.id, "s", %{"utm_source" => "<script>alert(1)</script>"})
      assert v.source == :other
    end
  end

  describe "windows" do
    test "only visits inside the window count", %{store: store} do
      {:ok, recent} = StoreVisits.record(store.id, "s1", %{})
      {:ok, old} = StoreVisits.record(store.id, "s2", %{})
      backdate!(old, 40)

      assert StoreVisits.visits(store.id, 30) == 1
      assert StoreVisits.visits(store.id, 90) == 2
      _ = recent
    end
  end

  describe "by channel" do
    test "traffic is grouped by where it came from", %{store: store} do
      StoreVisits.record(store.id, "a", %{"utm_source" => "instagram"})
      StoreVisits.record(store.id, "b", %{"utm_source" => "instagram"})
      StoreVisits.record(store.id, "c", %{})

      counts = StoreVisits.by_source(store.id, 30)

      assert counts[:instagram] == 2
      assert counts[:direct] == 1
    end
  end

  defp backdate!(visit, days_ago) do
    Emakola.Repo.update_all(
      from(v in "store_visits", where: v.id == ^Ecto.UUID.dump!(visit.id)),
      set: [occurred_at: DateTime.add(DateTime.utc_now(), -days_ago * 86_400, :second)]
    )
  end

  import Ecto.Query, only: [from: 2]

  describe "most_visited/2" do
    test "ranks stores by distinct people, not page views" do
      [busy, popular] = [create_store!(), create_store!()]

      # One obsessive visitor on `busy`: five page views, one person.
      for _ <- 1..5, do: StoreVisits.record(busy.id, "one-session", %{})
      # Three different people on `popular`: three page views, three people.
      for n <- 1..3, do: StoreVisits.record(popular.id, "session-#{n}", %{})

      assert [first | _] = StoreVisits.most_visited(7, 10)
      assert first == popular.id
    end

    test "ignores visits outside the window" do
      store = create_store!()
      StoreVisits.record(store.id, "recent", %{})

      assert store.id in StoreVisits.most_visited(7, 10)
      refute store.id in StoreVisits.most_visited(0, 10)
    end

    test "honours the limit" do
      for n <- 1..4 do
        store = create_store!()
        StoreVisits.record(store.id, "s-#{n}", %{})
      end

      assert length(StoreVisits.most_visited(7, 2)) == 2
    end

    test "a marketplace with no traffic ranks nobody" do
      assert StoreVisits.most_visited(7, 10) == []
    end
  end

  describe "record/3 feeds the popular sort" do
    test "each recorded visit bumps the store's view_count" do
      store = create_store!()
      assert store.view_count == 0

      StoreVisits.record(store.id, "session-a", %{})
      StoreVisits.record(store.id, "session-b", %{})

      reread = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reread.view_count == 2
    end

    test "the directory's Most popular sort now means most viewed" do
      quiet = create_store!(%{name: "Quiet Shop"})
      busy = create_store!(%{name: "Busy Shop"})

      for n <- 1..3, do: StoreVisits.record(busy.id, "s-#{n}", %{})
      StoreVisits.record(quiet.id, "s-x", %{})

      names =
        Emakola.Stores.Store
        |> Ash.Query.for_read(:list_with_filters, %{sort: :popular})
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.name)

      # Only the relative order matters — the read is unscoped, so stores from
      # sibling tests may ride along.
      busy_at = Enum.find_index(names, &(&1 == "Busy Shop"))
      quiet_at = Enum.find_index(names, &(&1 == "Quiet Shop"))
      assert busy_at < quiet_at
    end
  end
end
