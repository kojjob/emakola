defmodule Emakola.Themes.HomeSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defmodule FakeSection do
    @behaviour Emakola.Themes.Section
    use Phoenix.Component
    def key, do: "fake/hero"
    def label, do: "Fake hero"
    def settings_schema, do: [%{key: "heading", type: :string, label: "Heading", default: ""}]
    def render(assigns), do: ~H"<div>fake</div>"
  end

  defmodule FakeTheme do
    # Canonical theme key (mirrors real theme modules' id/0, e.g. Starter.id/0
    # == "starter" — the key ThemeResolver/theme_config store under "theme").
    def id, do: "fake"
    def sections, do: [Emakola.Themes.HomeSectionsTest.FakeSection]
  end

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  test "default_layout builds enabled entries with the key as id" do
    assert [entry] = HomeSections.default_layout(FakeTheme)
    assert entry["id"] == "fake/hero"
    assert entry["type"] == "fake/hero"
    assert entry["enabled"] == true
  end

  test "effective_layout falls back to defaults when nothing is saved", %{store: store} do
    assert HomeSections.effective_layout(store, FakeTheme) ==
             HomeSections.default_layout(FakeTheme)
  end

  test "put_layout persists per-theme and effective_layout returns it", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{
        "id" => "fake/hero",
        "type" => "block/text_section",
        "enabled" => false,
        "settings" => %{"heading" => "Hi"},
        "style" => %{"bg" => "#FFF7ED", "padding" => "md"}
      }
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [saved] = HomeSections.saved_layout(updated, "starter")
    assert saved["enabled"] == false
    assert saved["style"]["bg"] == "#FFF7ED"

    # Other themes are untouched.
    assert HomeSections.saved_layout(updated, "atelier") == nil
  end

  test "put_layout sanitizes: bad type, bad color, bad padding, bad url", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{"id" => "x", "type" => "not/registered", "enabled" => true},
      %{
        "id" => "y",
        "type" => "block/text_section",
        "enabled" => true,
        "settings" => %{"heading" => "ok", "image" => "javascript:alert(1)"},
        "style" => %{"bg" => "url(javascript:x)", "padding" => "huge"}
      }
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [only] = HomeSections.saved_layout(updated, "starter")
    assert only["id"] == "y"
    assert only["style"] == %{}
    refute Map.has_key?(only["settings"], "image")
  end

  test "cross-store actors are forbidden", %{store: store} do
    {stranger, _} = create_merchant_with_store!()
    assert {:error, :forbidden} = HomeSections.put_layout(stranger, store, "starter", [])
  end

  test "clear_layout removes the saved layout for a theme", %{
    merchant: merchant,
    store: store
  } do
    entries = [%{"id" => "fake/hero", "type" => "block/text_section", "enabled" => true}]
    assert {:ok, store} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [_saved] = HomeSections.saved_layout(store, "starter")

    assert {:ok, cleared} = HomeSections.clear_layout(merchant, store, "starter")
    assert HomeSections.saved_layout(cleared, "starter") == nil
  end
end
