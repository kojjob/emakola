defmodule Emakola.Notifications.DeviceTokenTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Notifications.DeviceToken

  defp register!(merchant, store, attrs) do
    DeviceToken
    |> Ash.Changeset.for_create(:register, attrs, actor: merchant, tenant: store.id)
    |> Ash.create!()
  end

  test "register creates a device token owned by the actor" do
    {merchant, store} = create_merchant_with_store!()

    dt = register!(merchant, store, %{platform: :android, token: "fcm-token-1"})

    assert dt.merchant_id == merchant.id
    assert dt.store_id == store.id
    assert dt.platform == :android
    assert Emakola.Security.FieldEncryption.encrypted?(dt.token_encrypted)
    assert String.starts_with?(dt.token_blind_index, "emkidx.v1.test-lookup-v1.")
    assert {:ok, "fcm-token-1"} = Emakola.Security.SecretStorage.device_token(dt)
    assert %DateTime{} = dt.last_seen_at
  end

  test "re-registering the same token upserts (no duplicate) and refreshes ownership" do
    {merchant_a, store} = create_merchant_with_store!()
    merchant_b = create_merchant!()
    create_store_membership!(merchant_b, store, :staff)

    dt1 = register!(merchant_a, store, %{platform: :android, token: "shared-device"})
    dt2 = register!(merchant_b, store, %{platform: :android, token: "shared-device"})

    assert dt2.id == dt1.id
    assert dt2.merchant_id == merchant_b.id
    assert dt2.token_encrypted == dt1.token_encrypted
    assert dt2.token_blind_index == dt1.token_blind_index
    assert {:ok, "shared-device"} = Emakola.Security.SecretStorage.device_token(dt2)

    all = Ash.read!(DeviceToken, authorize?: false, tenant: store.id)
    assert length(all) == 1
  end

  test "merchant cannot register a token into a store they don't belong to" do
    {_merchant_a, store} = create_merchant_with_store!()
    outsider = create_merchant!()

    assert_raise Ash.Error.Forbidden, fn ->
      register!(outsider, store, %{platform: :android, token: "evil"})
    end
  end
end
