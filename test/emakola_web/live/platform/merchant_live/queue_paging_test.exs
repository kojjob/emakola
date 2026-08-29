defmodule EmakolaWeb.Platform.MerchantLive.QueuePagingTest do
  @moduledoc """
  The merchant queue streams a page at a time and can be reordered.

  Before this, every merchant on the platform was streamed into the DOM on
  mount, in one fixed order. That is fine at two dozen and expensive at a few
  thousand, and it gave staff no way to bring the newest signups or the
  merchants with the most stores to the top.
  """
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  # One more than a page, so the boundary is exercised rather than assumed.
  @over_a_page 26

  defp seed_queue! do
    for i <- 1..@over_a_page do
      Factory.create_merchant!(%{
        name: "Queue Merchant #{String.pad_leading(to_string(i), 2, "0")}",
        email: "queue-#{i}@example.com"
      })
    end
  end

  defp sorted_by_name(view) do
    view
    |> element("#merchant-sort-form")
    |> render_change(%{"sort" => "name"})
  end

  describe "paging" do
    setup %{conn: conn} do
      seed_queue!()
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, conn: conn}
    end

    test "streams one page and reveals the rest on Load more", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      html = sorted_by_name(view)
      assert html =~ "Queue Merchant 01"
      refute html =~ "Queue Merchant 26"

      html = view |> element("#merchants-load-more") |> render_click()
      assert html =~ "Queue Merchant 26"
    end

    test "the footer counts what is shown against what matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      assert sorted_by_name(view) =~ "Showing 25 of #{@over_a_page}"

      assert view |> element("#merchants-load-more") |> render_click() =~
               "Showing #{@over_a_page} of #{@over_a_page}"
    end

    test "the Load more button is gone once the whole queue is shown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      assert has_element?(view, "#merchants-load-more")
      render_click(element(view, "#merchants-load-more"))
      refute has_element?(view, "#merchants-load-more")
    end

    test "searching resets the page window", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      render_click(element(view, "#merchants-load-more"))

      html =
        view
        |> element("#merchant-search-form")
        |> render_change(%{"search" => "Queue Merchant 2"})

      assert html =~ "Showing 7 of 7"
      refute has_element?(view, "#merchants-load-more")
    end
  end

  describe "sorting" do
    test "name orders the queue A to Z", %{conn: conn} do
      Factory.create_merchant!(%{name: "Zenabu Alhassan", email: "zen@example.com"})
      Factory.create_merchant!(%{name: "Adwoa Badu", email: "adwoa@example.com"})
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      html = sorted_by_name(view)

      assert index_of(html, "Adwoa Badu") < index_of(html, "Zenabu Alhassan")
    end

    test "most stores brings merchants with stores to the top", %{conn: conn} do
      with_store = Factory.create_merchant!(%{name: "Has Store", email: "has@example.com"})
      Factory.create_merchant!(%{name: "Aaa No Store", email: "none@example.com"})
      store = Factory.create_store!()
      Factory.create_store_membership!(with_store, store, :owner)

      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      html =
        view
        |> element("#merchant-sort-form")
        |> render_change(%{"sort" => "stores"})

      assert index_of(html, "Has Store") < index_of(html, "Aaa No Store")
    end

    test "an unknown sort key falls back to the default order", %{conn: conn} do
      Factory.create_merchant!(%{name: "Only Merchant", email: "only@example.com"})
      {conn, _user, _session} = setup_platform_staff(conn)

      {:ok, view, _html} = live(conn, ~p"/platform/merchants")

      html =
        view
        |> element("#merchant-sort-form")
        |> render_change(%{"sort" => "'; drop table merchants; --"})

      assert html =~ "Only Merchant"
    end
  end

  defp index_of(html, needle) do
    case :binary.match(html, needle) do
      {at, _} -> at
      :nomatch -> flunk("expected #{inspect(needle)} in the rendered queue")
    end
  end
end
