defmodule Emakola.Notifications.Providers.FcmPush do
  @moduledoc """
  Production push provider — FCM HTTP v1 via Req, authenticated with an
  OAuth2 token from Goth (`Emakola.Goth`, started only when
  FCM_SERVICE_ACCOUNT_JSON is configured).
  """

  @behaviour Emakola.Notifications.PushProvider

  @fcm_base "https://fcm.googleapis.com/v1/projects"

  @impl true
  def send_push(device_token, %{title: title, body: body} = notification) do
    project_id = Application.fetch_env!(:emakola, :fcm_project_id)

    payload = %{
      "message" => %{
        "token" => device_token,
        "notification" => %{"title" => title, "body" => body},
        "data" => stringify_values(Map.get(notification, :data, %{}))
      }
    }

    with {:ok, %{token: oauth_token}} <- Goth.fetch(Emakola.Goth),
         {:ok, response} <-
           Req.post("#{@fcm_base}/#{project_id}/messages:send",
             json: payload,
             auth: {:bearer, oauth_token}
           ) do
      handle_response(response)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # FCM requires data payload values to be strings.
  defp stringify_values(data) do
    Map.new(data, fn {k, v} -> {to_string(k), to_string(v)} end)
  end

  defp handle_response(%Req.Response{status: 200, body: body}), do: {:ok, body}

  # Deliberately NO status-only 404 clause: a typo'd FCM_PROJECT_ID also
  # yields 404s, and classifying those as :unregistered would let the push
  # worker mass-prune every device token after one bad deploy. Dead tokens
  # are identified by the UNREGISTERED errorCode in the body instead.
  defp handle_response(%Req.Response{status: status, body: body}) do
    if unregistered?(body) do
      {:error, :unregistered}
    else
      {:error, {:fcm_error, status, body}}
    end
  end

  defp unregistered?(%{"error" => error}) when is_map(error) do
    error
    |> Map.get("details", [])
    |> Enum.any?(&(is_map(&1) and Map.get(&1, "errorCode") == "UNREGISTERED"))
  end

  defp unregistered?(_body), do: false
end
