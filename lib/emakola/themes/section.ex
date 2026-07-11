defmodule Emakola.Themes.Section do
  @moduledoc """
  Contract for a theme-native home section (spec:
  docs/superpowers/specs/2026-07-11-section-editor-design.md).

  `render/1` receives the storefront assigns (`:store`, `:products`,
  `:categories`, plus whatever the theme's home already passes) merged
  with `:settings` (schema defaults overridden by the merchant's saved
  values) and `:section_meta` (registry metadata — used by the block
  bridge, empty for theme sections).

  A setting is `%{key: String.t(), type: atom, label: String.t(),
  default: term}` with type in `:string | :text | :image_url |
  :category | :link | :boolean | :integer`.
  """

  @callback key() :: String.t()
  @callback label() :: String.t()
  @callback settings_schema() :: [map()]
  @callback render(map()) :: Phoenix.LiveView.Rendered.t()
end
