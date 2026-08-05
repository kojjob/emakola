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

  # Sonnet 5 thinks by default when the request omits `thinking`, and thinking
  # tokens bill against max_tokens — so every longform request pairs this model
  # with `thinking: :disabled` (these are format-strict drafts, not reasoning
  # tasks). Its tokenizer also counts ~30% more tokens for the same text than
  # Sonnet 4.6's, hence the larger budgets below.
  @longform_model "claude-sonnet-5"

  # JSON Schemas for structured outputs — the API constrains the response to
  # the schema, so parsing is a guarantee rather than a regex scrape. Structured
  # outputs don't support string/number constraints (maxLength, minimum, …);
  # length and range guidance stays in the prompt text.
  @seo_meta_schema %{
    type: "object",
    properties: %{title: %{type: "string"}, description: %{type: "string"}},
    required: ["title", "description"],
    additionalProperties: false
  }

  @blog_post_schema %{
    type: "object",
    properties: %{
      title: %{type: "string"},
      body: %{type: "string"},
      excerpt: %{type: "string"},
      tags: %{type: "array", items: %{type: "string"}}
    },
    required: ["title", "body", "excerpt", "tags"],
    additionalProperties: false
  }

  @recipe_schema %{
    type: "object",
    properties: %{
      body: %{type: "string"},
      ingredients: %{
        type: "array",
        items: %{
          type: "object",
          properties: %{item: %{type: "string"}, quantity: %{type: "string"}},
          required: ["item", "quantity"],
          additionalProperties: false
        }
      },
      instructions: %{type: "array", items: %{type: "string"}},
      prep_time: %{type: "integer"},
      cook_time: %{type: "integer"},
      servings: %{type: "integer"}
    },
    required: ["body", "ingredients", "instructions", "prep_time", "cook_time", "servings"],
    additionalProperties: false
  }

  @snap_to_shop_schema %{
    "type" => "object",
    "additionalProperties" => false,
    "required" => [
      "identified",
      "title",
      "description",
      "category",
      "tags",
      "alt_text",
      "photo_flags"
    ],
    "properties" => %{
      "identified" => %{"type" => "boolean"},
      "title" => %{"type" => "string", "maxLength" => 60},
      "description" => %{"type" => "string"},
      "category" => %{"type" => ["string", "null"]},
      "tags" => %{"type" => "array", "items" => %{"type" => "string"}, "maxItems" => 8},
      "alt_text" => %{"type" => "string", "maxLength" => 125},
      "photo_flags" => %{
        "type" => "object",
        "additionalProperties" => false,
        "required" => ["stock_photo", "watermark", "screenshot"],
        "properties" => %{
          "stock_photo" => %{"type" => "boolean"},
          "watermark" => %{"type" => "boolean"},
          "screenshot" => %{"type" => "boolean"}
        }
      }
    }
  }

  @doc "Build the request for `feature` from `inputs`."
  @spec build(atom(), map()) :: Request.t()

  def build(:product_description, %{product: product, store: store}) do
    system = """
    You write concise, accurate ecommerce product descriptions for West African
    online shops. Use only facts present in the supplied title, notes, and tags.
    Never invent a material, ingredient, origin, size, feature, certification,
    performance claim, delivery promise, return term, or warranty. If the facts
    are sparse, keep the copy short instead of filling space with generic claims.
    Use plain English, no emojis, keyword stuffing, or unverifiable superlatives.
    """

    user = """
    Store: #{field(store, :name)} (currency: #{field(store, :currency)})
    Product: #{field(product, :title)}
    Notes: #{field(product, :description) || "none"}
    Tags: #{format_tags(field(product, :tags))}

    Write the product description only.
    """

    text_request(@cheap_model, system, user, 400)
  end

  def build(:seo_meta, %{resource: resource, store: store}) do
    system = """
    You write SEO meta tags. Reply ONLY as JSON: {"title": "...", "description": "..."}.
    Title <= 60 characters, description <= 155 characters. No markdown, no commentary.
    Use only supplied facts. Do not add quality, popularity, origin, availability,
    delivery, price, certification, or performance claims that are not provided.
    """

    user =
      "Store: #{field(store, :name)}. Title: #{field(resource, :title)}. " <>
        "Summary: #{field(resource, :description) || field(resource, :excerpt)}"

    %{
      text_request(@cheap_model, system, user, 200)
      | response_format: :json,
        json_schema: @seo_meta_schema
    }
  end

  def build(:blog_post, %{topic: topic, store: store, type: type}) do
    system = """
    You prepare human-review drafts for a West African online store's blog.
    Write a useful #{type} with clear subheadings and plain English. Never invent
    customer stories, quotes, statistics, tests, awards, business history, or
    first-hand experience. Where original merchant expertise is needed, insert a
    concise [ADD MERCHANT EXPERIENCE: ...] prompt instead of fabricating it.
    Reply ONLY as JSON:
    {"title": "", "body": "", "excerpt": "", "tags": []} where body is markdown.
    """

    user = "Store: #{field(store, :name)}. Topic: #{topic}."

    %{
      text_request(@longform_model, system, user, 3000)
      | response_format: :json,
        json_schema: @blog_post_schema,
        thinking: :disabled
    }
  end

  def build(:image_alt_text, %{image_url: image_url}) do
    system =
      "You write concise, descriptive image alt text under 125 characters. " <>
        "Describe only visible details; do not infer material, brand, origin, " <>
        "quality, or product performance. No 'image of' / 'picture of'. " <>
        "Plain English, no quotes."

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
    You prepare human-review recipe drafts in a West African cuisine context.
    Do not make health, nutrition, allergy, or product-ingredient claims not
    present in the input. Reply ONLY as JSON:
    {"body": "", "ingredients": [{"item": "", "quantity": ""}],
     "instructions": [""], "prep_time": 0, "cook_time": 0, "servings": 0}.
    Times are whole minutes.
    """

    user = "Store: #{field(store, :name)}. Product: #{field(product, :title)}. Create a recipe."

    %{
      text_request(@longform_model, system, user, 2000)
      | response_format: :json,
        json_schema: @recipe_schema,
        thinking: :disabled
    }
  end

  def build(:snap_to_shop, %{image_url: image_url, store: store, category_names: category_names}) do
    system = """
    You extract structured product data from merchant-submitted photos for a West African
    ecommerce platform. Never invent a material, ingredient, origin, size, feature,
    certification, performance claim, delivery promise, return term, or warranty.
    Describe only what is visible in the photo. If you cannot clearly identify a
    sellable product, set identified to false and leave other fields empty. Set
    photo_flags honestly: stock_photo when the image looks professionally staged/
    catalog-sourced rather than merchant-taken; watermark when any watermark or
    overlaid logo/text is present; screenshot when the image is a screenshot of
    another app or listing. category must be exactly one of the provided category
    names, or null.
    """

    categories = Enum.join(category_names, ", ")

    user = """
    Store: #{field(store, :name)} (#{field(store, :currency)})
    Available categories: #{categories}

    Extract product data from this photo. Reply only as JSON.
    """

    content = [
      %{type: :image, url: image_url},
      %{type: :text, text: user}
    ]

    %Request{
      model: @longform_model,
      system: system,
      messages: [%{role: :user, content: content}],
      response_format: :json,
      json_schema: @snap_to_shop_schema,
      max_tokens: 1000,
      thinking: :disabled
    }
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

  defp format_tags(tags) when is_list(tags) and tags != [], do: Enum.join(tags, ", ")
  defp format_tags(_tags), do: "none"
end
