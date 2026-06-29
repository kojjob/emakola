defmodule EmakolaWeb.Storefront.CustomerWhatsAppLive do
  @moduledoc """
  Store-scoped customer WhatsApp phone-OTP sign-in.

  Mirrors the merchant flow (`EmakolaWeb.Auth.WhatsAppLive`) but every PhoneAuth
  and Ash call is scoped to the current store: `purpose: :customer`, the store id
  in `:store_id`, and `tenant: @store.id` for customer reads/creates. On success
  it mints a `:customer_token` session via the customer-session controller.
  """
  use EmakolaWeb, :live_view
  import EmakolaWeb.AuthComponents
  import EmakolaWeb.Storefront.Path
  alias Emakola.Accounts.PhoneAuth
  alias Emakola.Customers.Customer
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       step: :phone,
       phone: nil,
       phone_verified: false,
       error: nil,
       page_title: "Sign in with WhatsApp"
     )}
  end

  @impl true
  def handle_event("send_code", %{"phone" => %{"cc" => cc, "number" => number}}, socket) do
    phone = PhoneAuth.to_e164(cc, number)
    store = socket.assigns.store

    case PhoneAuth.request_code(phone, :customer, store_id: store.id) do
      :ok ->
        {:noreply, assign(socket, step: :code, phone: phone, phone_verified: false, error: nil)}

      {:error, :rate_limited} ->
        {:noreply, assign(socket, error: "Too many attempts. Try again in a minute.")}

      {:error, _} ->
        {:noreply, assign(socket, error: "Couldn't send a code. Please try again.")}
    end
  end

  def handle_event("verify_code", %{"otp" => %{"code" => code}}, socket) do
    store = socket.assigns.store

    case PhoneAuth.verify_code(socket.assigns.phone, code, :customer, store_id: store.id) do
      :ok ->
        resolve(socket)

      {:error, :too_many_attempts} ->
        Emakola.Security.record(%{
          event_type: :auth_failed,
          subject_type: :customer,
          identifier: socket.assigns.phone,
          metadata: %{"reason" => "too_many_attempts"}
        })

        {:noreply, assign(socket, error: "Too many attempts. Request a new code.")}

      {:error, :expired} ->
        {:noreply, assign(socket, step: :phone, error: "Code expired. Please try again.")}

      {:error, _} ->
        Emakola.Security.record(%{
          event_type: :auth_failed,
          subject_type: :customer,
          identifier: socket.assigns.phone
        })

        {:noreply, assign(socket, error: "Invalid code.")}
    end
  end

  def handle_event("create_account", %{"customer" => params}, socket) do
    store = socket.assigns.store

    # Events dispatch regardless of the rendered step, so the verified-phone
    # check must live here (not in the template) or an unverified phone could
    # be registered by a scripted client.
    if socket.assigns.phone_verified do
      case Ash.create(
             Ash.Changeset.for_create(
               Customer,
               :register_with_phone,
               %{
                 email: params["email"],
                 name: params["name"],
                 phone: socket.assigns.phone
               },
               tenant: store.id
             ),
             authorize?: false
           ) do
        {:ok, customer} ->
          {:noreply, sign_in(socket, customer)}

        {:error, _} ->
          {:noreply,
           assign(socket, error: "That email is already in use. Try signing in instead.")}
      end
    else
      {:noreply,
       assign(socket,
         step: :phone,
         phone: nil,
         phone_verified: false,
         error: "Please verify your phone number first."
       )}
    end
  end

  def handle_event("resend", _params, socket) do
    store = socket.assigns.store
    PhoneAuth.request_code(socket.assigns.phone, :customer, store_id: store.id)
    {:noreply, assign(socket, error: nil)}
  end

  # After OTP success: existing (store-scoped) customer signs in; a new phone
  # goes to the email step.
  defp resolve(socket) do
    case customer_by_phone(socket.assigns.phone, socket.assigns.store.id) do
      nil -> {:noreply, assign(socket, step: :email, phone_verified: true, error: nil)}
      customer -> {:noreply, sign_in(socket, customer)}
    end
  end

  defp customer_by_phone(phone, store_id) do
    Customer
    |> Ash.Query.filter(phone == ^phone)
    |> Ash.read_one(tenant: store_id, authorize?: false)
    |> case do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp sign_in(socket, customer) do
    token = EmakolaWeb.AuthTokens.sign_subject_exchange(AshAuthentication.user_to_subject(customer))
    slug = socket.assigns.store.slug
    redirect(socket, to: ~p"/s/#{slug}/auth/customer-session?#{[token: token]}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#FAFAF9] flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div class="sm:mx-auto sm:w-full sm:max-w-md">
        <h2 class="text-center text-2xl font-serif font-semibold text-cta-dark">
          {@store.name}
        </h2>
        <p class="mt-2 text-center text-sm text-[#44403C]">
          Sign in with WhatsApp
        </p>
      </div>

      <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-white py-8 px-6 shadow-sm rounded-xl border border-stone-200 sm:px-10">
          <div
            :if={@error}
            class="mb-6 rounded-lg bg-red-50 border border-red-200 p-4 text-sm text-red-700"
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
            <label class="block text-xs font-medium uppercase tracking-wider text-[#44403C]">
              Your WhatsApp number
            </label>
            <.phone_input id="wa-phone" />
            <button class="w-full flex justify-center py-3 px-4 rounded-lg text-sm font-semibold text-white bg-cta-dark hover:bg-[#292524] transition-colors">
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
            <label class="block text-xs font-medium uppercase tracking-wider text-[#44403C]">
              Enter the 6-digit code
            </label>
            <.otp_code_input id="wa-code" />
            <button class="w-full flex justify-center py-3 px-4 rounded-lg text-sm font-semibold text-white bg-cta-dark hover:bg-[#292524] transition-colors">
              Verify
            </button>
            <button type="button" phx-click="resend" class="w-full text-sm font-medium text-cta-dark">
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
            <p class="text-sm text-[#44403C]">Last step — your email (for receipts &amp; updates).</p>
            <input
              type="email"
              name="customer[email]"
              required
              placeholder="you@example.com"
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors"
            />
            <input
              type="text"
              name="customer[name]"
              placeholder="Your name (optional)"
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors"
            />
            <button class="w-full flex justify-center py-3 px-4 rounded-lg text-sm font-semibold text-white bg-cta-dark hover:bg-[#292524] transition-colors">
              Create account
            </button>
          </.form>

          <div class="mt-6 text-center">
            <.link
              navigate={store_path(@store.slug, "/login")}
              class="text-sm text-[#78716C] hover:text-[#44403C] transition-colors"
            >
              Back to sign in
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
