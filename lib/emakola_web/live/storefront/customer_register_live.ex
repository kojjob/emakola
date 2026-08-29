defmodule EmakolaWeb.Storefront.CustomerRegisterLive do
  @moduledoc """
  Customer registration page for the storefront.

  Creates a new customer account scoped to the current store using
  AshAuthentication's password strategy, then auto-logs in by redirecting
  to the session controller with the generated token.
  """
  use EmakolaWeb, :live_view

  require Logger

  import EmakolaWeb.AuthComponents
  import EmakolaWeb.OAuthComponents
  import EmakolaWeb.Storefront.Path

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Create Account - #{socket.assigns.store.name}")
     |> assign(
       :form,
       to_form(
         %{
           "name" => "",
           "email" => "",
           "phone" => "",
           "password" => "",
           "password_confirmation" => ""
         },
         as: :customer
       )
     )
     |> assign(:error_message, nil)
     |> assign(:field_errors, %{})}
  end

  @impl true
  def handle_event("register", %{"customer" => params}, socket) do
    store = socket.assigns.store

    create_params = %{
      email: params["email"],
      password: params["password"],
      password_confirmation: params["password_confirmation"],
      store_id: store.id,
      name: params["name"],
      phone: params["phone"]
    }

    case Emakola.Customers.register_customer(create_params, authorize?: false) do
      {:ok, customer} ->
        token =
          EmakolaWeb.AuthTokens.sign_subject_exchange(AshAuthentication.user_to_subject(customer))

        {:noreply, redirect(socket, to: "/s/#{store.slug}/auth/customer-session?token=#{token}")}

      {:error, %Ash.Error.Invalid{} = error} ->
        field_errors = extract_field_errors(error)

        message =
          if map_size(field_errors) > 0,
            do: nil,
            else: "Registration failed. Please check your details."

        {:noreply,
         socket
         |> assign(:error_message, message)
         |> assign(:field_errors, field_errors)}

      {:error, _} ->
        {:noreply, assign(socket, :error_message, "Registration failed. Please try again.")}
    end
  end

  # A page that does not know an event is a bug in whatever sent it — a theme
  # calling `add_to_bag` where this page listens for `add_to_cart`. Raising
  # takes the storefront down in front of a shopper mid-purchase, which is a
  # far worse answer than ignoring the click. Logged rather than swallowed
  # silently, so the next wrong event name does not ship unnoticed.
  def handle_event(event, _params, socket) do
    Logger.warning("[storefront] #{inspect(__MODULE__)} ignored unknown event #{inspect(event)}")

    {:noreply, socket}
  end

  defp extract_field_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.reduce(errors, %{}, fn
      %{field: field} = error, acc when not is_nil(field) ->
        Map.put(acc, to_string(field), EmakolaWeb.AshErrors.message(error))

      _, acc ->
        acc
    end)
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
          Create your account
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

          <.whatsapp_button
            :if={Emakola.Accounts.PhoneAuth.enabled?()}
            href={store_path(@store.slug, "/whatsapp")}
            class="mb-6"
          />

          <.oauth_buttons subject="customer" store_slug={@store.slug} class="mb-6" />

          <.form for={@form} id="register-form" phx-submit="register" class="space-y-5">
            <div>
              <label
                for="customer_name"
                class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2"
              >
                Name <span class="text-[#A8A29E] normal-case">(optional)</span>
              </label>
              <input
                type="text"
                name="customer[name]"
                id="customer_name"
                autocomplete="name"
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors"
                value={@form[:name].value}
              />
            </div>

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
                class={[
                  "w-full px-4 py-3 border rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors",
                  if(@field_errors["email"], do: "border-red-300", else: "border-stone-200")
                ]}
                value={@form[:email].value}
              />
              <p :if={@field_errors["email"]} class="mt-1 text-xs text-red-600">
                {@field_errors["email"]}
              </p>
            </div>

            <div>
              <label
                for="customer_phone"
                class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2"
              >
                Phone <span class="text-[#A8A29E] normal-case">(optional)</span>
              </label>
              <input
                type="tel"
                name="customer[phone]"
                id="customer_phone"
                autocomplete="tel"
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors"
                value={@form[:phone].value}
              />
            </div>

            <div>
              <label
                for="customer_password"
                class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2"
              >
                Password <span class="text-[#A8A29E] normal-case">(min. 8 characters)</span>
              </label>
              <input
                type="password"
                name="customer[password]"
                id="customer_password"
                required
                minlength="8"
                autocomplete="new-password"
                class={[
                  "w-full px-4 py-3 border rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors",
                  if(@field_errors["password"], do: "border-red-300", else: "border-stone-200")
                ]}
              />
              <p :if={@field_errors["password"]} class="mt-1 text-xs text-red-600">
                {@field_errors["password"]}
              </p>
            </div>

            <div>
              <label
                for="customer_password_confirmation"
                class="block text-xs font-medium uppercase tracking-wider text-[#44403C] mb-2"
              >
                Confirm password
              </label>
              <input
                type="password"
                name="customer[password_confirmation]"
                id="customer_password_confirmation"
                required
                minlength="8"
                autocomplete="new-password"
                class={[
                  "w-full px-4 py-3 border rounded-lg text-sm text-cta-dark focus:outline-none focus:ring-2 focus:ring-stone-900 focus:border-transparent transition-colors",
                  if(@field_errors["password_confirmation"],
                    do: "border-red-300",
                    else: "border-stone-200"
                  )
                ]}
              />
              <p :if={@field_errors["password_confirmation"]} class="mt-1 text-xs text-red-600">
                {@field_errors["password_confirmation"]}
              </p>
            </div>

            <div class="pt-1">
              <button
                type="submit"
                id="register-submit-btn"
                class="cursor-pointer w-full flex justify-center py-3 px-4 rounded-lg text-sm font-semibold text-white bg-cta-dark hover:bg-[#292524] transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-stone-900"
              >
                Create Account
              </button>
            </div>
          </.form>

          <div class="mt-6 space-y-3 text-center">
            <p class="text-sm text-[#44403C]">
              Already have an account?
              <.link
                navigate={store_path(@store.slug, "/login")}
                class="font-medium text-cta-dark hover:underline"
              >
                Sign in
              </.link>
            </p>
            <p>
              <.link
                navigate={store_path(@store.slug, "/")}
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
