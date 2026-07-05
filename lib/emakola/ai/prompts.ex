defmodule Emakola.AI.Prompts do
  @moduledoc """
  Central registry of AI prompt templates.

  `build/2` maps a feature key + inputs to a neutral `Emakola.AI.Request` (system,
  messages, model, token budget, response format). Keeping every prompt here — out
  of provider and worker code — makes them reviewable in one place and lets each new
  AI feature add an entry without touching the dispatch layer.

  Model choice follows the suite convention: the cheapest capable model
  (`#{"claude-haiku-4-5"}`) for short, high-volume text; Sonnet for long-form and
  structured tasks.
  """

  alias Emakola.AI.Request

  @cheap_model "claude-haiku-4-5"
  @longform_model "claude-sonnet-4-6"

  @doc "Build the request for `feature` from `inputs`."
  @spec build(atom(), map()) :: Request.t()

  def build(:product_description, %{product: product, store: store}) do
    system = """
    You write concise, warm ecommerce product descriptions for West African
    online shops. 2-3 short paragraphs, benefit-led, plain English, no emojis.
    """

    user = """
    Store: #{field(store, :name)} (#{field(store, :currency)}, Ghana / West Africa)
    Product: #{field(product, :title)}
    Notes: #{field(product, :description) || "none"}

    Write the product description only.
    """

    text_request(@cheap_model, system, user, 400)
  end

  def build(:seo_meta, %{resource: resource, store: store}) do
    system = """
    You write SEO meta tags. Reply ONLY as JSON: {"title": "...", "description": "..."}.
    Title <= 60 characters, description <= 155 characters. No markdown, no commentary.
    """

    user =
      "Store: #{field(store, :name)}. Title: #{field(resource, :title)}. " <>
        "Summary: #{field(resource, :description) || field(resource, :excerpt)}"

    %{text_request(@cheap_model, system, user, 200) | response_format: :json}
  end

  def build(:blog_post, %{topic: topic, store: store, type: type}) do
    system = """
    You write helpful #{type} posts for a West African online store's blog:
    600-1000 words, subheadings, practical, plain English. Reply ONLY as JSON:
    {"title": "", "body": "", "excerpt": "", "tags": []} where body is markdown.
    """

    user = "Store: #{field(store, :name)}. Topic: #{topic}."

    %{text_request(@longform_model, system, user, 2000) | response_format: :json}
  end

  def build(:image_alt_text, %{image_url: image_url}) do
    system =
      "You write concise, descriptive image alt text under 125 characters. " <>
        "No 'image of' / 'picture of'. Plain English, no quotes."

    content = [
      %{type: :image, url: image_url},
      %{type: :text, text: "Write alt text for this product image."}
    ]

    %Request{
      model: @cheap_model,
      system: system,
      messages: [%{role: :user, content: content}],
      max_tokens: 100
    }
  end

  def build(:recipe, %{product: product, store: store}) do
    system = """
    You write recipes in West African cuisine context. Reply ONLY as JSON:
    {"body": "", "ingredients": [{"item": "", "quantity": ""}],
     "instructions": [""], "prep_time": 0, "cook_time": 0, "servings": 0}.
    Times are whole minutes.
    """

    user = "Store: #{field(store, :name)}. Product: #{field(product, :title)}. Create a recipe."

    %{text_request(@longform_model, system, user, 1500) | response_format: :json}
  end

  # -- helpers --

  defp text_request(model, system, user, max_tokens) do
    %Request{
      model: model,
      system: system,
      messages: [%{role: :user, content: user}],
      max_tokens: max_tokens
    }
  end

  # Inputs may arrive as structs/maps with atom or string keys.
  defp field(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))
end
