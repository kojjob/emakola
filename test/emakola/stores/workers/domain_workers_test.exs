defmodule Emakola.Stores.Workers.DomainWorkersTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Mox
  import Emakola.Factory

  alias Emakola.Infra.FlyCerts.Status
  alias Emakola.Stores
  alias Emakola.Stores.Domains
  alias Emakola.Stores.Workers.DomainCertificateWorker
  alias Emakola.Stores.Workers.DomainSweepWorker

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    Application.put_env(:emakola, :fly_certs, Emakola.Infra.FlyCertsMock)

    on_exit(fn ->
      Application.delete_env(:emakola, :store_subdomain_base)
      Application.delete_env(:emakola, :fly_certs)
    end)

    {:ok, store: create_store!(%{name: "Kente Kingdom", slug: "kente-kingdom-wrk"})}
  end

  defp pending!(store, host \\ "kentekingdom.com") do
    {:ok, d} = Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)
    d
  end

  defp verifying!(store, host \\ "kentekingdom.com") do
    {:ok, d} = store |> pending!(host) |> Stores.request_domain_verification(authorize?: false)
    d
  end

  defp perform(domain),
    do: DomainCertificateWorker.perform(%Oban.Job{args: %{"store_domain_id" => domain.id}})

  defp status(overrides \\ %{}) do
    struct(
      %Status{hostname: "kentekingdom.com", client_status: "Awaiting configuration"},
      overrides
    )
  end

  describe "DomainCertificateWorker" do
    test "asks Fly for a certificate the first time", %{store: store} do
      domain = verifying!(store)

      expect(Emakola.Infra.FlyCertsMock, :get_certificate, fn "kentekingdom.com" -> {:ok, nil} end)

      expect(Emakola.Infra.FlyCertsMock, :add_certificate, fn "kentekingdom.com" ->
        {:ok, status()}
      end)

      assert :ok = perform(domain)
      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :verifying
    end

    # Re-requesting would burn Let's Encrypt quota for no reason.
    test "never asks twice for the same certificate", %{store: store} do
      domain = verifying!(store)

      expect(Emakola.Infra.FlyCertsMock, :get_certificate, 2, fn _ ->
        {:ok, status()}
      end)

      expect(Emakola.Infra.FlyCertsMock, :add_certificate, 0, fn _ -> {:ok, status()} end)

      assert :ok = perform(domain)
      assert :ok = perform(domain)
    end

    test "goes live when Fly reports Ready", %{store: store} do
      domain = verifying!(store)

      expect(Emakola.Infra.FlyCertsMock, :get_certificate, fn _ ->
        {:ok, status(%{client_status: "Ready", ready?: true, configured?: true})}
      end)

      assert :ok = perform(domain)
      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :active
      assert reloaded.verified_at
    end

    test "records a readable reason while it waits", %{store: store} do
      domain = verifying!(store)

      expect(Emakola.Infra.FlyCertsMock, :get_certificate, fn _ ->
        {:ok, status(%{validation_errors: ["no AAAA record found"]})}
      end)

      assert :ok = perform(domain)
      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :verifying
      assert reloaded.status_reason =~ "AAAA"
    end

    test "surfaces a rate limit rather than hiding it", %{store: store} do
      domain = verifying!(store)

      expect(Emakola.Infra.FlyCertsMock, :get_certificate, fn _ ->
        {:ok, status(%{rate_limited_until: "2026-08-30T00:00:00Z"})}
      end)

      assert :ok = perform(domain)
      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status_reason =~ "2026-08-30"
    end

    test "cancels for a domain that is not being verified", %{store: store} do
      domain = pending!(store)
      assert {:cancel, _} = perform(domain)
    end

    test "cancels rather than retrying when Fly errors", %{store: store} do
      domain = verifying!(store)

      expect(Emakola.Infra.FlyCertsMock, :get_certificate, fn _ -> {:error, :timeout} end)

      assert {:cancel, _} = perform(domain)
      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :verifying
    end

    test "does nothing at all when Fly is not configured", %{store: store} do
      Application.delete_env(:emakola, :fly_certs)
      domain = verifying!(store)

      # No Mox expectations: any call would fail verify_on_exit!.
      assert :ok = perform(domain)
    end
  end

  describe "DomainSweepWorker" do
    test "enqueues a certificate check for each verifying domain", %{store: store} do
      domain = verifying!(store)
      _pending = pending!(store, "not-yet.example")

      assert :ok = DomainSweepWorker.perform(%Oban.Job{args: %{}})

      assert_enqueued(
        worker: DomainCertificateWorker,
        args: %{"store_domain_id" => domain.id}
      )
    end

    test "ignores subdomains entirely", %{store: store} do
      {:ok, _} =
        Stores.create_store_domain(%{store_id: store.id, host: "kente-kingdom-wrk.makola.io"},
          authorize?: false
        )

      assert :ok = DomainSweepWorker.perform(%Oban.Job{args: %{}})
      refute_enqueued(worker: DomainCertificateWorker)
    end

    test "retires a domain whose DNS was never connected", %{store: store} do
      domain = verifying!(store)

      long_ago = DateTime.add(DateTime.utc_now(), -30, :day)

      {:ok, _} =
        domain
        |> Ash.Changeset.for_update(:record_check, %{}, authorize?: false)
        |> Ash.Changeset.force_change_attribute(:verifying_since, long_ago)
        |> Ash.update(authorize?: false)

      expect(Emakola.Infra.FlyCertsMock, :delete_certificate, fn "kentekingdom.com" -> :ok end)

      assert :ok = DomainSweepWorker.perform(%Oban.Job{args: %{}})

      assert {:ok, reloaded} = Ash.get(Stores.StoreDomain, domain.id, authorize?: false)
      assert reloaded.status == :expired
      assert reloaded.status_reason =~ "not connected"
    end

    test "a retired host can be claimed by someone else", %{store: store} do
      domain = verifying!(store)
      other = create_store!(%{name: "Other", slug: "other-store-wrk"})

      expect(Emakola.Infra.FlyCertsMock, :delete_certificate, fn _ -> :ok end)
      {:ok, _} = Domains.expire(domain, "released")

      assert {:ok, _} =
               Stores.claim_custom_domain(%{store_id: other.id, host: "kentekingdom.com"},
                 authorize?: false
               )
    end
  end

  describe "the service seams the workers hook into" do
    test "approving a domain queues its certificate immediately", %{store: store} do
      # Waiting up to 10 minutes for the cron sweep would look broken to a
      # merchant watching the screen.
      domain = pending!(store)
      {:ok, _} = Domains.request_verification(domain)

      assert_enqueued(worker: DomainCertificateWorker, args: %{"store_domain_id" => domain.id})
    end

    test "retiring a domain frees its Fly certificate slot", %{store: store} do
      domain = verifying!(store)
      expect(Emakola.Infra.FlyCertsMock, :delete_certificate, fn "kentekingdom.com" -> :ok end)
      assert {:ok, _} = Domains.expire(domain, "revoked")
    end
  end
end
