defmodule Emakola.Content.Generators.ClaudeTest do
  # async: false — sets the :anthropic_api_key application env.
  use ExUnit.Case, async: false

  import Mox

  alias Emakola.Content.Generators.Claude

  setup :verify_on_exit!

  setup do
    prev = Application.get_env(:emakola, :anthropic_api_key)
    Application.put_env(:emakola, :anthropic_api_key, "test-key")

    on_exit(fn ->
      if prev,
        do: Application.put_env(:emakola, :anthropic_api_key, prev),
        else: Application.delete_env(:emakola, :anthropic_api_key)
    end)

    :ok
  end

  defp anthropic_text(text), do: {:ok, %{"content" => [%{"type" => "text", "text" => text}]}}

  test "generate_product_description builds the Anthropic request and returns the text" do
    expect(Emakola.HTTPClientMock, :post, fn url, opts ->
      assert url == "https://api.anthropic.com/v1/messages"
      body = opts[:json]
      assert body.model == "claude-haiku-4-5"
      assert [%{role: "user", content: content}] = body.messages
      assert content =~ "Kente Cloth"
      assert {"x-api-key", "test-key"} in opts[:headers]
      assert {"anthropic-version", "2023-06-01"} in opts[:headers]
      anthropic_text("A beautiful handwoven kente cloth, rich with tradition.")
    end)

    store = %{name: "Ama's Shop", currency: "GHS"}
    product = %{title: "Kente Cloth", description: "handwoven"}

    assert {:ok, desc} = Claude.generate_product_description(product, store)
    assert desc =~ "kente"
  end

  test "generate_seo_meta parses the JSON title/description" do
    expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      anthropic_text(
        ~s({"title": "Kente Cloth | Ama", "description": "Authentic handwoven kente."})
      )
    end)

    assert {:ok, %{title: "Kente Cloth | Ama", description: "Authentic handwoven kente."}} =
             Claude.generate_seo_meta(%{title: "Kente"}, %{name: "Ama"})
  end

  test "generate_recipe parses structured recipe JSON" do
    expect(Emakola.HTTPClientMock, :post, fn _url, _opts ->
      anthropic_text(
        ~s({"body":"Cook it","ingredients":[{"item":"Rice","quantity":"2 cups"}],"instructions":["Boil"],"prep_time":10,"cook_time":20,"servings":4})
      )
    end)

    assert {:ok, recipe} = Claude.generate_recipe(%{title: "Jollof"}, %{name: "Ama"})
    assert recipe.servings == 4
    assert recipe.prep_time == 10
    assert [%{"item" => "Rice"}] = recipe.ingredients
  end

  test "generate_image_alt_text sends a vision content block" do
    expect(Emakola.HTTPClientMock, :post, fn _url, opts ->
      [%{role: "user", content: content}] = opts[:json].messages
      assert Enum.any?(content, &match?(%{type: "image"}, &1))
      anthropic_text("Handwoven kente cloth in gold and green")
    end)

    assert {:ok, alt} = Claude.generate_image_alt_text("https://cdn.example.com/kente.jpg")
    assert alt =~ "kente"
  end

  test "returns {:error, :not_configured} when no API key (ships dark)" do
    Application.delete_env(:emakola, :anthropic_api_key)

    assert {:error, :not_configured} =
             Claude.generate_product_description(%{title: "x"}, %{name: "y"})
  end
end
