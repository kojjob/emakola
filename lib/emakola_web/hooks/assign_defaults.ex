defmodule EmakolaWeb.Hooks.AssignDefaults do
  @moduledoc """
  LiveView on_mount hook that assigns default values needed by the app layout.
  Loads the current_user from the session token and checks onboarding status.
  """
  import Phoenix.Component, only: [assign: 2]

  require Ash.Query

  def on_mount(:default, _params, session, socket) do
    socket = assign(socket, active_nav: :dashboard, setup_banner_dismissed: false)

    case session["user_token"] do
      nil ->
        {:cont, assign(socket, current_user: nil, onboarding_complete: false)}

      token ->
        case AshAuthentication.subject_to_user(token, Emakola.Accounts.User) do
          {:ok, user} ->
            onboarding_complete = has_membership?(user.id)
            {:cont, assign(socket, current_user: user, onboarding_complete: onboarding_complete)}

          _ ->
            {:cont, assign(socket, current_user: nil, onboarding_complete: false)}
        end
    end
  end

  defp has_membership?(user_id) do
    case Emakola.Accounts.Membership
         |> Ash.Query.filter(user_id: user_id)
         |> Ash.Query.limit(1)
         |> Ash.read() do
      {:ok, [_ | _]} -> true
      _ -> false
    end
  end
end
