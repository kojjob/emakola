defmodule EmakolaWeb.StorefrontComponents.DmButtonTest do
  @moduledoc """
  Pins the contract for the click-to-DM helpers + button:

    * `instagram_dm_url/1` extracts handle from common URL forms,
      builds ig.me/m/<handle>
    * `tiktok_dm_url/1` extracts handle, builds tiktok.com/@<handle>
    * Both return nil for nil/empty/non-platform URLs
    * `dm_button/1` renders nothing when url is nil/empty
    * `dm_button/1` renders the platform-specific styling per variant
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "instagram_dm_url/1" do
    test "extracts handle from canonical URL" do
      assert "https://ig.me/m/akosua_boutique" ==
               instagram_dm_url("https://instagram.com/akosua_boutique")
    end

    test "handles trailing slash" do
      assert "https://ig.me/m/akosua_boutique" ==
               instagram_dm_url("https://www.instagram.com/akosua_boutique/")
    end

    test "handles query params" do
      assert "https://ig.me/m/akosua_boutique" ==
               instagram_dm_url("https://instagram.com/akosua_boutique?hl=en")
    end

    test "returns nil for non-Instagram URLs" do
      assert nil == instagram_dm_url("https://twitter.com/store")
    end

    test "returns nil for nil and empty" do
      assert nil == instagram_dm_url(nil)
      assert nil == instagram_dm_url("")
    end

    test "returns nil when path has no handle" do
      assert nil == instagram_dm_url("https://instagram.com/")
    end
  end

  describe "tiktok_dm_url/1" do
    test "extracts handle with @ prefix from URL" do
      assert "https://www.tiktok.com/@store_name" ==
               tiktok_dm_url("https://tiktok.com/@store_name")
    end

    test "handles trailing slash" do
      assert "https://www.tiktok.com/@store_name" ==
               tiktok_dm_url("https://www.tiktok.com/@store_name/")
    end

    test "returns nil for non-TikTok URLs" do
      assert nil == tiktok_dm_url("https://instagram.com/store")
    end

    test "returns nil for nil and empty" do
      assert nil == tiktok_dm_url(nil)
      assert nil == tiktok_dm_url("")
    end
  end

  describe "dm_button/1" do
    test "renders empty when url is nil" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dm_button url={nil} variant={:instagram} />
        """)

      assert html == ""
    end

    test "renders empty when url is empty string" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dm_button url="" variant={:tiktok} />
        """)

      assert html == ""
    end

    test "Instagram variant uses gradient + correct label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dm_button url="https://ig.me/m/store" variant={:instagram} />
        """)

      assert html =~ ~s(href="https://ig.me/m/store")
      assert html =~ "Instagram DM"
      assert html =~ "from-instagram-orange"
    end

    test "TikTok variant uses black bg" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dm_button url="https://www.tiktok.com/@store" variant={:tiktok} />
        """)

      assert html =~ "TikTok"
      assert html =~ "bg-black"
    end

    test "WhatsApp variant uses WhatsApp green" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dm_button url="https://wa.me/233241234567" variant={:whatsapp} />
        """)

      assert html =~ "bg-whatsapp"
    end

    test "label override" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.dm_button url="https://ig.me/m/store" variant={:instagram} label="Chat" />
        """)

      assert html =~ ~r/>\s*Chat\s*</
      assert html =~ ~s(aria-label="Message on Chat")
    end
  end
end
