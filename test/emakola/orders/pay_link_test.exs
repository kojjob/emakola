defmodule Emakola.Orders.PayLinkTest do
  use Emakola.DataCase, async: true

  alias Emakola.Orders.PayLink

  defp create!(store, attrs) do
    PayLink
    |> Ash.Changeset.for_create(:create, Map.put(attrs, :store_id, store.id))
    |> Ash.create!(authorize?: false)
  end

  test "custom link gets an 8-char code, active status, 7-day default expiry" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    assert String.match?(link.code, ~r/^[a-z2-7]{8}$/)
    assert link.status == :active
    assert_in_delta DateTime.diff(link.expires_at, DateTime.utc_now(), :day), 7, 1
  end

  test "catalog link has no default expiry and keeps its variant" do
    store = Emakola.Factory.create_store!()
    product = Emakola.Factory.create_product!(store)
    variant = Emakola.Factory.create_variant!(product, store)
    link = create!(store, %{type: :catalog, variant_id: variant.id})

    assert link.expires_at == nil
    assert link.variant_id == variant.id
  end

  test "custom link requires amount >= 100" do
    store = Emakola.Factory.create_store!()

    assert {:error, %Ash.Error.Invalid{}} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{
               store_id: store.id,
               type: :custom,
               title: "Deal",
               amount: 99
             })
             |> Ash.create(authorize?: false)
  end

  test "catalog link requires variant_id; custom requires title+amount" do
    store = Emakola.Factory.create_store!()

    assert {:error, _} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{store_id: store.id, type: :catalog})
             |> Ash.create(authorize?: false)

    assert {:error, _} =
             PayLink
             |> Ash.Changeset.for_create(:create, %{store_id: store.id, type: :custom})
             |> Ash.create(authorize?: false)
  end

  test "usable?/1 covers active, expired, cancelled, consumed" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})
    assert :ok = PayLink.usable?(link)

    expired = %{link | expires_at: DateTime.add(DateTime.utc_now(), -1, :day)}
    assert {:error, :expired} = PayLink.usable?(expired)

    assert {:error, :cancelled} = PayLink.usable?(%{link | status: :cancelled})
    assert {:error, :consumed} = PayLink.usable?(%{link | status: :paid})
  end

  test "tenant isolation: store B cannot read store A's link by code" do
    store_a = Emakola.Factory.create_store!()
    store_b = Emakola.Factory.create_store!()
    link = create!(store_a, %{type: :custom, title: "Deal", amount: 25_000})

    assert {:ok, []} =
             PayLink
             |> Ash.Query.for_read(:get_by_code, %{code: link.code})
             |> Ash.Query.set_tenant(store_b.id)
             |> Ash.read(authorize?: false)
  end

  test "increment_opened bumps the counter" do
    store = Emakola.Factory.create_store!()
    link = create!(store, %{type: :custom, title: "Deal", amount: 25_000})

    updated =
      link
      |> Ash.Changeset.for_update(:increment_opened, %{})
      |> Ash.update!(authorize?: false)

    assert updated.opened_count == 1
  end
end
