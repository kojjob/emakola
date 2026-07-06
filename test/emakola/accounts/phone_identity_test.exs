defmodule Emakola.Accounts.PhoneIdentityTest do
  use Emakola.DataCase, async: true

  alias Emakola.Accounts.Merchant

  test "two merchants cannot share a non-null phone" do
    {:ok, _} = Emakola.Factory.create_merchant!(phone: "+233501112222") |> then(&{:ok, &1})

    # Second merchant exists email-only; setting the duplicate phone must be
    # rejected by the unique_phone identity. Use the non-bang path so the
    # rejection surfaces as {:error, %Ash.Error.Invalid{}}.
    other = Emakola.Factory.create_merchant!()

    assert {:error, %Ash.Error.Invalid{}} =
             other
             |> Ash.Changeset.for_update(:update_profile, %{phone: "+233501112222"})
             |> Ash.update(authorize?: false)
  end

  test "many merchants may have a null phone" do
    {:ok, _} = Emakola.Factory.create_merchant!() |> then(&{:ok, &1})
    {:ok, _} = Emakola.Factory.create_merchant!() |> then(&{:ok, &1})

    assert Ash.count!(Merchant, authorize?: false) >= 2
  end
end
