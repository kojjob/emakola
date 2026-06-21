defmodule EmakolaWeb.Storefront.PathTest do
  use ExUnit.Case, async: true
  alias EmakolaWeb.Storefront.Path, as: SP

  test "on the store's own subdomain, drops the /s/:slug prefix" do
    assigns = %{on_store_subdomain?: true, store: %{slug: "tiny-stitches"}}
    assert SP.store_path(assigns, "/cart") == "/cart"
    assert SP.store_path(assigns, "/products/abc") == "/products/abc"
    assert SP.store_path(assigns, "/") == "/"
  end

  test "on the apex (or another host), keeps /s/:slug" do
    assigns = %{on_store_subdomain?: false, store: %{slug: "tiny-stitches"}}
    assert SP.store_path(assigns, "/cart") == "/s/tiny-stitches/cart"
    assert SP.store_path(assigns, "/") == "/s/tiny-stitches"
  end
end
