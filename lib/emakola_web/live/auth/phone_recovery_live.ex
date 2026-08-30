defmodule EmakolaWeb.Auth.PhoneRecoveryLive do
  @moduledoc """
  Get back into your shop with your phone number.

  Recovery used to require an email address, which most merchants here do not
  have — so losing a password meant losing the shop. Two steps: we send a
  code to the registered number, you type it and choose a new password.

  The page never says whether a number has an account. Telling the visitor
  would turn this form into a way to enumerate every merchant's phone number,
  so a known and an unknown number look identical from the outside.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Accounts.PhoneRecovery

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Recover with your phone",
       step: :phone,
       phone: nil,
       error: nil,
       form: to_form(%{"phone" => ""}, as: :recover)
     )}
  end

  @impl true
  def handle_event("send_code", %{"recover" => %{"phone" => phone}}, socket) do
    phone = String.trim(phone)

    # Always :ok, known number or not.
    :ok = PhoneRecovery.request_code(phone)

    {:noreply,
     assign(socket,
       step: :code,
       phone: phone,
       error: nil,
       form: to_form(%{"code" => "", "password" => ""}, as: :recover)
     )}
  end

  def handle_event("reset", %{"recover" => %{"code" => code, "password" => password}}, socket) do
    case PhoneRecovery.verify_and_reset(socket.assigns.phone, String.trim(code), password) do
      {:ok, _merchant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your password is changed. Sign in with it now.")
         |> push_navigate(to: ~p"/auth/login")}

      {:error, _reason} ->
        {:noreply, assign(socket, error: "That code is wrong or has expired. Ask for a new one.")}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-slate-50 px-4">
      <div class="w-full max-w-md bg-white rounded-card border border-border p-8">
        <div class="w-14 h-14 rounded-card bg-primary flex items-center justify-center mb-5">
          <.icon name="hero-device-phone-mobile" class="size-7 text-white" />
        </div>

        <h1 class="text-2xl font-bold text-slate-900">Use your phone</h1>

        <p :if={@step == :phone} class="text-sm text-slate-500 mt-2">
          We send a code to your number.
        </p>

        <p :if={@step == :code} class="text-sm text-slate-500 mt-2">
          Type the code we sent, and pick a new password.
        </p>

        <p :if={@error} class="mt-4 text-sm font-medium text-danger">{@error}</p>

        <.form
          :if={@step == :phone}
          for={@form}
          id="recover-phone-form"
          phx-submit="send_code"
          class="mt-6 space-y-4"
        >
          <.input field={@form[:phone]} label="Your phone number" placeholder="0201234567" />
          <.admin_button type="submit" class="w-full justify-center">Send me a code</.admin_button>
        </.form>

        <.form
          :if={@step == :code}
          for={@form}
          id="recover-code-form"
          phx-submit="reset"
          class="mt-6 space-y-4"
        >
          <.input field={@form[:code]} label="The code we sent" inputmode="numeric" />
          <.input field={@form[:password]} type="password" label="Your new password" />
          <.admin_button type="submit" class="w-full justify-center">
            Change my password
          </.admin_button>
        </.form>

        <p class="mt-6 text-sm text-slate-500">
          <.link navigate={~p"/auth/login"} class="font-semibold text-primary">Back to sign in</.link>
        </p>
      </div>
    </div>
    """
  end
end
