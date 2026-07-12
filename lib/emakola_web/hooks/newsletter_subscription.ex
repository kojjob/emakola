defmodule EmakolaWeb.Hooks.NewsletterSubscription do
  @moduledoc """
  LiveView on_mount hook that handles the `subscribe_newsletter` event fired
  by theme newsletter forms (home sections and footers).

  The forms are theme chrome rendered across many storefront LiveViews, so a
  single attached `handle_event` hook serves every LiveView in the storefront
  live_sessions instead of each module implementing its own handler.

  Must be mounted after ResolveStore / ResolveStoreFromHost — the subscription
  is scoped to the store in `socket.assigns.store`, never to client params.
  """

  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    {:cont, attach_hook(socket, :subscribe_newsletter, :handle_event, &handle_subscribe/3)}
  end

  defp handle_subscribe("subscribe_newsletter", %{"email" => email}, socket)
       when is_binary(email) do
    result =
      Emakola.Customers.subscribe_to_newsletter(
        %{email: String.trim(email), store_id: socket.assigns.store.id},
        authorize?: false
      )

    socket =
      case result do
        {:ok, _subscriber} ->
          put_flash(socket, :info, "Thanks for subscribing! You're on the list.")

        {:error, %Ash.Error.Invalid{}} ->
          put_flash(socket, :error, "Please enter a valid email address.")

        {:error, _error} ->
          put_flash(socket, :error, "Something went wrong. Please try again.")
      end

    {:halt, socket}
  end

  defp handle_subscribe("subscribe_newsletter", _params, socket) do
    {:halt, put_flash(socket, :error, "Please enter a valid email address.")}
  end

  defp handle_subscribe(_event, _params, socket), do: {:cont, socket}
end
