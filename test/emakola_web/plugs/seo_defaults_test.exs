defmodule EmakolaWeb.Plugs.SEODefaultsTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias EmakolaWeb.Plugs.SEODefaults

  describe "init/1" do
    test "passes options through" do
      assert SEODefaults.init([]) == []
    end
  end

  describe "call/2" do
    test "sets default SEO assigns" do
      conn =
        conn(:get, "/@test-store/products")
        |> SEODefaults.call([])

      assert conn.assigns[:page_title] == nil
      assert conn.assigns[:meta_description] == nil
      assert conn.assigns[:og_image] == nil
      assert conn.assigns[:canonical_url] == nil
      assert conn.assigns[:robots] == "index, follow"
      assert conn.assigns[:json_ld] == nil
    end

    test "does not override existing assigns" do
      conn =
        conn(:get, "/@test-store/products")
        |> Plug.Conn.assign(:page_title, "Already Set")
        |> Plug.Conn.assign(:robots, "noindex")
        |> SEODefaults.call([])

      assert conn.assigns[:page_title] == "Already Set"
      assert conn.assigns[:robots] == "noindex"
    end
  end
end
