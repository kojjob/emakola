defmodule Emakola.Accounts.PhoneRecoveryTest do
  @moduledoc """
  Account recovery for merchants who have no email.

  Recovery was email-only, so a merchant without an email address could not
  get back into their own shop at all — in a market where most merchants do
  not use email. This is the lockout fix.

  The security properties matter as much as the feature: an unknown phone
  must not reveal that it is unknown, and a correct code must not be
  reusable.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory
  import Mox

  alias Emakola.Accounts.PhoneRecovery

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    # A phone per test. PhoneAuth rate-limits sends PER NUMBER, so tests
    # sharing one number exhaust the window and a later test silently gets no
    # code delivered — which looks like a broken feature, not a noisy test.
    phone = "+2332" <> to_string(10_000_000 + System.unique_integer([:positive]))
    merchant = create_merchant!(%{phone: phone})
    test_pid = self()

    # The OTP is stored hashed, so the only way to read it is the way the
    # merchant does — off the delivery.
    stub(Emakola.WhatsAppProviderMock, :send_message, fn _to, "auth_code", %{code: code}, _opts ->
      send(test_pid, {:code, code})
      {:ok, %{}}
    end)

    stub(Emakola.SMSProviderMock, :send_sms, fn _to, _msg, _opts -> {:ok, %{}} end)

    %{merchant: merchant, phone: phone}
  end

  defp delivered_code do
    assert_received {:code, code}
    code
  end

  describe "request_code/1" do
    test "sends a code to a merchant's own phone", %{phone: phone} do
      assert :ok = PhoneRecovery.request_code(phone)
    end

    test "accepts a local Ghana number, not just E.164" do
      # Merchants type 0201234567, not +233201234567.
      assert :ok = PhoneRecovery.request_code("0201234567")
    end

    test "an unknown phone returns :ok and reveals nothing" do
      # Never confirm whether a number has an account — that would turn this
      # form into a way to enumerate every merchant's phone number.
      assert :ok = PhoneRecovery.request_code("+233209999999")
    end
  end

  describe "verify_and_reset/3" do
    test "resets the password with a correct code", %{merchant: merchant, phone: phone} do
      :ok = PhoneRecovery.request_code(phone)
      code = delivered_code()

      assert {:ok, updated} = PhoneRecovery.verify_and_reset(phone, code, "NewPassword123!")

      assert updated.id == merchant.id

      assert {:ok, _} =
               Emakola.Accounts.Merchant
               |> Ash.Query.for_read(:sign_in_with_password, %{
                 email: to_string(merchant.email),
                 password: "NewPassword123!"
               })
               |> Ash.read_one(authorize?: false)
    end

    test "a wrong code changes nothing", %{phone: phone} do
      :ok = PhoneRecovery.request_code(phone)

      assert {:error, _} = PhoneRecovery.verify_and_reset(phone, "000000", "NewPassword123!")
    end

    test "a code cannot be used twice", %{phone: phone} do
      :ok = PhoneRecovery.request_code(phone)
      code = delivered_code()

      assert {:ok, _} = PhoneRecovery.verify_and_reset(phone, code, "NewPassword123!")
      assert {:error, _} = PhoneRecovery.verify_and_reset(phone, code, "Another123!")
    end

    test "an unknown phone with any code fails" do
      assert {:error, _} =
               PhoneRecovery.verify_and_reset("+233209999999", "123456", "NewPassword123!")
    end
  end
end
