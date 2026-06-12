defmodule Emakola.Notifications.Providers.LogPushTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Emakola.Notifications.Providers.LogPush

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
