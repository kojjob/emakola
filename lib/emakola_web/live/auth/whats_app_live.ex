defmodule EmakolaWeb.Auth.WhatsAppLive do
  use EmakolaWeb, :live_view
  import EmakolaWeb.AuthComponents
  alias Emakola.Accounts.{Merchant, PhoneAuth}
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, step: :phone, phone: nil, error: nil, page_title: "Sign in with WhatsApp"),
     layout: false}
  end

  @impl true
  def handle_event("send_code", %{"phone" => %{"cc" => cc, "number" => number}}, socket) do
    phone = PhoneAuth.normalize(cc <> number)

    case PhoneAuth.request_code(phone, :merchant) do
      :ok ->
        {:noreply, assign(socket, step: :code, phone: phone, error: nil)}

      {:error, :rate_limited} ->
        {:noreply, assign(socket, error: "Too many attempts. Try again in a minute.")}

      {:error, _} ->
        {:noreply, assign(socket, error: "Couldn't send a code. Please try again.")}
    end
  end

  def handle_event("verify_code", %{"otp" => %{"code" => code}}, socket) do
    case PhoneAuth.verify_code(socket.assigns.phone, code, :merchant) do
      :ok ->
        resolve(socket)

      {:error, :too_many_attempts} ->
        {:noreply, assign(socket, error: "Too many attempts. Request a new code.")}

      {:error, :expired} ->
        {:noreply, assign(socket, step: :phone, error: "Code expired. Please try again.")}

      {:error, _} ->
        {:noreply, assign(socket, error: "Invalid code.")}
    end
  end

  def handle_event("create_account", %{"merchant" => params}, socket) do
    case Ash.create(
           Ash.Changeset.for_create(Merchant, :register_with_phone, %{
             email: params["email"],
             name: params["name"],
             phone: socket.assigns.phone
           }),
           authorize?: false
         ) do
      {:ok, merchant} ->
        {:noreply, sign_in(socket, merchant)}

      {:error, _} ->
        {:noreply, assign(socket, error: "That email is already in use. Try signing in instead.")}
    end
  end

  def handle_event("resend", _params, socket) do
    PhoneAuth.request_code(socket.assigns.phone, :merchant)
    {:noreply, assign(socket, error: nil)}
  end

  # After OTP success: existing merchant signs in; new phone goes to the email step.
  defp resolve(socket) do
    case merchant_by_phone(socket.assigns.phone) do
      nil -> {:noreply, assign(socket, step: :email, error: nil)}
      merchant -> {:noreply, sign_in(socket, merchant)}
    end
  end

  defp merchant_by_phone(phone) do
    Merchant
    |> Ash.Query.filter(phone == ^phone)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, m} -> m
      _ -> nil
    end
  end

  defp sign_in(socket, merchant) do
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))
    redirect(socket, to: ~p"/auth/session?#{[token: token]}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#f7f8fa] px-4">
      <div class="w-full max-w-md bg-white rounded-2xl shadow-sm border border-gray-100 p-8">
        <h1 class="text-xl font-semibold text-[#0c1526] mb-6">Continue with WhatsApp</h1>

        <div
          :if={@error}
          class="mb-4 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
        >
          {@error}
        </div>

        <.form
          :if={@step == :phone}
          for={%{}}
          id="phone-form"
          phx-submit="send_code"
          class="space-y-4"
        >
          <label class="block text-sm font-medium text-[#0c1526]">Your WhatsApp number</label>
          <.phone_input id="wa-phone" />
          <button class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-white font-semibold py-3 rounded-xl text-sm">
            Send code
          </button>
        </.form>

        <.form
          :if={@step == :code}
          for={%{}}
          id="code-form"
          phx-submit="verify_code"
          class="space-y-4"
        >
          <label class="block text-sm font-medium text-[#0c1526]">Enter the 6-digit code</label>
          <.otp_code_input id="wa-code" />
          <button class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-white font-semibold py-3 rounded-xl text-sm">
            Verify
          </button>
          <button type="button" phx-click="resend" class="w-full text-[#2563eb] text-sm font-medium">
            Resend code
          </button>
        </.form>

        <.form
          :if={@step == :email}
          for={%{}}
          id="email-form"
          phx-submit="create_account"
          class="space-y-4"
        >
          <p class="text-sm text-[#5f6b7a]">Last step — your email (for receipts &amp; recovery).</p>
          <input
            type="email"
            name="merchant[email]"
            required
            placeholder="you@business.com"
            class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526]"
          />
          <input
            type="text"
            name="merchant[name]"
            placeholder="Your name (optional)"
            class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526]"
          />
          <button class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-white font-semibold py-3 rounded-xl text-sm">
            Create account
          </button>
        </.form>
      </div>
    </div>
    """
  end
end
