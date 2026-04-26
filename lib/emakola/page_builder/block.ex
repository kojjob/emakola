defmodule Emakola.PageBuilder.Block do
  @moduledoc """
  Behaviour every page-builder block module implements.

  A block module owns:

    * its registry `type/0` string (matches `block.type` in the page json)
    * a human-readable `name/0` and material-symbol `icon/0` for the editor
    * `default_content/0` returning the map of fields the block expects
    * `render/1` returning a Phoenix LiveView `Rendered` for the storefront
    * `edit_form/1` returning the editor form for merchants (Phase 2 use)

  ## Render assigns contract

  `render/1` receives:

      %{
        block:   %{"id" => "...", "type" => "...", "content" => %{...}},
        store:   %Emakola.Stores.Store{},
        products: [...],          # featured products loaded by StoreLive
        categories: [...]         # root categories loaded by StoreLive
      }

  The block reads `assigns.block.content` for its configuration, falling back
  to `default_content/0` for any missing keys. This makes block schema
  changes forward-compatible without database migrations.

  ## Edit form contract

  `edit_form/1` is invoked by the merchant editor (Phase 2) with:

      %{
        block:   %{"id" => "...", "type" => "...", "content" => %{...}},
        form:    %Phoenix.HTML.Form{}
      }

  Phase 1 ships render-only blocks; `edit_form/1` may return an empty
  template until Phase 2.
  """

  @callback type() :: String.t()
  @callback name() :: String.t()
  @callback icon() :: String.t()
  @callback default_content() :: map()
  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback edit_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
