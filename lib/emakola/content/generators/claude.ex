defmodule Emakola.Content.Generators.Claude do
  @moduledoc """
  Claude-backed `Emakola.Content.Generator` (SEO Phase 3).

  Now a thin adapter over the shared AI foundation: each function delegates to
  `Emakola.AI.generate/3`, which builds the prompt (`Emakola.AI.Prompts`), calls
  the configured provider (`Emakola.AI.Providers.Anthropic`), and records token
  usage and cost (`Emakola.AI.Usage`). The prompts and Anthropic wire format now
  live in the foundation; this module only adapts the neutral `Emakola.AI.Response`
  back to the shapes the SEO callers expect.

  Ships dark via the provider: no `ANTHROPIC_API_KEY` → `{:error, :not_configured}`.
  """

  @behaviour Emakola.Content.Generator

  alias Emakola.AI

  @impl true
  def generate_product_description(product, store) do
    with {:ok, %{text: text}} <-
           AI.generate(:product_description, %{product: product, store: store}, store: store) do
      {:ok, text}
    end
  end

  @impl true
  def generate_seo_meta(resource, store) do
    case AI.generate(:seo_meta, %{resource: resource, store: store}, store: store) do
      {:ok, %{parsed: %{"title" => title, "description" => description}}} ->
        {:ok, %{title: title, description: description}}

      {:ok, _} ->
        {:error, :unparseable}

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def generate_blog_post(topic, store, type) do
    case AI.generate(:blog_post, %{topic: topic, store: store, type: type}, store: store) do
      {:ok, %{parsed: %{"title" => title, "body" => body, "excerpt" => excerpt, "tags" => tags}}} ->
        {:ok, %{title: title, body: body, excerpt: excerpt, tags: List.wrap(tags)}}

      {:ok, _} ->
        {:error, :unparseable}

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def generate_image_alt_text(image_url) do
    with {:ok, %{text: text}} <- AI.generate(:image_alt_text, %{image_url: image_url}) do
      {:ok, text}
    end
  end

  @impl true
  def generate_recipe(product, store) do
    case AI.generate(:recipe, %{product: product, store: store}, store: store) do
      {:ok, %{parsed: %{} = map}} ->
        {:ok,
         %{
           body: map["body"],
           ingredients: map["ingredients"] || [],
           instructions: map["instructions"] || [],
           prep_time: map["prep_time"],
           cook_time: map["cook_time"],
           servings: map["servings"]
         }}

      {:ok, _} ->
        {:error, :unparseable}

      {:error, _} = error ->
        error
    end
  end
end
