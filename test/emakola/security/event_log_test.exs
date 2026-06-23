defmodule Emakola.Security.EventLogTest do
  @moduledoc """
  Security event log: record/1 (fire-and-forget) and the overview/1 aggregates
  (by-type counts, top-IP ranking, anomaly flagging, 24h window).
  """
  use Emakola.DataCase, async: true

  alias Emakola.Security

  describe "record/1" do
    test "persists a security event" do
      assert {:ok, event} =
               Security.record(%{
                 event_type: :rate_limit_exceeded,
                 ip: "1.2.3.4",
                 path: "/auth/login"
               })

      assert event.event_type == :rate_limit_exceeded
      assert event.ip == "1.2.3.4"
      assert event.subject_type == :anonymous
    end

    test "returns an error (never raises) on invalid input" do
      assert {:error, _} = Security.record(%{event_type: :bogus})
      assert {:error, _} = Security.record(%{})
    end
  end

  describe "overview/1" do
    test "counts by type and total within the window" do
      Security.record(%{event_type: :rate_limit_exceeded, ip: "1.1.1.1"})
      Security.record(%{event_type: :rate_limit_exceeded, ip: "1.1.1.1"})
      Security.record(%{event_type: :auth_failed, subject_type: :merchant, identifier: "a@b.com"})

      o = Security.overview(DateTime.utc_now())

      assert o.total == 3
      assert o.by_type.rate_limit_exceeded == 2
      assert o.by_type.auth_failed == 1
    end

    test "excludes events outside the 24h window" do
      Security.record(%{event_type: :rate_limit_exceeded, ip: "1.1.1.1"})
      o = Security.overview(~U[2030-01-01 00:00:00Z])
      assert o.total == 0
    end

    test "ranks top IPs and flags anomalies (>= threshold)" do
      for _ <- 1..10, do: Security.record(%{event_type: :rate_limit_exceeded, ip: "9.9.9.9"})
      Security.record(%{event_type: :rate_limit_exceeded, ip: "8.8.8.8"})

      o = Security.overview(DateTime.utc_now())

      top = hd(o.top_ips)
      assert top.ip == "9.9.9.9"
      assert top.count == 10
      assert top.flagged == true

      low = Enum.find(o.top_ips, &(&1.ip == "8.8.8.8"))
      assert low.flagged == false
      assert o.anomaly_count >= 1
    end

    test "recent is newest-first" do
      Security.record(%{event_type: :auth_failed, identifier: "older"})
      Security.record(%{event_type: :rate_limit_exceeded, identifier: "newer"})

      o = Security.overview(DateTime.utc_now())
      assert hd(o.recent).identifier == "newer"
    end
  end
end
