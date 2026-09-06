defmodule EmakolaWeb.IdleConnectionSweeper do
  @moduledoc """
  Periodically garbage-collects idle Bandit connection processes.

  Every browser tab on a storefront or admin page holds two Bandit processes:
  the WebSocket transport carrying the LiveView, and often a keep-alive HTTP/1
  connection left over from the dead render. Both do one burst of heavy work
  (decoding the session, JSON-encoding the first render) and then sit idle. The
  BEAM only collects a process when *that process* allocates, so an idle
  connection keeps whatever heap the burst grew, indefinitely.

  Measured on the production image (2026-09-06): a WebSocket transport idled at
  250 to 650 KB and a keep-alive HTTP handler at 300 to 670 KB, while the
  LiveView process itself (which hibernates) was 58 KB. One forced collection
  took every transport to under 8 KB. That garbage was 0.9 MB per visitor and
  the whole reason a 512 MB machine died at 160 to 250 live shoppers.

  Bandit gives keep-alive HTTP handlers `gc_every_n_keepalive_requests`, set to
  1 in `config/runtime.exs`. Nothing equivalent exists for WebSocket transports
  (neither Bandit nor WebSock can hibernate them), so this process walks them
  every 10 seconds and collects any that sit idle above a heap threshold. A
  collection of a process with a few KB live costs tens of microseconds.
  """

  use GenServer

  @handler_initial_call {Bandit.DelegatingHandler, :init, 1}

  # Words, not bytes: 8_192 words is 64 KB on a 64-bit BEAM. A collected
  # transport sits at under 1_000 words; only bloated ones cross this line.
  @min_heap_words 8_192

  # Connections that arrived since the last sweep still carry their garbage, so
  # the interval bounds that backlog: at 10s and ~0.65MB per fresh connection,
  # a burst of 5 visitors a second costs ~30MB in flight. A sweep itself is a
  # walk of the process list, single-digit milliseconds.
  @default_interval :timer.seconds(10)

  @doc "Bandit's connection handler, as it appears in a process's `$initial_call`."
  @spec handler_initial_call() :: {module(), atom(), non_neg_integer()}
  def handler_initial_call, do: @handler_initial_call

  @doc "Heap size (in words) above which an idle connection is collected."
  @spec min_heap_words() :: pos_integer()
  def min_heap_words, do: @min_heap_words

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Collects every idle, bloated Bandit connection process now.

  Returns how many processes were collected. Safe to call from anywhere.
  """
  @spec sweep() :: non_neg_integer()
  def sweep do
    Process.list()
    |> Enum.filter(&bloated_idle_connection?/1)
    |> Enum.map(&:erlang.garbage_collect/1)
    |> Enum.count(& &1)
  end

  @impl true
  def init(opts) do
    unless Code.ensure_loaded?(Bandit.DelegatingHandler) do
      raise "Bandit.DelegatingHandler is gone; update #{inspect(__MODULE__)} to match Bandit's handler"
    end

    interval = Keyword.get(opts, :interval, @default_interval)
    schedule(interval)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule(state.interval)
    {:noreply, state}
  end

  defp schedule(interval), do: Process.send_after(self(), :sweep, interval)

  defp bloated_idle_connection?(pid) do
    case Process.info(pid, [:dictionary, :total_heap_size, :status]) do
      [dictionary: dict, total_heap_size: heap, status: status]
      when heap > @min_heap_words and status in [:waiting, :suspended] ->
        dict[:"$initial_call"] == @handler_initial_call

      _ ->
        false
    end
  end
end
