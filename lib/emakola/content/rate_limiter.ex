defmodule Emakola.Content.RateLimiter do
  @moduledoc """
  Per-store daily cap on AI content generations (SEO Phase 3) — the cost guard.

  Each store may run at most `:ai_rate_limit_per_day` generations per calendar
  day (UTC). Backed by an ETS counter keyed `{store_id, date}`, owned by this
  GenServer for crash safety and incremented atomically.

  Per-node: Fly runs multiple machines, so the effective global cap is roughly
  `nodes × limit`. That's an acceptable bound for a spend guard — the workers
  also ship dark (no API key → no generation), so this is belt-and-suspenders.
  """

  use GenServer

  @table :emakola_ai_usage

  # ── Client API ──

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Reserves one generation for `store_id` today. Returns `:ok` while under the
  daily limit, `{:error, :rate_limit_exceeded}` once it's reached. Atomic.
  """
  @spec check_and_increment(String.t(), pos_integer()) :: :ok | {:error, :rate_limit_exceeded}
  def check_and_increment(store_id, limit \\ default_limit()) do
    key = {store_id, Date.utc_today()}
    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

    if count <= limit, do: :ok, else: {:error, :rate_limit_exceeded}
  end

  @doc "Generations used by `store_id` so far today — for the SEO dashboard."
  @spec usage(String.t()) :: non_neg_integer()
  def usage(store_id) do
    case :ets.lookup(@table, {store_id, Date.utc_today()}) do
      [{_key, count}] -> count
      [] -> 0
    end
  end

  @doc "The configured daily limit."
  @spec default_limit() :: pos_integer()
  def default_limit, do: Application.get_env(:emakola, :ai_rate_limit_per_day, 50)

  @doc """
  Seconds until the cap resets, with a minute of slack. The counter is keyed by
  UTC calendar day, so a job that hit the cap can snooze exactly this long and
  find room when it wakes.
  """
  @spec seconds_until_reset() :: pos_integer()
  def seconds_until_reset do
    now = DateTime.utc_now()

    next_midnight =
      now
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    DateTime.diff(next_midnight, now, :second) + 60
  end

  # ── Server ──

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, write_concurrency: true])
    {:ok, %{}}
  end
end
