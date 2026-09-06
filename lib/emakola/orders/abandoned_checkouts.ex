defmodule Emakola.Orders.AbandonedCheckouts do
  @moduledoc """
  Carts left behind: remember who typed a phone and left, and hand the
  merchant a WhatsApp link. No automated sends.
  """

  require Ash.Query

  alias Emakola.Accounts.PhoneAuth
  alias Emakola.Orders.AbandonedCheckout

  @settle_hours 2
  @keep_days 7

  def touch(store_id, cart_session_id, %{phone: phone} = cart)
      when is_binary(store_id) and is_binary(cart_session_id) and is_binary(phone) do
    AbandonedCheckout
    |> Ash.Changeset.for_create(:touch, %{
      store_id: store_id,
      cart_session_id: cart_session_id,
      phone: PhoneAuth.normalize(phone),
      name: Map.get(cart, :name),
      items: Map.get(cart, :items, []),
      cart_total: Map.get(cart, :cart_total, 0)
    })
    |> Ash.create(authorize?: false)
  end

  def recover(store_id, cart_session_id, order_id) do
    AbandonedCheckout
    |> Ash.Query.filter(
      store_id == ^store_id and cart_session_id == ^cart_session_id and is_nil(recovered_at)
    )
    |> recover_all(order_id)
  end

  def recover_by_phone(store_id, phone, order_id) do
    phone = PhoneAuth.normalize(phone)

    AbandonedCheckout
    |> Ash.Query.filter(store_id == ^store_id and phone == ^phone and is_nil(recovered_at))
    |> recover_all(order_id)
  end

  defp recover_all(query, order_id) do
    query
    |> Ash.read!(authorize?: false)
    |> Enum.each(fn checkout ->
      checkout
      |> Ash.Changeset.for_update(:recover, %{recovered_order_id: order_id})
      |> Ash.update!(authorize?: false)
    end)

    :ok
  end

  def left_behind(store_id) do
    Emakola.Orders.list_left_behind!(store_id, hours_ago(@settle_hours), days_ago(@keep_days),
      authorize?: false
    )
  end

  def count_left_behind(store_id), do: store_id |> left_behind() |> length()

  @doc "A wa.me link with the message ready to send."
  def whatsapp_url(checkout, store) do
    digits = String.replace(checkout.phone, ~r/\D/, "")
    items = checkout.items |> Enum.map(& &1["title"]) |> Enum.reject(&is_nil/1) |> Enum.join(", ")
    name = if checkout.name in [nil, ""], do: "there", else: checkout.name

    text =
      "Hello #{name}, you left #{items} in your cart at #{store.name}. Reply here and I will finish it for you."

    "https://wa.me/#{digits}?text=#{URI.encode_www_form(text)}"
  end

  defp hours_ago(hours), do: DateTime.add(DateTime.utc_now(), -hours * 3600, :second)
  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
end
