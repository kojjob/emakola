defmodule Emakola.Themes.ProtectionSurfacesUniversalityTest do
  @moduledoc """
  Pins today's fact that every registered theme delegates `:tracking` and
  `:checkout` to `Emakola.Themes.DefaultRenderers` — mirrors the enumeration
  pattern in `no_invented_provenance_test.exs` and
  `default_renderer_consistency_test.exs`.

  `ThemeRenderer.theme_render/2` dispatches to a theme module's OWN
  `render_tracking/1` or `render_checkout/1` the moment either is exported,
  bypassing `DefaultRenderers.Tracking`/`DefaultRenderers.Checkout` entirely.
  Tracking is the only page carrying the buyer-protection strip — the
  confirm-delivery and file-a-complaint controls a protected buyer needs
  (TC-2). A future theme that adds its own tracking (or checkout) page
  without also carrying that surface would silently strand every buyer on
  that theme with no way to confirm delivery or complain, no error, no
  visible sign anything is missing.
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  # Page => the ThemeRenderer callback a theme module would need to export to
  # take over that page from DefaultRenderers.
  @guarded_pages %{tracking: :render_tracking, checkout: :render_checkout}

  describe "every registered theme leaves tracking and checkout to DefaultRenderers" do
    for theme_id <- ThemeResolver.theme_ids() do
      @theme_id theme_id

      test "#{theme_id}" do
        theme_module = ThemeResolver.theme_module(@theme_id)
        Code.ensure_loaded(theme_module)

        for {page, callback} <- @guarded_pages do
          refute function_exported?(theme_module, callback, 1), """
          #{inspect(theme_module)} (theme "#{@theme_id}") now exports #{callback}/1.

          Tracking carries the buyer-protection strip — the ONLY surface where a
          protected buyer confirms delivery or files a complaint (TC-2). The
          moment a theme module exports #{callback}/1,
          Emakola.Themes.ThemeRenderer.theme_render/2 dispatches to the theme's
          own #{page} template instead of
          Emakola.Themes.DefaultRenderers.#{page |> to_string() |> Macro.camelize()},
          silently stranding every buyer on that theme without the
          confirm/complain controls.

          If #{inspect(theme_module)} genuinely needs a custom #{page} page, it
          must render the shared protection strip itself (see
          Emakola.Themes.DefaultRenderers.Tracking's protection_strip/1) and
          this test's expectation should be revisited deliberately — not by
          accident.
          """
        end
      end
    end
  end
end
