defmodule EmakolaWeb.Hooks.ResolveCustomer do
  @moduledoc """
  LiveView on_mount hook that resolves the current customer from session token.

  Looks for a `customer_token` in the session (set by CustomerSessionController),
  converts it back to a Customer resource via AshAuthentication, and assigns
  `@current_customer` to the socket. Assigns nil if no token or invalid token.
  """

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    customer_token = session["customer_token"]

    if customer_token do
      case AshAuthentication.subject_to_user(customer_token, Emakola.Customers.Customer) do
        {:ok, customer} ->
          {:cont, assign(socket, :current_customer, customer)}

        _ ->
          {:cont, assign(socket, :current_customer, nil)}
      end
    else
      {:cont, assign(socket, :current_customer, nil)}
    end
  end
end
