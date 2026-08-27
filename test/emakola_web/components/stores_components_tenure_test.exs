defmodule EmakolaWeb.StoresComponentsTenureTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EmakolaWeb.StoresComponents

  defp store(attrs) do
    Map.merge(
      %{
        id: Ash.UUID.generate(),
        name: "Adom Fresh",
        slug: "adom-fresh",
        tagline: nil,
        description: nil,
        logo_url: nil,
        featured: false,
        verified: false,
        theme_config: %{},
        city: nil,
        region: nil,
        inserted_at: ~U[2026-03-14 09:00:00.000000Z]
      },
      attrs
    )
  end

  describe "tenure badge" do
    test "the card says when the shop joined" do
      html = render_component(&StoresComponents.store_card/1, store: store(%{}))

      assert html =~ "Since Mar 2026"
    end

    test "the carousel hero says it too" do
      html =
        render_component(&StoresComponents.featured_carousel/1,
          stores: [store(%{featured: true})]
        )

      assert html =~ "Since Mar 2026"
    end

    test "a store somehow missing its timestamp shows no badge rather than garbage" do
      html = render_component(&StoresComponents.store_card/1, store: store(%{inserted_at: nil}))

      refute html =~ "Since"
    end
  end
end
