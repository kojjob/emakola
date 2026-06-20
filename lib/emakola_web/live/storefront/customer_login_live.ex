defmodule EmakolaWeb.Storefront.CustomerLoginLive do
  @moduledoc """
  Customer login page for the storefront.

  Authenticates customers using AshAuthentication's password strategy,
  then redirects to the session controller to persist the token cookie.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.OAuthComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Sign In - #{socket.assigns.store.name}")
     |> assign(:form, to_form(%{"email" => "", "password" => ""}, as: :customer))
     |> assign(:error_message, nil)}
  end

  @impl true
  def handle_event("login", %{"customer" => params}, socket) do
    %{"email" => email, "password" => password} = params
    store = socket.assigns.store

    case Emakola.Customers.Customer
         |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: password})
         |> Ash.read_one(authorize?: false) do
      {:ok, customer} when not is_nil(customer) ->
        # Verify customer belongs to this store
        if to_string(customer.store_id) == to_string(store.id) do
          token =
            EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(customer))

          {:noreply,
           redirect(socket, to: "/s/#{store.slug}/auth/customer-session?token=#{token}")}
        else
          {:noreply, assign(socket, :error_message, "Invalid email or password.")}
        end

      _ ->
        {:noreply, assign(socket, :error_message, "Invalid email or password.")}
    end
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
          Sign in to your account
        </p>
      </div>

      <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-white py-8 px-6 shadow-sm rounded-xl border border-stone-200 sm:px-10">
          <div
            :if={@error_message}
            class="mb-6 rounded-lg bg-red-50 border border-red-200 p-4 text-sm text-red-700"
          >
            {@error_message}
          </div>

          <.oauth_buttons subject="customer" store_slug={@store.slug} class="mb-6" />

          <.form for={@form} id="login-form" phx-submit="login" class="space-y-6">
            <div>
              <label
                for="customer_email"
                class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2"
              >
                Email address
              </label>
              <input
                type="email"
                name="customer[email]"
                id="customer_email"
                required
                autocomplete="email"
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors"
                value={@form[:email].value}
              />
            </div>

            <div>
              <label
                for="customer_password"
                class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2"
              >
                Password
              </label>
              <input
                type="password"
                name="customer[password]"
                id="customer_password"
                required
                autocomplete="current-password"
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors"
              />
            </div>

            <div>
              <button
                type="submit"
                id="login-submit-btn"
                class="cursor-pointer w-full flex justify-center py-3 px-4 rounded-lg text-sm font-semibold text-white bg-cta-dark hover:bg-[#292524] transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-stone-900"
              >
                Sign In
              </button>
            </div>
          </.form>

          <div class="mt-6 space-y-3 text-center">
            <p class="text-sm text-[#44403C]">
              Don't have an account?
              <.link
                navigate={"/s/#{@store.slug}/register"}
                class="font-medium text-cta-dark hover:underline"
              >
                Create one
              </.link>
            </p>
            <p>
              <.link
                navigate={"/s/#{@store.slug}"}
                class="text-sm text-[#78716C] hover:text-[#44403C] transition-colors"
              >
                Continue shopping
              </.link>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
