defmodule Emakola.Themes.ThemeResolverSocialOverlayTest do
  @moduledoc """
  Pins the contract for `ThemeResolver.resolve/2` social URL overlay:

    * Without a store, returns the same shape as `resolve/1`
    * With a store, overlays its `instagram_url`/`tiktok_url`/etc onto
      `footer.social_links`
    * Nil and empty-string URL fields don't overwrite the theme defaults
    * Existing footer.social_links keys (twitter, etc.) survive when the
      store has no overlay for that key
  """
  use ExUnit.Case, async: true

  alias Emakola.Themes.ThemeResolver

  describe "resolve/2 — no store" do
    test "behaves identically to resolve/1" do
      assert ThemeResolver.resolve(%{"theme" => "atelier"}) ==
               ThemeResolver.resolve(%{"theme" => "atelier"}, nil)
    end

    test "footer.social_links is the theme default" do
      result = ThemeResolver.resolve(%{"theme" => "atelier"}, nil)
      # Atelier defaults to a social_links map (may be empty map of keys)
      assert is_map(result.footer.social_links)
    end
  end

  describe "resolve/2 — with store overlay" do
    test "overlays instagram_url onto footer.social_links.instagram" do
      store = %{
        instagram_url: "https://instagram.com/akosua_boutique",
        tiktok_url: nil,
        facebook_url: nil,
        youtube_url: nil,
        x_url: nil
      }

      result = ThemeResolver.resolve(%{"theme" => "atelier"}, store)
      assert result.footer.social_links.instagram == "https://instagram.com/akosua_boutique"
    end

    test "overlays all five platforms when set" do
      store = %{
        instagram_url: "https://instagram.com/store",
        tiktok_url: "https://tiktok.com/@store",
        facebook_url: "https://facebook.com/store",
        youtube_url: "https://youtube.com/@store",
        x_url: "https://x.com/store"
      }

      result = ThemeResolver.resolve(%{"theme" => "atelier"}, store)

      assert result.footer.social_links.instagram == "https://instagram.com/store"
      assert result.footer.social_links.tiktok == "https://tiktok.com/@store"
      assert result.footer.social_links.facebook == "https://facebook.com/store"
      assert result.footer.social_links.youtube == "https://youtube.com/@store"
      # X URL maps to the existing :twitter footer key (legacy footer naming)
      assert result.footer.social_links.twitter == "https://x.com/store"
    end

    test "nil URLs don't overwrite existing footer.social_links values" do
      # Theme config provides an explicit social_links override
      config = %{
        "theme" => "atelier",
        "footer" => %{
          "social_links" => %{instagram: "https://instagram.com/from_theme_config"}
        }
      }

      # Store has nil instagram_url — should NOT clear the theme_config value
      store = %{
        instagram_url: nil,
        tiktok_url: nil,
        facebook_url: nil,
        youtube_url: nil,
        x_url: nil
      }

      result = ThemeResolver.resolve(config, store)
      assert result.footer.social_links.instagram == "https://instagram.com/from_theme_config"
    end

    test "empty-string URLs don't overwrite either" do
      config = %{
        "theme" => "atelier",
        "footer" => %{
          "social_links" => %{instagram: "https://instagram.com/from_theme_config"}
        }
      }

      store = %{
        instagram_url: "",
        tiktok_url: nil,
        facebook_url: nil,
        youtube_url: nil,
        x_url: nil
      }

      result = ThemeResolver.resolve(config, store)
      assert result.footer.social_links.instagram == "https://instagram.com/from_theme_config"
    end
  end
end
