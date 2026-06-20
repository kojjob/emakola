defmodule EmakolaWeb.SEO.RegionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.SEO.Regions

  defp store!(name, region, active) do
    create_store!(%{
      name: name,
      slug: "#{String.downcase(name)}-#{System.unique_integer([:positive])}",
      region: region,
      active: active
    })
  end

  test "slug/1 and from_slug/1 round-trip; unknown slug is nil" do
    assert Regions.slug("Greater Accra") == "greater-accra"
    assert Regions.from_slug("greater-accra") == "Greater Accra"
    assert Regions.from_slug("atlantis") == nil
  end

  test "indexable/0 returns only regions with at least min_for_index active shops" do
    for i <- 1..Regions.min_for_index(), do: store!("Accra#{i}", "Greater Accra", true)
    store!("Lone", "Ashanti", true)
    store!("Inactive", "Greater Accra", false)

    indexable = Regions.indexable()

    assert {"Greater Accra", "greater-accra"} in indexable
    refute Enum.any?(indexable, fn {name, _slug} -> name == "Ashanti" end)
  end
end
