defmodule Emakola.Analytics.StoreVisitsTest do
  @moduledoc """
  Counting storefront traffic.

  The point of this is a denominator: reports lost their conversion rate and
  their sales-by-channel breakdown because nothing measured visits, and both
  were removed rather than invented. These tests pin down what "a visit" and
  "a visitor" mean, since a conversion rate is only as honest as those two.
  """
  use Emakola.DataCase, async: true

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
end
