defmodule Emakola.AI.PromptsTest do
  use ExUnit.Case, async: true

  alias Emakola.AI.Prompts

  test "product descriptions are grounded in supplied catalog facts" do
    request =
      Prompts.build(:product_description, %{
        product: %{
          title: "Market Basket",
          description: "Woven basket with two handles",
          tags: ["basket", "woven"]
        },
        store: %{name: "Ama's Shop", currency: :GHS}
      })

    assert request.system =~ "Use only facts present"
    assert request.system =~ "Never invent"
    assert request.system =~ "keyword stuffing"

    assert [%{role: :user, content: content}] = request.messages
    assert content =~ "Notes: Woven basket with two handles"
    assert content =~ "Tags: basket, woven"
  end

  test "blog prompts require human review and placeholders for merchant expertise" do
    request =
      Prompts.build(:blog_post, %{
        topic: "How to choose a woven basket",
        store: %{name: "Ama's Shop"},
        type: :guide
      })

    assert request.system =~ "human-review drafts"
    assert request.system =~ "Never invent"
    assert request.system =~ "[ADD MERCHANT EXPERIENCE:"
  end

  test "metadata and image prompts prohibit unsupported inferences" do
    meta_request =
      Prompts.build(:seo_meta, %{
        resource: %{title: "Basket", description: "Two handles"},
        store: %{name: "Ama's Shop"}
      })

    image_request =
      Prompts.build(:image_alt_text, %{image_url: "https://example.test/basket.jpg"})

    assert meta_request.system =~ "Use only supplied facts"
    assert meta_request.system =~ "delivery"
    assert image_request.system =~ "Describe only visible details"
    assert image_request.system =~ "do not infer material"
  end
end
