defmodule EmakolaWeb.Storefront.PathTest do
  use ExUnit.Case, async: true
  alias EmakolaWeb.Storefront.Path, as: SP

  test "on the store's own subdomain, drops the /s/:slug prefix" do
    SP.put_on_store_subdomain(true)
    assert SP.store_path("tiny-stitches", "/cart") == "/cart"
    assert SP.store_path("tiny-stitches", "/products/abc") == "/products/abc"
    assert SP.store_path("tiny-stitches", "/") == "/"
  end

  test "on the apex (or another host), keeps /s/:slug" do
    SP.put_on_store_subdomain(false)
    assert SP.store_path("tiny-stitches", "/cart") == "/s/tiny-stitches/cart"
    assert SP.store_path("tiny-stitches", "/") == "/s/tiny-stitches"
  end

  test "defaults to apex form when the flag was never set" do
    assert SP.store_path("tiny-stitches", "/cart") == "/s/tiny-stitches/cart"
  end
end
