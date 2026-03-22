defmodule Emakola.Analytics do
  use Ash.Domain

  resources do
    resource Emakola.Analytics.AppEvent do
      define(:create_event, action: :create)
      define(:list_events, action: :read)
      define(:list_by_org, action: :by_organisation, args: [:organisation_id])
    end

    resource Emakola.Analytics.SearchConsoleData do
      define(:create_search_data, action: :create)
      define(:list_search_data, action: :read)
      define(:list_search_by_org, action: :by_organisation, args: [:organisation_id])
    end
  end

  @doc "Track an in-app event and broadcast via PubSub."
  def track(event_name, opts \\ []) do
    actor_id = Keyword.get(opts, :actor_id)
    org_id = Keyword.get(opts, :org_id)
    metadata = Keyword.get(opts, :metadata, %{})

    result =
      Emakola.Analytics.AppEvent
      |> Ash.Changeset.for_create(:create, %{
        event_name: event_name,
        actor_id: actor_id,
        organisation_id: org_id,
        metadata: metadata,
        occurred_at: DateTime.utc_now()
      })
      |> Ash.create()

    case result do
      {:ok, event} ->
        broadcast_event(event)
        {:ok, event}

      error ->
        error
    end
  end

  defp broadcast_event(event) do
    if event.organisation_id do
      Phoenix.PubSub.broadcast(
        Emakola.PubSub,
        "org_events:#{event.organisation_id}",
        {:app_event, event}
      )
    end
  end
end
