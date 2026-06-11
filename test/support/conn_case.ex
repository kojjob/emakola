defmodule EmakolaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EmakolaWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint EmakolaWeb.Endpoint

      use EmakolaWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import EmakolaWeb.ConnCase
    end
  end

  setup tags do
    Emakola.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Assigns a peer IP that is unique for the whole test run, isolating per-IP
  rate-limit buckets (Hammer's ETS table is global and never reset between
  tests). Sets both `remote_ip` (plugs/controllers) and the Plug.Test peer
  data (LiveView `get_connect_info(:peer_data)`).

  Do NOT build "unique" IPs from `:rand` — ExUnit seeds `:rand`
  deterministically per test from the suite seed, so two tests can draw the
  same IP and share a rate-limit bucket (flaky for ~1 in 5000 seeds).
  """
  def put_unique_peer_ip(conn) do
    n = System.unique_integer([:positive])
    ip = {10, rem(div(n, 65_536), 256), rem(div(n, 256), 256), rem(n, 256)}

    conn
    |> Map.replace!(:remote_ip, ip)
    |> Plug.Test.put_peer_data(%{address: ip, port: 54321, ssl_cert: nil})
  end
end
