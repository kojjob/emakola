defmodule EmakolaWeb.Auth.RegisterLive do
  use EmakolaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, form: to_form(%{"email" => "", "password" => "", "name" => ""}, as: :user)),
     layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col bg-background">
      <main class="flex-1 flex items-center justify-center p-4">
        <div class="w-full max-w-md space-y-8">
          <div class="text-center">
            <div class="w-12 h-12 rounded-xl bg-primary mx-auto flex items-center justify-center mb-4">
              <span class="material-symbols-outlined text-on-primary text-2xl">architecture</span>
            </div>
            <h1 class="text-3xl font-extrabold font-headline text-on-surface">Create your account</h1>
            <p class="text-on-surface-variant mt-2">Start building with Emakola</p>
          </div>

          <.form for={@form} phx-submit="register" class="space-y-6">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Full Name
                </label>
                <input
                  type="text"
                  name="user[name]"
                  value={@form[:name].value}
                  placeholder="Ada Lovelace"
                  required
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">Email</label>
                <input
                  type="email"
                  name="user[email]"
                  value={@form[:email].value}
                  placeholder="you@company.com"
                  required
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-on-surface-variant mb-1.5">
                  Password
                </label>
                <input
                  type="password"
                  name="user[password]"
                  placeholder="Min. 8 characters"
                  required
                  class="w-full bg-surface-container-highest border-none rounded-lg px-4 py-3 text-sm text-on-surface placeholder:text-on-surface-variant/50 focus:ring-2 focus:ring-primary"
                />
              </div>
            </div>

            <button
              type="submit"
              class="w-full primary-gradient font-semibold py-3 rounded-lg text-sm transition-all hover:opacity-90 active:scale-[0.98]"
            >
              Create Account
            </button>
          </.form>

          <div class="relative">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-outline-variant/20"></div>
            </div>
            <div class="relative flex justify-center text-xs">
              <span class="bg-background px-4 text-on-surface-variant">or sign up with</span>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <button class="flex items-center justify-center gap-2 bg-surface-container-high hover:bg-surface-container-highest rounded-lg py-2.5 text-sm font-medium text-on-surface transition-colors">
              <svg class="w-5 h-5" viewBox="0 0 24 24">
                <path
                  d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
                  fill="#4285F4"
                /><path
                  d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                  fill="#34A853"
                /><path
                  d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                  fill="#FBBC05"
                /><path
                  d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                  fill="#EA4335"
                />
              </svg>
              Google
            </button>
            <button class="flex items-center justify-center gap-2 bg-surface-container-high hover:bg-surface-container-highest rounded-lg py-2.5 text-sm font-medium text-on-surface transition-colors">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" />
              </svg>
              GitHub
            </button>
          </div>

          <p class="text-center text-sm text-on-surface-variant">
            Already have an account?
            <a href="/auth/login" class="text-primary font-medium hover:underline">Sign in</a>
          </p>
        </div>
      </main>
      <.public_footer />
    </div>
    """
  end

  def handle_event("register", %{"user" => params}, socket) do
    strategy = AshAuthentication.Info.strategy!(Emakola.Accounts.User, :password)

    case AshAuthentication.Strategy.action(strategy, :register, %{
           "email" => params["email"],
           "password" => params["password"],
           "password_confirmation" => params["password"]
         }) do
      {:ok, user} ->
        # Save the user's name from the registration form
        name = String.trim(params["name"] || "")

        if name != "" do
          user
          |> Ash.Changeset.for_update(:update_profile, %{name: name})
          |> Ash.update()
        end

        token = AshAuthentication.user_to_subject(user)

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(
           to: "/auth/session?token=#{URI.encode_www_form(token)}&redirect_to=%2Fonboarding"
         )}

      {:error, error} ->
        error_messages = extract_errors(error)

        {:noreply,
         socket
         |> put_flash(:error, error_messages)
         |> assign(
           form:
             to_form(
               %{"email" => params["email"], "password" => "", "name" => params["name"]},
               as: :user
             )
         )}
    end
  end

  defp extract_errors(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(fn
      %{field: field, message: message} when is_binary(field) ->
        "#{Phoenix.Naming.humanize(field)} #{message}"

      %{field: field, message: message} when is_atom(field) ->
        "#{Phoenix.Naming.humanize(Atom.to_string(field))} #{message}"

      %{message: message} ->
        message

      other ->
        inspect(other)
    end)
    |> Enum.join(". ")
  end

  defp extract_errors(_), do: "Registration failed. Please try again."
end
