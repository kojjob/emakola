defmodule Emakola.Accounts.PhoneOtpTest do
  use Emakola.DataCase, async: true
  alias Emakola.Accounts.PhoneOtp

  test "issue stores an OTP and record_attempt increments atomically" do
    {:ok, otp} =
      PhoneOtp
      |> Ash.Changeset.for_create(:issue, %{
        phone: "+233501234567",
        code_hash: "hashed",
        purpose: :merchant,
        expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
      })
      |> Ash.create()

    assert otp.attempts == 0

    {:ok, otp} = otp |> Ash.Changeset.for_update(:record_attempt, %{}) |> Ash.update()
    assert otp.attempts == 1
  end
end
