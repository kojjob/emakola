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
  @list_limit 200
  @recover_limit 20

  @doc "The most carts the merchant page (and count) will ever show at once."
  def list_limit, do: @list_limit

  @doc """
  Refuses a phone that fails `PhoneAuth.valid?/1` and writes nothing —
  independent of whatever the caller already checked, because this is the
  last line of defense on an unauthenticated write.
  """
  def touch(store_id, cart_session_id, %{phone: phone} = cart)
      when is_binary(store_id) and is_binary(cart_session_id) and is_binary(phone) do
    if PhoneAuth.valid?(phone) do
      AbandonedCheckout
      |> Ash.Changeset.for_create(:touch, %{
        store_id: store_id,
        cart_session_id: cart_session_id,
        phone: PhoneAuth.normalize(phone),
        name: cart |> Map.get(:name) |> cap_name(),
        items: Map.get(cart, :items, []),
        cart_total: Map.get(cart, :cart_total, 0)
      })
      |> Ash.create(authorize?: false)
    else
      {:error, :invalid_phone}
    end
  end

  # Buyer-typed free text, stored on an unauthenticated write — control
  # characters (newlines included) are stripped and the result capped, as a
  # safety net regardless of whether the caller already validated it.
  defp cap_name(nil), do: nil

  defp cap_name(name) do
    name
    |> String.replace(~r/[\p{Cc}]/u, "")
    |> String.slice(0, 255)
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

  # Bounded on both ends: a handful of rows, none older than the window the
  # merchant page shows. Bulk rather than a read-then-update loop, so a row
  # pruned between the read and the write is simply not matched by the
  # update statement instead of raising a stale-record error mid-checkout.
  defp recover_all(query, order_id) do
    query
    |> Ash.Query.filter(last_seen_at >= ^days_ago(@keep_days))
    |> Ash.Query.limit(@recover_limit)
    |> Ash.bulk_update(:recover, %{recovered_order_id: order_id},
      authorize?: false,
      return_errors?: false
    )

    :ok
  end

  def left_behind(store_id) do
    AbandonedCheckout
    |> Ash.Query.for_read(:left_behind, %{
      store_id: store_id,
      before: hours_ago(@settle_hours),
      after: days_ago(@keep_days)
    })
    |> Ash.Query.limit(@list_limit)
    |> Ash.read!(authorize?: false)
  end

  def count_left_behind(store_id) do
    AbandonedCheckout
    |> Ash.Query.for_read(:left_behind, %{
      store_id: store_id,
      before: hours_ago(@settle_hours),
      after: days_ago(@keep_days)
    })
    |> Ash.count!(authorize?: false)
  end

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
