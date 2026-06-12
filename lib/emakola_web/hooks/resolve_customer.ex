defmodule EmakolaWeb.Hooks.ResolveCustomer do
  @moduledoc """
  LiveView on_mount hook that resolves the current customer from session token.

  Looks for a `customer_token` in the session (set by CustomerSessionController),
  converts it back to a Customer resource via AshAuthentication, and assigns
  `@current_customer` to the socket. Assigns nil if no token or invalid token.
  """

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    with {:ok, subject} <- EmakolaWeb.AuthTokens.verify_subject(session["customer_token"]),
         {:ok, customer} <- AshAuthentication.subject_to_user(subject, Emakola.Customers.Customer) do
      {:cont, assign(socket, :current_customer, customer)}
    else
      _ -> {:cont, assign(socket, :current_customer, nil)}
    end
  end
end
