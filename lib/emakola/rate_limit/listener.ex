defmodule Emakola.RateLimit.Listener do
  @moduledoc false

  use GenServer

  @doc false
  def start_link(opts) do
    pubsub = Keyword.fetch!(opts, :pubsub)
    topic = Keyword.fetch!(opts, :topic)
    GenServer.start_link(__MODULE__, {pubsub, topic}, name: __MODULE__)
  end

  @impl true
  def init({pubsub, topic}) do
    :ok = Phoenix.PubSub.subscribe(pubsub, topic)
    {:ok, nil}
  end

  @impl true
  def handle_info({:inc, key, scale, increment}, state) do
    _count = Emakola.RateLimit.Local.inc(key, scale, increment)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}
end
