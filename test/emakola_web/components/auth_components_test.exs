defmodule EmakolaWeb.AuthComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "otp_code_input renders a numeric one-time-code field" do
    html = render_component(&EmakolaWeb.AuthComponents.otp_code_input/1, id: "otp")
    assert html =~ ~s(inputmode="numeric")
    assert html =~ ~s(autocomplete="one-time-code")
    assert html =~ ~s(maxlength="6")
  end

  test "phone_input defaults to the +233 country code" do
    html = render_component(&EmakolaWeb.AuthComponents.phone_input/1, id: "phone")
    assert html =~ "+233"
  end
end
