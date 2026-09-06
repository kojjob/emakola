defmodule EmakolaWeb.Hooks.CollectTransportTest do
  use ExUnit.Case, async: true

  alias EmakolaWeb.Hooks.CollectTransport

  # A stand-in for the WebSocket transport process: it grows a large heap doing
  # one burst of work (as JSON-encoding the join reply does), then sits idle
  # holding almost nothing live.
  defp spawn_bloated_transport do
    parent = self()

    pid =
      spawn(fn ->
        garbage = Enum.to_list(1..200_000)
        send(parent, {:bloated, length(garbage)})

        receive do
          :stop -> :ok
        end
      end)

    # Building the garbage can take well over the 100ms default on a loaded CI runner.
    assert_receive {:bloated, 200_000}, 10_000
    pid
  end

  defp heap_words(pid) do
    {:total_heap_size, words} = Process.info(pid, :total_heap_size)
    words
  end

  # A real socket carries its lifecycle in `private`; attach_hook/4 needs it.
  defp socket(transport_pid) do
    %Phoenix.LiveView.Socket{
      transport_pid: transport_pid,
      endpoint: EmakolaWeb.Endpoint,
      private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
    }
  end

  describe "on_mount/4" do
    test "on a connected mount, asks itself to collect the transport shortly after" do
      assert {:cont, %Phoenix.LiveView.Socket{}} =
               CollectTransport.on_mount(:default, %{}, %{}, socket(self()))

      assert_receive {CollectTransport, :collect}, CollectTransport.delay_ms() + 500
    end

    test "on a disconnected (dead) render, does nothing" do
      assert {:cont, %Phoenix.LiveView.Socket{}} =
               CollectTransport.on_mount(:default, %{}, %{}, socket(nil))

      refute_receive {CollectTransport, :collect}, CollectTransport.delay_ms() + 200
    end
  end

  describe "collect/2 (the handle_info hook)" do
    test "collects the transport process and swallows its own message" do
      transport = spawn_bloated_transport()
      assert heap_words(transport) > 8_192

      assert {:halt, %Phoenix.LiveView.Socket{}} =
               CollectTransport.collect({CollectTransport, :collect}, socket(transport))

      assert heap_words(transport) < 8_192
      send(transport, :stop)
    end

    test "passes every other message through" do
      assert {:cont, %Phoenix.LiveView.Socket{}} =
               CollectTransport.collect(:some_other_message, socket(self()))
    end

    test "tolerates a transport that has already gone away" do
      transport = spawn(fn -> :ok end)
      ref = Process.monitor(transport)
      assert_receive {:DOWN, ^ref, :process, ^transport, _}

      assert {:halt, %Phoenix.LiveView.Socket{}} =
               CollectTransport.collect({CollectTransport, :collect}, socket(transport))
    end
  end
end
