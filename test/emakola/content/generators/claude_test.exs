defmodule Emakola.Content.Generators.ClaudeTest do
  # async: false — drives the globally-configured :ai_provider (ProviderMock).
  # DataCase: delegating through Emakola.AI records a usage row.
  use Emakola.DataCase, async: false

  import Mox

  alias Emakola.AI.Response
  alias Emakola.Content.Generators.Claude

  setup :verify_on_exit!

  test "generate_product_description returns the provider text" do
    expect(Emakola.AI.ProviderMock, :complete, fn request ->
      assert request.feature == :product_description
      assert request.model == "claude-haiku-4-5"
      assert [%{role: :user, content: content}] = request.messages
      assert content =~ "Kente"
      {:ok, %Response{text: "A handwoven kente cloth.", model: "claude-haiku-4-5"}}
    end)

    assert {:ok, "A handwoven kente cloth."} =
             Claude.generate_product_description(%{title: "Kente"}, %{
               name: "Ama",
               currency: "GHS"
             })
  end

  test "generate_seo_meta maps parsed JSON to title/description" do
    expect(Emakola.AI.ProviderMock, :complete, fn request ->
      assert request.response_format == :json
      {:ok, %Response{parsed: %{"title" => "Kente | Ama", "description" => "Handwoven kente."}}}
    end)

    assert {:ok, %{title: "Kente | Ama", description: "Handwoven kente."}} =
             Claude.generate_seo_meta(%{title: "Kente"}, %{name: "Ama"})
  end

  test "generate_seo_meta returns :unparseable when the model returns no JSON" do
    expect(Emakola.AI.ProviderMock, :complete, fn _request ->
      {:ok, %Response{parsed: nil, text: "oops"}}
    end)

    assert {:error, :unparseable} = Claude.generate_seo_meta(%{title: "x"}, %{name: "y"})
  end

  test "generate_recipe maps the parsed recipe JSON" do
    expect(Emakola.AI.ProviderMock, :complete, fn _request ->
      {:ok,
       %Response{
         parsed: %{
           "body" => "Cook it",
           "ingredients" => [%{"item" => "Rice", "quantity" => "2 cups"}],
           "instructions" => ["Boil"],
           "prep_time" => 10,
           "cook_time" => 20,
           "servings" => 4
         }
       }}
    end)

    assert {:ok, recipe} = Claude.generate_recipe(%{title: "Jollof"}, %{name: "Ama"})
    assert recipe.servings == 4
    assert recipe.prep_time == 10
    assert [%{"item" => "Rice"}] = recipe.ingredients
  end

  test "generate_image_alt_text sends a vision request and returns the text" do
    expect(Emakola.AI.ProviderMock, :complete, fn request ->
      [%{role: :user, content: content}] = request.messages
      assert Enum.any?(content, &match?(%{type: :image}, &1))
      {:ok, %Response{text: "Handwoven kente cloth in gold and green"}}
    end)

    assert {:ok, alt} = Claude.generate_image_alt_text("https://cdn.example.com/kente.jpg")
    assert alt =~ "kente"
  end

  test "passes through :not_configured (ships dark)" do
    expect(Emakola.AI.ProviderMock, :complete, fn _request -> {:error, :not_configured} end)

    assert {:error, :not_configured} =
             Claude.generate_product_description(%{title: "x"}, %{name: "y"})
  end
end
