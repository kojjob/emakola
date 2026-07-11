defmodule Emakola.Themes.SectionRendererTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (a
  # test-only seam shared with Sections.resolve/1 and HomeSections' theme
  # name validation) — must not run async with other tests touching it.
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import ExUnit.CaptureLog, only: [with_log: 1]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.{HomeSections, SectionRenderer}

  defmodule AlphaSection do
    @behaviour Emakola.Themes.Section
    use Phoenix.Component
    def key, do: "faketheme/alpha"
    def label, do: "Alpha"

    def settings_schema,
      do: [%{key: "heading", type: :string, label: "Heading", default: "Alpha default"}]

    def render(assigns) do
      ~H"""
      <section data-sec="alpha">{@settings["heading"]}</section>
      """
    end
  end

  defmodule BetaSection do
    @behaviour Emakola.Themes.Section
    use Phoenix.Component
    def key, do: "faketheme/beta"
    def label, do: "Beta"
    def settings_schema, do: []

    def render(assigns) do
      ~H"""
      <section data-sec="beta">B</section>
      """
    end
  end

  defmodule FakeTheme do
    # Canonical theme key (mirrors real theme modules' id/0).
    def id, do: "faketheme"
    def sections, do: [AlphaSection, BetaSection]
  end

  setup do
    # Test-only seam: lets the fake theme resolve through
    # Sections.resolve/1 and pass HomeSections' theme-name validation
    # without registering it as a real sectionized theme.
    Application.put_env(:emakola, :extra_sectionized_themes, [FakeTheme])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)

    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  defp render_home(store) do
    %{store: store, theme_module: FakeTheme, products: [], categories: [], __changed__: nil}
    |> SectionRenderer.home()
    |> rendered_to_string()
  end

  test "renders defaults in order with schema-default settings", %{store: store} do
    html = render_home(store)
    assert html =~ ~r/alpha.*beta/s
    assert html =~ "Alpha default"
    # Spec amendment (88963c2): unstyled entries render bare — no wrapper
    # divs — so default storefronts keep today's exact DOM.
    refute html =~ "data-section-id"
  end

  test "saved layout controls order, enabled, settings, and style wrapper", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true},
        %{
          "id" => "faketheme/alpha",
          "type" => "faketheme/alpha",
          "enabled" => true,
          "settings" => %{"heading" => "Custom heading"},
          "style" => %{"bg" => "#B45309", "padding" => "lg"}
        }
      ])

    html = render_home(store)
    assert html =~ ~r/beta.*alpha/s
    assert html =~ "Custom heading"
    assert html =~ "background-color: #B45309"
    assert html =~ "data-section-padding=\"lg\""
  end

  test "disabled sections are skipped", %{merchant: merchant, store: store} do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/alpha", "type" => "faketheme/alpha", "enabled" => false},
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    html = render_home(store)
    refute html =~ "alpha"
    assert html =~ "beta"
  end

  test "an unresolvable saved type is skipped without crashing", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    # Simulate a section removed from a later release: corrupt the saved type.
    config = store.theme_config

    entries =
      [%{"id" => "gone", "type" => "faketheme/removed", "enabled" => true}] ++
        get_in(config, ["home_sections", "faketheme"])

    store = %{store | theme_config: put_in(config, ["home_sections", "faketheme"], entries)}

    html = render_home(store)
    assert html =~ "beta"
  end

  test "non-map layout entries are skipped with a warning, never raise", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    # Simulate corruption from a write path that bypasses put_layout's
    # sanitizer (raw Ash update, migration): a bare string in the array.
    config = store.theme_config
    entries = ["oops" | get_in(config, ["home_sections", "faketheme"])]
    store = %{store | theme_config: put_in(config, ["home_sections", "faketheme"], entries)}

    {html, log} = with_log(fn -> render_home(store) end)

    assert html =~ "beta"
    assert log =~ "[sections] malformed layout entry"
  end

  test "corrupt nested entry fields are normalized instead of raising", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    # Same bypass-the-sanitizer corruption class as the bare-string entry,
    # one level deeper: a resolvable entry whose nested fields are junk.
    corrupt = %{
      "id" => %{},
      "type" => "faketheme/alpha",
      "enabled" => true,
      "style" => "x",
      "settings" => "x"
    }

    config = store.theme_config
    entries = [corrupt | get_in(config, ["home_sections", "faketheme"])]
    store = %{store | theme_config: put_in(config, ["home_sections", "faketheme"], entries)}

    html = render_home(store)

    # Normalized: settings fall back to schema defaults; the normalized
    # (empty) style means no wrapper is emitted (spec amendment 88963c2).
    assert html =~ "Alpha default"
    refute html =~ "data-section-id"
    assert html =~ "beta"
  end

  test "a well-formed style map with scalar junk is sanitized instead of raising", %{
    merchant: merchant,
    store: store
  } do
    {:ok, store} =
      HomeSections.put_layout(merchant, store, "faketheme", [
        %{"id" => "faketheme/beta", "type" => "faketheme/beta", "enabled" => true}
      ])

    # Same bypass-the-sanitizer corruption class as the tests above, one
    # level narrower: the style map itself is well-formed, but "bg" holds a
    # nested map instead of a scalar. `is_map(style) == true` alone doesn't
    # catch this — the crash is at interpolation ("background-color: #{...}"),
    # which String.Chars can't do for a Map.
    corrupt = %{
      "id" => "faketheme/alpha",
      "type" => "faketheme/alpha",
      "enabled" => true,
      "settings" => %{},
      "style" => %{"bg" => %{"x" => 1}}
    }

    config = store.theme_config
    entries = [corrupt | get_in(config, ["home_sections", "faketheme"])]
    store = %{store | theme_config: put_in(config, ["home_sections", "faketheme"], entries)}

    html = render_home(store)

    assert html =~ "Alpha default"
    refute html =~ "background-color"
    assert html =~ "beta"
  end
end
