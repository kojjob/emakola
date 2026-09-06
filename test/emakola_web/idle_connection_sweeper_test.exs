defmodule EmakolaWeb.IdleConnectionSweeperTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.IdleConnectionSweeper

  @bandit_handler {Bandit.DelegatingHandler, :init, 1}
  @bloat_words 200_000

  # A stand-in for a Bandit connection process: it registers Bandit's initial
  # call, builds a large amount of garbage (as JSON-encoding a first render
  # does), then sits idle holding almost nothing live.
  defp spawn_idle_process(initial_call) do
    parent = self()

    pid =
      spawn(fn ->
        Process.put(:"$initial_call", initial_call)
        garbage = Enum.to_list(1..@bloat_words)
        send(parent, {:bloated, length(garbage)})

        receive do
          :stop -> :ok
        end
      end)

    # Building the garbage can take well over the 100ms default on a loaded CI runner.
    assert_receive {:bloated, @bloat_words}, 10_000
    pid
  end

  defp heap_words(pid) do
    {:total_heap_size, words} = Process.info(pid, :total_heap_size)
    words
  end

  # Polls rather than sleeping a fixed time: on a loaded host a 20ms interval can
  # slip well past 100ms, and a fixed sleep turns the test into a coin toss.
  defp eventually(check, deadline_ms \\ 3_000) do
    wait_until(check, System.monotonic_time(:millisecond) + deadline_ms)
  end

  defp wait_until(check, deadline) do
    cond do
      check.() -> true
      System.monotonic_time(:millisecond) > deadline -> false
      true -> Process.sleep(10) && wait_until(check, deadline)
    end
  end

  describe "sweep/0" do
    test "collects an idle Bandit connection process whose heap is mostly garbage" do
      pid = spawn_idle_process(@bandit_handler)
      assert heap_words(pid) > IdleConnectionSweeper.min_heap_words()

      assert IdleConnectionSweeper.sweep() >= 1

      assert heap_words(pid) < IdleConnectionSweeper.min_heap_words()
      send(pid, :stop)
    end

    test "leaves processes that are not Bandit connections alone" do
      pid = spawn_idle_process({SomeOther.Server, :init, 1})
      before = heap_words(pid)

      IdleConnectionSweeper.sweep()

      assert heap_words(pid) == before
      send(pid, :stop)
    end

    test "skips a Bandit connection whose heap is already small" do
      parent = self()

      pid =
        spawn(fn ->
          Process.put(:"$initial_call", @bandit_handler)
          send(parent, :ready)

          receive do
            :stop -> :ok
          end
        end)

      assert_receive :ready
      before = heap_words(pid)
      assert before < IdleConnectionSweeper.min_heap_words()

      IdleConnectionSweeper.sweep()

      assert heap_words(pid) == before
      send(pid, :stop)
    end
  end

  describe "as a supervised process" do
    test "sweeps on its own on the configured interval" do
      pid = spawn_idle_process(@bandit_handler)
      assert heap_words(pid) > IdleConnectionSweeper.min_heap_words()

      start_supervised!({IdleConnectionSweeper, interval: 20, name: __MODULE__.Sweeper})

      assert eventually(fn -> heap_words(pid) < IdleConnectionSweeper.min_heap_words() end)
      send(pid, :stop)
    end

    test "refuses to start if Bandit's connection handler module is gone" do
      # The sweeper matches Bandit's handler by name. If a Bandit upgrade renames
      # it the sweep would silently do nothing, so the process must fail loudly.
      assert Code.ensure_loaded?(Bandit.DelegatingHandler)
      assert IdleConnectionSweeper.handler_initial_call() == @bandit_handler
    end
  end
end
