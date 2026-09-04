defmodule EmakolaWeb.TrustBadgeRenderTest do
  @moduledoc """
  The badge is rendered from plain maps in three directory components. These
  tests pin what a shopper actually sees, because the render sites are where a
  badge can quietly start over-claiming again.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias EmakolaWeb.StoresComponents

  defp card(store_overrides) do
    store =
      Map.merge(
        %{
          id: Ecto.UUID.generate(),
          name: "Ama Trades",
          slug: "ama-trades",
          tagline: "Kente and beads",
          description: nil,
          verified: true,
          verified_basis: :wallet_proof,
          verified_basis_at: DateTime.utc_now(),
          featured: false,
          theme_config: %{},
          city: "Accra",
          region: "Greater Accra",
          inserted_at: DateTime.utc_now(),
          product_count: 3
        },
        Map.new(store_overrides)
      )

    %{store: store, target: "_self", show_favorite: false, is_favorite: false}
    |> StoresComponents.store_card()
    |> rendered_to_string()
  end

  defp days_ago(n), do: DateTime.add(DateTime.utc_now(), -n * 24 * 3600, :second)

  test "a wallet-proven shop shows the tick and says why" do
    html = card(%{})

    assert html =~ "Checked"
    assert html =~ "Money goes to a checked wallet"
  end

  test "the badge never says the bare word 'Verified' any more" do
    # It claimed identity the system could not back. Narrowed to "Checked",
    # with the reason spelled out separately.
    refute card(%{}) =~ "Verified"
  end

  test "a papers-checked shop says papers, not wallet" do
    html = card(%{verified_basis: :business_review})

    assert html =~ "Shop papers checked"
    refute html =~ "checked wallet"
  end

  test "an unverified shop shows no badge and no reason" do
    html = card(%{verified: false})

    refute html =~ "Money goes to a checked wallet"
    refute html =~ "Shop papers checked"
  end

  test "a badge with no recorded basis shows nothing" do
    html = card(%{verified_basis: nil, verified_basis_at: nil})

    refute html =~ "Checked by Makola staff"
    refute html =~ "Money goes to a checked wallet"
  end

  describe "the retired Ghana Card basis lapses on the page too" do
    test "inside the grace window it still shows" do
      html = card(%{verified_basis: :retired_document_flow, verified_basis_at: days_ago(10)})
      assert html =~ "Checked by Makola staff"
    end

    test "past it the badge is gone from the card entirely" do
      html = card(%{verified_basis: :retired_document_flow, verified_basis_at: days_ago(120)})

      refute html =~ "Checked by Makola staff"
      refute html =~ "Money goes to a checked wallet"
    end
  end

  test "the shopper is never told which telco the merchant is paid on" do
    # Payout details live on a merchant-only resource by design.
    html = card(%{verified_basis: :wallet_proof})

    refute html =~ "MTN"
    refute html =~ "Telecel"
    refute html =~ "AirtelTigo"
  end
end
