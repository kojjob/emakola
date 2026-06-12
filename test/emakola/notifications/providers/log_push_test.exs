defmodule Emakola.Notifications.Providers.LogPushTest do
  # async: false — the test temporarily raises the global Logger level so
  # capture_log can see the provider's info-level output (test env runs at
  # :warning).
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Emakola.Notifications.Providers.LogPush

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  test "logs and succeeds without leaking the token" do
    log =
      capture_log(fn ->
        assert {:ok, %{provider: :log}} =
                 LogPush.send_push("fcm-token-123456789", %{
                   title: "New order",
                   body: "GHS 50.00",
                   data: %{"order_id" => "abc"}
                 })
      end)

    assert log =~ "[push]"
    assert log =~ "New order"
    refute log =~ "fcm-token-123456789"
  end
end
