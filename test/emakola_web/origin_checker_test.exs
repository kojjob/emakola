defmodule EmakolaWeb.OriginCheckerTest do
  @moduledoc """
  `check_origin` runs on EVERY LiveView socket connect, and anyone can probe it
  with an arbitrary Host header. So the cheap checks come first and a miss is
  cached — an uncached miss is a database read per probe.

  There is no test-env path that exercises Phoenix's own check_origin (dev sets
  `false`, test sets nothing), so all the logic lives here where it can be
  tested directly. The live half is a real `wss://` handshake after deploy —
  check_origin fails SILENTLY, degrading to longpoll, which then breaks across
  two Fly machines.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Cache.StoreCache
  alias Emakola.Stores
  alias EmakolaWeb.OriginChecker

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    StoreCache.invalidate_all()

    on_exit(fn ->
      Application.delete_env(:emakola, :store_subdomain_base)
      StoreCache.invalidate_all()
    end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-org"})}
  end

  defp uri(url), do: URI.parse(url)

  defp live_domain!(store, host) do
    {:ok, d} = Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)
    {:ok, d} = Stores.request_domain_verification(d, authorize?: false)
    {:ok, d} = Stores.mark_domain_active(d, authorize?: false)
    d
  end

  defp queries_during(fun) do
    parent = self()
    ref = make_ref()

    handler = fn _event, _measure, _meta, _cfg -> send(parent, {ref, :query}) end
    :telemetry.attach({__MODULE__, ref}, [:emakola, :repo, :query], handler, nil)

    try do
      fun.()
      count_messages(ref, 0)
    after
      :telemetry.detach({__MODULE__, ref})
    end
  end

  defp count_messages(ref, acc) do
    receive do
      {^ref, :query} -> count_messages(ref, acc + 1)
    after
      0 -> acc
    end
  end

  describe "platform hosts are allowed without touching the database" do
    for host <- ["makola.io", "www.makola.io", "emakola.fly.dev", "kente-kingdom.makola.io"] do
      test "allows https://#{host} with no query", _ctx do
        assert queries_during(fn ->
                 assert OriginChecker.allowed?(uri("https://#{unquote(host)}"))
               end) == 0
      end
    end
  end

  describe "merchant custom domains" do
    test "an active domain is allowed", %{store: store} do
      _ = live_domain!(store, "kentekingdom.com")
      assert OriginChecker.allowed?(uri("https://kentekingdom.com"))
    end

    test "a pending domain is refused", %{store: store} do
      {:ok, _} =
        Stores.claim_custom_domain(%{store_id: store.id, host: "pending.example"},
          authorize?: false
        )

      refute OriginChecker.allowed?(uri("https://pending.example"))
    end

    test "an expired domain is refused", %{store: store} do
      domain = live_domain!(store, "kentekingdom.com")
      {:ok, _} = Stores.expire_store_domain(domain, %{reason: "revoked"}, authorize?: false)

      refute OriginChecker.allowed?(uri("https://kentekingdom.com"))
    end

    # This is the one that catches a missing cache invalidation: without it the
    # merchant's shop looks fine over HTTP while every interaction is dead.
    test "a domain going live is allowed immediately, not after the TTL", %{store: store} do
      refute OriginChecker.allowed?(uri("https://kentekingdom.com"))
      _ = live_domain!(store, "kentekingdom.com")
      assert OriginChecker.allowed?(uri("https://kentekingdom.com"))
    end
  end

  describe "unknown origins" do
    test "are refused" do
      refute OriginChecker.allowed?(uri("https://evil.example"))
    end

    test "cost nothing to refuse twice" do
      refute OriginChecker.allowed?(uri("https://evil.example"))
      assert queries_during(fn -> OriginChecker.allowed?(uri("https://evil.example")) end) == 0
    end
  end

  describe "scheme" do
    test "plain http is refused even for a known host", %{store: store} do
      _ = live_domain!(store, "kentekingdom.com")
      refute OriginChecker.allowed?(uri("http://kentekingdom.com"))
    end

    test "a garbage origin is refused rather than crashing" do
      refute OriginChecker.allowed?(uri("null"))
      refute OriginChecker.allowed?(%URI{})
    end
  end
end
