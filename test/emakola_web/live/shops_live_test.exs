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
    for i <- 1..3, do: region_store!("Accra Shop #{i}", "Greater Accra")

    {:ok, _view, html} = live(conn, "/shops/greater-accra")

    assert html =~ "Online shops in Greater Accra"
    assert html =~ "Accra Shop 1"

    assert html =~
             ~s(<link rel="canonical" href="http://localhost:4000/shops/greater-accra")

    assert html =~ ~s(<meta name="robots" content="index, follow")
    assert html =~ ~s("@type":"FAQPage")
  end

  test "noindexes a thin region with fewer than 3 shops", %{conn: conn} do
    region_store!("Lone Kumasi Shop", "Ashanti")

    {:ok, _view, html} = live(conn, "/shops/ashanti")

    assert html =~ "Lone Kumasi Shop"
    assert html =~ ~s(<meta name="robots" content="noindex, follow")
  end

  test "excludes inactive stores and stores from other regions", %{conn: conn} do
    region_store!("Visible Accra Shop", "Greater Accra")

    create_store!(%{
      name: "Hidden Inactive",
      slug: "hidden-#{System.unique_integer([:positive])}",
      region: "Greater Accra",
      active: false
    })

    region_store!("Kumasi Only", "Ashanti")

    {:ok, _view, html} = live(conn, "/shops/greater-accra")

    assert html =~ "Visible Accra Shop"
    refute html =~ "Hidden Inactive"
    refute html =~ "Kumasi Only"
  end

  test "redirects an unknown region to /stores", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/stores"}}} = live(conn, "/shops/atlantis")
  end
end
