defmodule Emakola.Themes.HomeSectionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defmodule FakeSection do
    @behaviour Emakola.Themes.Section
    use Phoenix.Component
    def key, do: "fake/hero"
    def label, do: "Fake hero"

    def settings_schema,
      do: [
        %{key: "heading", type: :string, label: "Heading", default: ""},
        %{key: "cta_url", type: :link, label: "Button link", default: "/products"},
        %{key: "image", type: :image_url, label: "Image", default: ""}
      ]

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

  test "put_layout sanitizes: bad type dropped, bad color and padding stripped", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{"id" => "x", "type" => "not/registered", "enabled" => true},
      %{
        "id" => "y",
        "type" => "block/text_section",
        "enabled" => true,
        "settings" => %{"heading" => "ok"},
        "style" => %{"bg" => "url(javascript:x)", "padding" => "huge"}
      }
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [only] = HomeSections.saved_layout(updated, "starter")
    assert only["id"] == "y"
    assert only["style"] == %{}
    assert only["settings"] == %{"heading" => "ok"}
  end

  test "put_layout drops entries with a non-string type instead of crashing", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{"id" => "a", "type" => true, "enabled" => true},
      %{"id" => "b", "type" => 5, "enabled" => true},
      %{"id" => "c", "type" => %{"nested" => "map"}, "enabled" => true},
      %{"id" => "d", "type" => nil, "enabled" => true}
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert HomeSections.saved_layout(updated, "starter") == []
  end

  test "put_layout falls back to the type string when id is not a binary", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{"id" => %{"evil" => true}, "type" => "block/text_section", "enabled" => true},
      %{"id" => [1, 2], "type" => "block/spacer", "enabled" => true}
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [first, second] = HomeSections.saved_layout(updated, "starter")
    assert first["id"] == "block/text_section"
    assert second["id"] == "block/spacer"
  end

  test "settings text with colons survives (page-builder parity for block sections)", %{
    merchant: merchant,
    store: store
  } do
    entries = [
      %{
        "id" => "y",
        "type" => "block/text_section",
        "enabled" => true,
        "settings" => %{"heading" => "Sale: Ends Friday", "body" => "Open 9:00–18:00"}
      }
    ]

    assert {:ok, updated} = HomeSections.put_layout(merchant, store, "starter", entries)
    assert [only] = HomeSections.saved_layout(updated, "starter")
    assert only["settings"]["heading"] == "Sale: Ends Friday"
    assert only["settings"]["body"] == "Open 9:00–18:00"
  end

  # The registry resolves only "block/..." types until the theme fan-out
  # registers sectionized themes, so the schema-scoped URL rule is exercised
  # directly against the sanitizer with an explicit section module.
  test "sanitize_entry/2 drops non-http(s) values only in :image_url/:link-schema settings" do
    entry = %{
      "id" => "fake/hero",
      "type" => "fake/hero",
      "enabled" => true,
      "settings" => %{
        "heading" => "Sale: Ends Friday",
        "cta_url" => "javascript:alert(1)",
        "image" => "data:text/html,<script>x</script>"
      }
    }

    sanitized = HomeSections.sanitize_entry(entry, FakeSection)

    assert sanitized["settings"]["heading"] == "Sale: Ends Friday"
    refute Map.has_key?(sanitized["settings"], "cta_url")
    refute Map.has_key?(sanitized["settings"], "image")
  end

  test "sanitize_entry/2 keeps relative and http(s) values in URL-typed settings" do
    entry = %{
      "id" => "fake/hero",
      "type" => "fake/hero",
      "enabled" => true,
      "settings" => %{"cta_url" => "/products", "image" => "https://cdn.example.com/a.png"}
    }

    sanitized = HomeSections.sanitize_entry(entry, FakeSection)

    assert sanitized["settings"]["cta_url"] == "/products"
    assert sanitized["settings"]["image"] == "https://cdn.example.com/a.png"
  end

  test "put_layout and clear_layout reject unknown themes and the reserved envelope key", %{
    merchant: merchant,
    store: store
  } do
    assert {:error, :unknown_theme} = HomeSections.put_layout(merchant, store, "v", [])
    assert {:error, :unknown_theme} = HomeSections.put_layout(merchant, store, "no-such", [])
    assert {:error, :unknown_theme} = HomeSections.put_layout(merchant, store, :starter, [])
    assert {:error, :unknown_theme} = HomeSections.clear_layout(merchant, store, "v")
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
