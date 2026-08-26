defmodule EmakolaWeb.ShopsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  defp region_store!(name, region) do
    create_store!(%{
      name: name,
      slug: "#{slugify(name)}-#{System.unique_integer([:positive])}",
      region: region,
      active: true
    })
  end

  defp slugify(s), do: s |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")

  test "lists active shops in a region and indexes when there are enough", %{conn: conn} do
    stores = for i <- 1..3, do: region_store!("Accra Shop #{i}", "Greater Accra")

    {:ok, view, html} = live(conn, "/shops/greater-accra")

    assert has_element?(view, "#plain-app-layout")
    assert has_element?(view, "#shops-region-heading")
    assert has_element?(view, "#regional-shops[phx-update='stream'][data-count='3']")

    for store <- stores do
      # The directory hands out the short form — makola.io/yourshop — because
      # that is the link a merchant can say aloud or write on a poster. The
      # /s/ route still serves, it is just no longer what we hand out.
      assert has_element?(view, "#stores-#{store.id}[href='/#{store.slug}']")
    end

    assert html =~
             ~s(<link rel="canonical" href="http://localhost:4000/shops/greater-accra")

    assert html =~ ~s(<meta name="robots" content="index, follow")
    assert html =~ ~s("@type":"FAQPage")
  end

  test "noindexes a thin region with fewer than 3 shops", %{conn: conn} do
    store = region_store!("Lone Kumasi Shop", "Ashanti")

    {:ok, view, html} = live(conn, "/shops/ashanti")

    assert has_element?(view, "#regional-shops[data-count='1']")
    assert has_element?(view, "#stores-#{store.id}")
    assert html =~ ~s(<meta name="robots" content="noindex, follow")
  end

  test "renders the streamed empty state for a region without shops", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/shops/western")

    assert has_element?(view, "#regional-shops[data-count='0']")
    assert has_element?(view, "#regional-shops-empty")
    refute has_element?(view, "#regional-shops > a[id^='stores-']")
  end

  test "excludes inactive stores and stores from other regions", %{conn: conn} do
    visible = region_store!("Visible Accra Shop", "Greater Accra")

    hidden =
      create_store!(%{
        name: "Hidden Inactive",
        slug: "hidden-#{System.unique_integer([:positive])}",
        region: "Greater Accra",
        active: false
      })

    other_region = region_store!("Kumasi Only", "Ashanti")

    {:ok, view, _html} = live(conn, "/shops/greater-accra")

    assert has_element?(view, "#stores-#{visible.id}")
    refute has_element?(view, "#stores-#{hidden.id}")
    refute has_element?(view, "#stores-#{other_region.id}")
  end

  test "redirects an unknown region to /stores", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/stores"}}} = live(conn, "/shops/atlantis")
  end
end
