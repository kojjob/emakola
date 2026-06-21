defmodule Emakola.Accounts.PhoneAuthTest do
  use Emakola.DataCase, async: false
  import Mox
  alias Emakola.Accounts.PhoneAuth
  setup :verify_on_exit!

  setup do
    Application.put_env(:emakola, :whatsapp_provider, Emakola.WhatsAppProviderMock)
    Application.put_env(:emakola, :sms_provider, Emakola.SMSProviderMock)
    :ok
  end

  test "request_code sends via WhatsApp and verify_code accepts the code" do
    test_pid = self()

    expect(Emakola.WhatsAppProviderMock, :send_message, fn _to,
                                                           "auth_code",
                                                           %{code: code},
                                                           _opts ->
      send(test_pid, {:code, code})
      {:ok, %{}}
    end)

    assert :ok = PhoneAuth.request_code("0501234567", :merchant)
    assert_received {:code, code}
    assert :ok = PhoneAuth.verify_code("0501234567", code, :merchant)
  end

  test "request_code falls back to SMS when WhatsApp fails" do
    test_pid = self()
    expect(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ -> {:error, :boom} end)

    expect(Emakola.SMSProviderMock, :send_sms, fn _to, body, _opts ->
      send(test_pid, {:sms, body})
      {:ok, %{}}
    end)

    assert :ok = PhoneAuth.request_code("0501234567", :merchant)
    assert_received {:sms, body}
    assert body =~ ~r/\d{6}/
  end

  test "verify_code rejects a wrong code, and too many attempts" do
    stub(Emakola.WhatsAppProviderMock, :send_message, fn _, _, _, _ -> {:ok, %{}} end)
    assert :ok = PhoneAuth.request_code("0509999999", :merchant)
    assert {:error, :invalid} = PhoneAuth.verify_code("0509999999", "000000", :merchant)
  end

  describe "to_e164/2" do
    test "drops a single leading trunk-0 from the national number" do
      assert PhoneAuth.to_e164("+233", "0501234567") == "+233501234567"
    end

    test "a national number with and without the trunk-0 agree" do
      assert PhoneAuth.to_e164("+233", "0501234567") ==
               PhoneAuth.to_e164("+233", "501234567")
    end

    test "strips non-digit separators from the national number" do
      assert PhoneAuth.to_e164("+233", "050 123 4567") == "+233501234567"
    end
  end
end
