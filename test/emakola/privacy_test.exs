defmodule Emakola.PrivacyTest do
  use ExUnit.Case, async: true

  alias Emakola.Privacy

  describe "mask_phone/1" do
    test "retains only a country hint and final four digits" do
      phone = "+233 244 123 456"
      masked = Privacy.mask_phone(phone)

      assert masked == "+233****3456"
      refute masked =~ "244123456"
    end

    test "fully redacts short or absent values" do
      assert Privacy.mask_phone("1234") == "[redacted]"
      assert Privacy.mask_phone(nil) == "[redacted]"
      assert Privacy.mask_phone(%{phone: "+233244123456"}) == "[redacted]"
    end
  end

  describe "mask_email/1" do
    test "retains one local-part character and the domain" do
      email = "ama.boateng@example.com"
      masked = Privacy.mask_email(email)

      assert masked == "a***@example.com"
      refute masked == email
      refute masked =~ "ama.boateng"
    end

    test "fully redacts invalid values" do
      assert Privacy.mask_email("not-an-email") == "[redacted]"
      assert Privacy.mask_email(nil) == "[redacted]"
      assert Privacy.mask_email(%{email: "ama@example.com"}) == "[redacted]"
    end
  end

  test "error_type/1 never serialises arbitrary details" do
    assert Privacy.error_type(%{token: "secret", email: "ama@example.com"}) == "unknown"
    assert Privacy.error_type({:timeout, %{token: "secret"}}) == "timeout"
  end

  test "safe labels and UUIDs reject arbitrary values" do
    assert Privacy.safe_label("order_placed") == "order_placed"
    assert Privacy.safe_label("ama@example.com") == "invalid"
    assert Privacy.safe_uuid("7c6f2ad0-a185-4bd2-984f-71ca22ff8b40") =~ "7c6f2ad0"
    assert Privacy.safe_uuid("bearer-secret") == "unknown"
  end
end
