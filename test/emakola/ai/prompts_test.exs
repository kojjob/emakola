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

  test "long-form prompts run on Sonnet 5 with thinking off and tokenizer headroom" do
    blog =
      Prompts.build(:blog_post, %{topic: "t", store: %{name: "Ama's Shop"}, type: :guide})

    recipe = Prompts.build(:recipe, %{product: %{title: "Basket"}, store: %{name: "Ama's Shop"}})

    # Sonnet 5 runs adaptive thinking when the field is omitted, and thinking
    # tokens bill against max_tokens — an unbounded think could truncate the
    # JSON mid-object. These are format-strict drafts; thinking stays off.
    for request <- [blog, recipe] do
      assert request.model == "claude-sonnet-5"
      assert request.thinking == :disabled
    end

    # Sonnet 5's tokenizer counts ~30% more tokens for the same text, so the
    # old budgets would truncate equivalent drafts.
    assert blog.max_tokens == 3000
    assert recipe.max_tokens == 2000
  end

  test "cheap-model prompts leave thinking unset (Haiku wire shape unchanged)" do
    request = Prompts.build(:seo_meta, %{resource: %{}, store: %{}})

    assert request.model == "claude-haiku-4-5"
    assert request.thinking == nil
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
