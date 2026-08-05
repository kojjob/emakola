defmodule EmakolaWeb.Auth.ResetPasswordLive do
  use EmakolaWeb, :live_view

  alias AshAuthentication.{Info, Strategy}

  def mount(params, _session, socket) do
    token = params["token"]

    {:ok,
     socket
     |> assign(token: token)
     |> assign(invalid_link: token in [nil, ""])
     |> assign(form: to_form(%{"password" => "", "password_confirmation" => ""}, as: :reset)),
     layout: false}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} variant={:plain}>
      <div class="min-h-screen flex items-center justify-center bg-[#f7f8fa] px-6 py-12">
        <div class="w-full max-w-md">
          <div class="flex items-center justify-center gap-2 mb-8">
            <img src={~p"/images/emakola-logo.svg"} alt="Makola" class="h-8 w-auto" />
            <span class="text-[#0c1526] text-lg font-bold tracking-tight">Makola</span>
          </div>

          <div :if={@invalid_link} class="text-center">
            <div class="mb-4 inline-flex items-center gap-2 rounded-xl bg-amber-50 border border-amber-200 px-4 py-3 text-sm text-amber-800">
              <span class="material-symbols-outlined text-lg text-amber-600">link_off</span>
              <span>This reset link is invalid or has expired.</span>
            </div>
            <p class="text-sm text-[#5f6b7a]">
              <a href="/auth/forgot-password" class="font-medium text-[#2563eb] hover:underline">
                Request a new reset link
              </a>
            </p>
          </div>

          <div :if={!@invalid_link}>
            <div class="mb-8 text-center">
              <h1 class="text-2xl font-bold text-[#0c1526]">Set a new password</h1>
              <p class="text-[#5f6b7a] mt-1 text-sm">Minimum 8 characters.</p>
            </div>

            <div
              :if={@flash["error"]}
              class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
              role="alert"
            >
              <span class="material-symbols-outlined text-lg text-red-500">error</span>
              <span>{@flash["error"]}</span>
            </div>

            <.form for={@form} id="reset-password-form" phx-submit="reset_password" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-[#0c1526] mb-1.5">New password</label>
                <input
                  type="password"
                  name="reset[password]"
                  placeholder="Min. 8 characters"
                  required
                  class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-[#0c1526] mb-1.5">
                  Confirm new password
                </label>
                <input
                  type="password"
                  name="reset[password_confirmation]"
                  placeholder="Repeat the password"
                  required
                  class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
                />
              </div>
              <button
                type="submit"
                class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
              >
                Update Password
              </button>
            </.form>

            <p class="mt-6 text-center text-sm text-[#5f6b7a]">
              <a href="/auth/login" class="font-medium text-[#2563eb] hover:underline">
                Back to login
              </a>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("reset_password", %{"reset" => params}, socket) do
    strategy = Info.strategy!(Emakola.Accounts.Merchant, :password)

    case Strategy.action(strategy, :reset, %{
           "reset_token" => socket.assigns.token,
           "password" => params["password"] || "",
           "password_confirmation" => params["password_confirmation"] || ""
         }) do
      {:ok, merchant} ->
        # Password proof rotated — sign out every other device, attacker
        # included: Ash tokens revoked AND browser sessions invalidated.
        Emakola.Accounts.revoke_all_sessions_for(merchant)

        {:noreply,
         socket
         |> put_flash(:info, "Password updated. Sign in with your new password.")
         |> redirect(to: "/auth/login")}

      {:error, error} ->
        if invalid_token_error?(error) do
          {:noreply, assign(socket, invalid_link: true)}
        else
          {:noreply, put_flash(socket, :error, format_field_errors(error))}
        end
    end
  end

  # A bad/expired token surfaces as a bare InvalidToken (pinned empirically);
  # keep the wrapped forms too in case the library changes its envelope.
  defp invalid_token_error?(%AshAuthentication.Errors.InvalidToken{}), do: true

  defp invalid_token_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %AshAuthentication.Errors.InvalidToken{} -> true
      %{field: :reset_token} -> true
      _ -> false
    end)
  end

  defp invalid_token_error?(_), do: false

  defp format_field_errors(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ". ", fn
      %{field: field} = error when not is_nil(field) ->
        "#{Phoenix.Naming.humanize(field)} #{EmakolaWeb.AshErrors.message(error)}"

      %{message: message} = error when is_binary(message) ->
        EmakolaWeb.AshErrors.message(error)

      _ ->
        "Something went wrong. Please try again."
    end)
  end

  defp format_field_errors(_), do: "Something went wrong. Please try again."
end
