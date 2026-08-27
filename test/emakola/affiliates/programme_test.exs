defmodule Emakola.Affiliates.ProgrammeTest do
  @moduledoc """
  A merchant's affiliate programme: whether it is on, what it pays, and the
  links that carry a sale back to the person who drove it.

  The rate is basis points, the convention everywhere money is computed here
  (`@bps_denominator 10_000`) — never a percentage as a float, because a
  commission is money and money is integers.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Affiliates
  alias Emakola.Affiliates.Programme

  setup do
    {merchant, store} = create_merchant_with_store!()
    product = create_product!(store, status: :active, title: "Kente Cloth")

    {:ok, affiliate} =
      Affiliates.register(%{
        phone: "0201234567",
        name: "Ama Mensah",
        momo_number: "0201234567",
        momo_provider: "mtn"
      })

    %{merchant: merchant, store: store, product: product, affiliate: affiliate}
  end

  describe "enable/2" do
    test "starts off, and turning it on sets a rate", ctx do
      assert Programme.enabled?(ctx.store.id) == false

      assert {:ok, programme} = Programme.enable(ctx.store.id, 1_000)

      assert programme.commission_bps == 1_000
      assert programme.active == true
      assert Programme.enabled?(ctx.store.id) == true
    end

    test "refuses a rate that would pay out more than the sale", ctx do
      # 10_000 bps is 100%. Anything at or above it means the merchant keeps
      # nothing and, once other carves stack, the split goes negative.
      assert {:error, _} = Programme.enable(ctx.store.id, 10_000)
      assert {:error, _} = Programme.enable(ctx.store.id, 12_000)
    end

    test "refuses a negative rate", ctx do
      assert {:error, _} = Programme.enable(ctx.store.id, -100)
    end

    test "enabling twice updates the rate rather than creating a second", ctx do
      {:ok, _} = Programme.enable(ctx.store.id, 1_000)
      {:ok, updated} = Programme.enable(ctx.store.id, 1_500)

      assert updated.commission_bps == 1_500
      assert {:ok, [_only_one]} = Programme.list_all(ctx.store.id)
    end

    test "disabling stops it without forgetting the rate", ctx do
      {:ok, _} = Programme.enable(ctx.store.id, 1_000)
      {:ok, disabled} = Programme.disable(ctx.store.id)

      assert disabled.active == false
      assert disabled.commission_bps == 1_000
      assert Programme.enabled?(ctx.store.id) == false
    end
  end

  describe "link_for/3" do
    test "mints one stable link per affiliate per product", ctx do
      {:ok, _} = Programme.enable(ctx.store.id, 1_000)

      assert {:ok, link} = Programme.link_for(ctx.affiliate, ctx.store.id, ctx.product.id)
      assert is_binary(link.token)

      # Asking again returns the SAME token — an affiliate who shares a link
      # twice must not split their own attribution across two rows.
      assert {:ok, same} = Programme.link_for(ctx.affiliate, ctx.store.id, ctx.product.id)
      assert same.token == link.token
    end

    test "refuses when the programme is off", ctx do
      assert {:error, :programme_inactive} =
               Programme.link_for(ctx.affiliate, ctx.store.id, ctx.product.id)
    end

    test "the url carries the token and points at the product", ctx do
      {:ok, _} = Programme.enable(ctx.store.id, 1_000)
      {:ok, link} = Programme.link_for(ctx.affiliate, ctx.store.id, ctx.product.id)

      url = Programme.url(link)

      assert url =~ link.token
      assert url =~ "/products/"
    end
  end

  describe "find_link/1" do
    test "resolves a token back to its affiliate and product", ctx do
      {:ok, _} = Programme.enable(ctx.store.id, 1_000)
      {:ok, link} = Programme.link_for(ctx.affiliate, ctx.store.id, ctx.product.id)

      assert {:ok, found} = Programme.find_link(link.token)
      assert found.affiliate_id == ctx.affiliate.id
      assert found.product_id == ctx.product.id
    end

    test "an unknown token resolves to nothing" do
      assert {:error, :not_found} = Programme.find_link("nope")
    end
  end
end
