defmodule Emakola.Content.Generator do
  @moduledoc """
  Behaviour + dispatcher for AI content generation (SEO Phase 3).

  The active implementation is configured via `:content_generator`
  (`Emakola.Content.Generators.Claude` in prod, a Mox `GeneratorMock` in test),
  so callers use the convenience functions here and tests swap the whole
  generator — they never hit the network.

  Ships dark: with no `ANTHROPIC_API_KEY` the Claude implementation returns
  `{:error, :not_configured}` and nothing is spent.
  """

  @type store :: map()
  @type result(t) :: {:ok, t} | {:error, term()}

  @callback generate_product_description(product :: map(), store()) :: result(String.t())
  @callback generate_seo_meta(resource :: map(), store()) ::
              result(%{title: String.t(), description: String.t()})
  @callback generate_blog_post(topic :: String.t(), store(), type :: atom()) ::
              result(%{
                title: String.t(),
                body: String.t(),
                excerpt: String.t(),
                tags: [String.t()]
              })
  @callback generate_image_alt_text(image_url :: String.t()) :: result(String.t())
  @callback generate_recipe(product :: map(), store()) :: result(map())

  @spec impl() :: module()
  def impl,
    do: Application.get_env(:emakola, :content_generator, Emakola.Content.Generators.Claude)

  def generate_product_description(product, store),
    do: impl().generate_product_description(product, store)

  def generate_seo_meta(resource, store), do: impl().generate_seo_meta(resource, store)

  def generate_blog_post(topic, store, type), do: impl().generate_blog_post(topic, store, type)

  def generate_image_alt_text(image_url), do: impl().generate_image_alt_text(image_url)

  def generate_recipe(product, store), do: impl().generate_recipe(product, store)
end
