defmodule EmakolaWeb.Platform.InviteAcceptLive do
  @moduledoc """
  Platform staff invite acceptance page.

  The raw token from the URL is hashed and classified on mount. Invalid
  and revoked tokens show the same generic copy so revocation is never
  leaked. Acceptance does NOT sign the user in — staff must sign in at
  /platform/login, which forces TOTP enrolment on first sign-in.
  """
  use EmakolaWeb, :live_view

  alias Emakola.Accounts.PlatformTeam

  @accepted_flash "This invite has already been used — sign in instead."

  def mount(%{"token" => raw_token}, _session, socket) do
    if connected?(socket) do
      case PlatformTeam.invite_status(raw_token) do
        {:ok, invite} ->
          {:ok,
           assign(socket,
             state: :form,
             raw_token: raw_token,
             invite_email: to_string(invite.email),
             form: to_form(%{"name" => ""}, as: :user),
             error: nil
           )}

        {:error, :already_accepted} ->
          {:ok, socket |> put_flash(:info, @accepted_flash) |> redirect(to: "/platform/login")}

        {:error, :expired} ->
          {:ok, assign(socket, state: :expired)}

        {:error, status} when status in [:invalid, :revoked] ->
          {:ok, assign(socket, state: :invalid)}
      end
    else
      {:ok,
       assign(socket,
         state: :loading,
         raw_token: raw_token,
         invite_email: nil,
         form: to_form(%{"name" => ""}, as: :user),
         error: nil
       )}
    end
  end

  # No signed-in actor here by design: possession of a pending invite
  # token is the authorization, and accept_invite re-verifies the token
  # on every submit (it could have been revoked since mount).
  def handle_event("submit", %{"user" => params}, socket) do
    case PlatformTeam.accept_invite(socket.assigns.raw_token, %{
           name: String.trim(params["name"] || ""),
           password: params["password"] || "",
           password_confirmation: params["password_confirmation"] || ""
         }) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created — sign in to set up two-factor authentication.")
         |> redirect(to: "/platform/login")}

      {:error, :email_taken} ->
        {:noreply,
         assign(socket,
           error:
             "An account with this email already exists — sign in at /platform/login instead."
         )}

      {:error, :already_accepted} ->
        {:noreply, socket |> put_flash(:info, @accepted_flash) |> redirect(to: "/platform/login")}

      {:error, :expired} ->
        {:noreply, assign(socket, state: :expired)}

      {:error, status} when status in [:invalid, :revoked] ->
        {:noreply, assign(socket, state: :invalid)}

      {:error, error} ->
        {:noreply,
         assign(socket,
           error: error_messages(error),
           form: to_form(%{"name" => params["name"] || ""}, as: :user)
         )}
    end
  end

  defp error_messages(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ". ", fn
      %{field: field, message: message} when not is_nil(field) ->
        "#{Phoenix.Naming.humanize(field)} #{message}"

      %{message: message} ->
        message

      _other ->
        "Something went wrong. Please try again."
    end)
  end

  defp error_messages(_), do: "Something went wrong. Please try again."

  # ── Render ──────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-[#0c1526] px-6 py-12">
      <div class="w-full max-w-md">
        <div class="flex items-center justify-center gap-2 mb-8">
          <img src={~p"/images/emakola-logo.svg"} alt="Emakola" class="h-8 w-auto" />
          <span class="text-[#f1f5f9] text-lg font-bold tracking-tight">Emakola</span>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-6 sm:p-8">
          <div :if={@state == :loading} class="py-8 text-center text-sm text-[#8896ab]">
            Checking invite…
          </div>

          <.dead_end :if={@state == :invalid} title="Invite not valid">
            This invite link is invalid or has been revoked.
          </.dead_end>

          <.dead_end :if={@state == :expired} title="Invite expired">
            This invite has expired — ask an owner to send a new one.
          </.dead_end>

          <div :if={@state == :form}>
            <div class="mb-6">
              <h1 class="text-2xl font-bold text-[#0c1526]">Join the platform team</h1>
              <p class="text-[#5f6b7a] mt-1 text-sm">
                Create your Emakola staff account to accept the invite.
              </p>
            </div>

            <div
              :if={@error}
              class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700"
              role="alert"
            >
              <span class="material-symbols-outlined text-lg text-red-500">error</span>
              <span>{@error}</span>
            </div>

            <.form for={@form} id="platform-invite-form" phx-submit="submit" class="space-y-4">
              <div>
                <label for="invite-email" class={label_class()}>Email</label>
                <input
                  type="email"
                  id="invite-email"
                  value={@invite_email}
                  disabled
                  class={input_class() <> " bg-gray-50 text-[#5f6b7a] cursor-not-allowed"}
                />
              </div>
              <div>
                <label for="invite-name" class={label_class()}>Full name</label>
                <input
                  type="text"
                  id="invite-name"
                  name="user[name]"
                  value={@form[:name].value}
                  placeholder="Kwame Asante"
                  required
                  autocomplete="name"
                  class={input_class()}
                />
              </div>
              <div>
                <label for="invite-password" class={label_class()}>Password</label>
                <input
                  type="password"
                  id="invite-password"
                  name="user[password]"
                  placeholder="Min. 8 characters"
                  required
                  autocomplete="new-password"
                  class={input_class()}
                />
              </div>
              <div>
                <label for="invite-password-confirmation" class={label_class()}>
                  Confirm password
                </label>
                <input
                  type="password"
                  id="invite-password-confirmation"
                  name="user[password_confirmation]"
                  placeholder="Repeat your password"
                  required
                  autocomplete="new-password"
                  class={input_class()}
                />
              </div>
              <button
                type="submit"
                class="w-full bg-[#0c1526] hover:bg-[#1a2744] text-[#f1f5f9] font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm"
              >
                Create account
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp dead_end(assigns) do
    ~H"""
    <div class="text-center py-4">
      <span class="material-symbols-outlined text-4xl text-[#8896ab]">link_off</span>
      <h1 class="text-xl font-bold text-[#0c1526] mt-3">{@title}</h1>
      <p class="text-sm text-[#5f6b7a] mt-2">{render_slot(@inner_block)}</p>
    </div>
    """
  end

  defp label_class, do: "block text-sm font-medium text-[#0c1526] mb-1.5"

  defp input_class do
    "w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] " <>
      "placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] " <>
      "transition-colors"
  end
end
