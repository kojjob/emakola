defmodule Emakola.Stores.DomainResolverNoSandboxTest do
  @moduledoc """
  `SEO.Canonical` used to be a pure function over config. Resolving a store's
  primary custom domain made it read the database, which means every caller
  without database access now depends on that read succeeding.

  It was only ever intermittent: the answer is cached, so the query happens on
  a cold cache. Whether a given test hit the database at all came down to
  whether some earlier test had warmed the same key — so this failed on
  unrelated pull requests, at random, and passed on re-run.

  Deliberately NOT a DataCase: no sandbox is the whole point.
  """
  use ExUnit.Case, async: false

  alias Emakola.Cache.StoreCache
  alias Emakola.Stores.DomainResolver

  setup do
    StoreCache.invalidate_all()
    on_exit(&StoreCache.invalidate_all/0)
    :ok
  end

  test "primary_host/1 falls back instead of crashing when it cannot reach the database" do
    assert DomainResolver.primary_host("some-store-slug") == nil
  end

  test "lookup/1 falls back instead of crashing" do
    assert DomainResolver.lookup("kentekingdom.com") == :none
  end

  test "canonical still produces a URL with no database" do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

    assert EmakolaWeb.SEO.Canonical.store_url(%{slug: "kente-shop"}) ==
             "http://kente-shop.makola.io"
  end
end
