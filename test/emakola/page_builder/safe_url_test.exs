defmodule Emakola.PageBuilder.SafeUrlTest do
  use ExUnit.Case, async: true

  import Emakola.PageBuilder.SafeUrl

  test "passes absolute http(s) and site-relative urls unchanged" do
    assert safe_url("https://wa.me/233201234567") == "https://wa.me/233201234567"
    assert safe_url("http://example.com/a?b=1") == "http://example.com/a?b=1"
    assert safe_url("HTTPS://EXAMPLE.COM/X") == "HTTPS://EXAMPLE.COM/X"
    assert safe_url("/products") == "/products"

    assert safe_url("/s/tiny-stitches/products/kente-tote") ==
             "/s/tiny-stitches/products/kente-tote"

    assert safe_url("  https://wa.me/233201234567  ") == "https://wa.me/233201234567"
  end

  test "rejects executable and non-http schemes" do
    assert safe_url("javascript:alert(1)") == nil
    assert safe_url("JAVASCRIPT:alert(1)") == nil
    assert safe_url("data:text/html;base64,PHNjcmlwdD4=") == nil
    assert safe_url("vbscript:msgbox") == nil
    assert safe_url("file:///etc/passwd") == nil
    assert safe_url("mailto:x@y.com") == nil
    assert safe_url("tel:+233200000000") == nil
  end

  test "rejects smuggling shapes" do
    assert safe_url("  javascript:alert(1)") == nil
    assert safe_url("jav\tascript:alert(1)") == nil
    assert safe_url("//evil.example.com") == nil
    assert safe_url("products") == nil
    assert safe_url("/\\evil.com") == nil
    assert safe_url("/\\/evil.com") == nil
    assert safe_url("/\\\\evil.com/x?y=1") == nil
    assert safe_url("\\\\evil.com") == nil
    assert safe_url("\\/evil.com") == nil
  end

  test "rejects non-binaries and blanks" do
    assert safe_url(nil) == nil
    assert safe_url(123) == nil
    assert safe_url(%{}) == nil
    assert safe_url("") == nil
    assert safe_url("   ") == nil
  end
end
