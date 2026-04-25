defmodule Emakola.PageBuilder do
  @moduledoc """
  Registry and dispatcher for the merchant page-builder block library.

  ## Registry

  `blocks/0` returns every registered block module. `block_module_for/1`
  looks up a module by its registry `type` string (the value stored in
  `page.blocks[].type`).

  ## Render dispatch

  `render_block/2` looks up the block module for a single block map and
  invokes its `render/1` with the merged assigns. Pages render by mapping
  over `page.blocks` and calling `render_block/2` for each.

  ## Adding a new block type

  1. Create `lib/emakola/page_builder/blocks/<name>.ex` implementing
     `Emakola.PageBuilder.Block`.
  2. Add the module to `@registered_blocks` below.
  3. Add a render-side test in `test/emakola/page_builder/blocks/`.

  Block schema validation is intentionally loose — `default_content/0`
  fills missing keys at render time, so a block whose schema changes
  doesn't strand existing pages.
  """

  alias Emakola.PageBuilder.Blocks

  @registered_blocks [
    Blocks.HeroBanner,
    Blocks.ProductGrid,
    Blocks.TextSection,
    Blocks.ImageBanner,
    Blocks.Spacer
  ]

  @doc """
  Returns every registered block module.
  """
  @spec blocks() :: [module()]
  def blocks, do: @registered_blocks

  @doc """
  Returns the block module for a registry type string, or `nil` if no
  block of that type is registered.
  """
  @spec block_module_for(String.t() | nil) :: module() | nil
  def block_module_for(nil), do: nil

  def block_module_for(type) when is_binary(type) do
    Enum.find(@registered_blocks, fn mod -> mod.type() == type end)
  end

  @doc """
  Renders a single block. Returns `nil` (which Phoenix safely renders as
  empty) when the block's type isn't registered or the block map is
  malformed — pages keep rendering even if a block module is removed.

  `assigns` should include `:store`, `:products`, `:categories` from
  `StoreLive`.
  """
  @spec render_block(map(), map()) :: Phoenix.LiveView.Rendered.t() | nil
  def render_block(%{"type" => type} = block, assigns) when is_map(assigns) do
    case block_module_for(type) do
      nil ->
        nil

      module ->
        merged =
          assigns
          |> Map.put(:block, block)
          |> Map.put(:content, merged_content(module, block))
          # Phoenix.Component requires `__changed__` for change tracking. When
          # called from a HEEx template it's already present; calls from
          # outside templates (StoreLive, tests) need it added explicitly.
          |> Map.put_new(:__changed__, nil)

        module.render(merged)
    end
  end

  def render_block(_block, _assigns), do: nil

  @doc """
  Resolves a block's content by merging stored content over the block
  module's defaults. Missing fields are populated from `default_content/0`,
  so a block with stale or partial content keeps rendering.
  """
  @spec merged_content(module(), map()) :: map()
  def merged_content(module, %{"content" => content}) when is_map(content) do
    Map.merge(module.default_content(), atomize_top_level(content))
  end

  def merged_content(module, _), do: module.default_content()

  # Block content stored in JSON has string keys. Block modules read fields as
  # atoms for ergonomics. We convert top-level keys only — nested values stay
  # as-is. Unknown keys (no matching atom) are silently dropped per-key so
  # one stale field doesn't poison the whole content map.
  defp atomize_top_level(content) do
    Enum.reduce(content, %{}, fn
      {k, v}, acc when is_binary(k) ->
        case safe_to_existing_atom(k) do
          {:ok, atom} -> Map.put(acc, atom, v)
          :error -> acc
        end

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  defp safe_to_existing_atom(s) do
    {:ok, String.to_existing_atom(s)}
  rescue
    ArgumentError -> :error
  end
end
