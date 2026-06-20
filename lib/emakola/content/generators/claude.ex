defmodule Emakola.Content.Generators.Claude do
  @moduledoc """
  Claude-backed `Emakola.Content.Generator` (SEO Phase 3).

  Calls the Anthropic Messages API through the injectable `:http_client`
  (`Emakola.HTTPClient.Req` in prod, `HTTPClientMock` in test). Cheapest capable
  model for short, high-volume tasks (descriptions/meta/alt-text); Sonnet only
  for long-form (blog posts, recipes) to keep the per-generation cost low.

  Ships dark: no `:anthropic_api_key` → `{:error, :not_configured}`, no spend.
  """

  @behaviour Emakola.Content.Generator

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"
  @cheap_model "claude-haiku-4-5"
  @longform_model "claude-sonnet-4-6"

  @impl true
  def generate_product_description(product, store) do
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

    complete(@cheap_model, system, user, 400)
  end

  @impl true
  def generate_seo_meta(resource, store) do
    system = """
    You write SEO meta tags. Reply ONLY as JSON: {"title": "...", "description": "..."}.
    Title <= 60 characters, description <= 155 characters. No markdown, no commentary.
    """

    user =
      "Store: #{field(store, :name)}. Title: #{field(resource, :title)}. " <>
        "Summary: #{field(resource, :description) || field(resource, :excerpt)}"

    with {:ok, text} <- complete(@cheap_model, system, user, 200),
         {:ok, %{"title" => title, "description" => description}} <- decode_json(text) do
      {:ok, %{title: title, description: description}}
    else
      {:error, _} = error -> error
      _ -> {:error, :unparseable}
    end
  end

  @impl true
  def generate_blog_post(topic, store, type) do
    system = """
    You write helpful #{type} posts for a West African online store's blog:
    600-1000 words, subheadings, practical, plain English. Reply ONLY as JSON:
    {"title": "", "body": "", "excerpt": "", "tags": []} where body is markdown.
    """

    with {:ok, text} <-
           complete(
             @longform_model,
             system,
             "Store: #{field(store, :name)}. Topic: #{topic}.",
             2000
           ),
         {:ok, %{"title" => t, "body" => b, "excerpt" => e, "tags" => tags}} <- decode_json(text) do
      {:ok, %{title: t, body: b, excerpt: e, tags: List.wrap(tags)}}
    else
      {:error, _} = error -> error
      _ -> {:error, :unparseable}
    end
  end

  @impl true
  def generate_image_alt_text(image_url) do
    system =
      "You write concise, descriptive image alt text under 125 characters. " <>
        "No 'image of' / 'picture of'. Plain English, no quotes."

    content = [
      %{type: "image", source: %{type: "url", url: image_url}},
      %{type: "text", text: "Write alt text for this product image."}
    ]

    complete(@cheap_model, system, content, 100)
  end

  @impl true
  def generate_recipe(product, store) do
    system = """
    You write recipes in West African cuisine context. Reply ONLY as JSON:
    {"body": "", "ingredients": [{"item": "", "quantity": ""}],
     "instructions": [""], "prep_time": 0, "cook_time": 0, "servings": 0}.
    Times are whole minutes.
    """

    user = "Store: #{field(store, :name)}. Product: #{field(product, :title)}. Create a recipe."

    with {:ok, text} <- complete(@longform_model, system, user, 1500),
         {:ok, map} <- decode_json(text) do
      {:ok,
       %{
         body: map["body"],
         ingredients: map["ingredients"] || [],
         instructions: map["instructions"] || [],
         prep_time: map["prep_time"],
         cook_time: map["cook_time"],
         servings: map["servings"]
       }}
    else
      {:error, _} = error -> error
      _ -> {:error, :unparseable}
    end
  end

  # -- HTTP --

  # `content` is a plain string for text tasks or a list of content blocks for
  # vision (alt text). Returns the first text block, trimmed.
  defp complete(model, system, content, max_tokens) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        body = %{
          model: model,
          max_tokens: max_tokens,
          system: system,
          messages: [%{role: "user", content: content}]
        }

        headers = [
          {"x-api-key", key},
          {"anthropic-version", @api_version},
          {"content-type", "application/json"}
        ]

        case http_client().post(@api_url, json: body, headers: headers, receive_timeout: 60_000) do
          {:ok, %{"content" => [%{"text" => text} | _]}} -> {:ok, String.trim(text)}
          {:ok, other} -> {:error, {:unexpected_response, other}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # Models sometimes wrap JSON in prose or code fences; extract the first object.
  defp decode_json(text) do
    case Regex.run(~r/\{.*\}/s, text) do
      [json] -> Jason.decode(json)
      _ -> {:error, :no_json}
    end
  end

  defp http_client, do: Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
  defp api_key, do: Application.get_env(:emakola, :anthropic_api_key)
  defp field(map, key), do: Map.get(map, key) || Map.get(map, to_string(key))
end
