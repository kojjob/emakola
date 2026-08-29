defmodule Emakola.RateLimit do
  @moduledoc """
  Distributed, eventually consistent rate limiter backed by Hammer ETS.

  Every node keeps a fast local counter. Hits are broadcast to the other
  clustered nodes through `Emakola.PubSub`, so a client cannot multiply its
  allowance simply by reaching a different Fly machine.

  New nodes start with empty counters and network partitions temporarily
  degrade to per-node enforcement. That trade-off is preferable to making
  request availability depend on a remote counter store; authentication also
  has its own credential and attempt controls.
  """

  alias Emakola.RateLimit.Local

  @pubsub Emakola.PubSub
  @topic "__emakola_rate_limit"

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc false
  def start_link(opts) do
    children = [
      {Local, opts},
      {Emakola.RateLimit.Listener, pubsub: @pubsub, topic: @topic}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end

  @doc """
  Check if a request should be allowed.

  Returns `{:allow, count}` or `{:deny, retry_after_ms}`.
  """
  def check_rate(id, limit, window_ms) do
    hit(id, window_ms, limit)
  end

  @doc false
  def hit(key, scale, limit, increment \\ 1) do
    _ = broadcast_remote({:inc, key, scale, increment})
    Local.hit(key, scale, limit, increment)
  end

  defp broadcast_remote(message) do
    # Remote-only broadcast: the adapter fans out to OTHER nodes while the
    # local effect was already applied directly, so a normal
    # Phoenix.PubSub.broadcast/3 would double-apply it here. The cost of
    # reaching past the public API is owning its shape: phoenix_pubsub 2.3
    # added the default dispatcher as a third meta element, which broke the
    # old 2-tuple match on every code path that rate-limits. Both shapes are
    # accepted so a future change degrades to :pubsub_unavailable instead of
    # a CaseClauseError.
    case Registry.meta(@pubsub, :pubsub) do
      {:ok, {adapter, adapter_name, dispatcher}} ->
        adapter.broadcast(adapter_name, @topic, message, dispatcher)

      {:ok, {adapter, adapter_name}} ->
        adapter.broadcast(adapter_name, @topic, message, Phoenix.PubSub)

      _ ->
        {:error, :pubsub_unavailable}
    end
  end
end
