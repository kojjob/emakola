defmodule EmakolaWeb.Storefront.CheckoutIdentity do
  @moduledoc """
  Who a storefront order belongs to.

  A signed-in buyer is themselves. A guest is found or created from the phone
  they typed, exactly as pay links already do; before this, every guest order
  was created with no customer and the customers page described only the
  buyers who had made an account.
  """

  alias Emakola.Orders.CheckoutService

  @spec opts(map()) :: keyword()
  def opts(%{current_customer: %{id: customer_id}}) when is_binary(customer_id),
    do: [customer_id: customer_id]

  def opts(%{phone: phone, fullname: fullname} = assigns) do
    case presence(phone) do
      # A blank phone normalises to the bare country code ("+233"), which
      # would find-or-create the SAME customer for every guest who typed
      # none — merging unrelated buyers. No phone, no customer lookup.
      nil ->
        []

      phone ->
        phone = Emakola.Accounts.PhoneAuth.normalize(phone)

        email =
          presence(Map.get(assigns, :email)) || CheckoutService.phone_placeholder_email(phone)

        [customer_email: email, customer_name: fullname, customer_phone: phone]
    end
  end

  defp presence(nil), do: nil

  defp presence(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: value)
end
