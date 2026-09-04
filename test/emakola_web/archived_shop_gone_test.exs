defmodule EmakolaWeb.ArchivedShopGoneTest do
  @moduledoc """
  An archived shop used to answer with a redirect to the homepage. Google
  reads a redirect as "page moved" and keeps the old URLs around for weeks.
  410 Gone says the shop is finished, and the URLs drop on the next crawl.
  A slug that never existed is a different case and keeps its redirect.
  """
  # async: false — configures :store_subdomain_base for the branded-host case.
  use EmakolaWeb.ConnCase, async: false

  import Emakola.Factory

  alias EmakolaWeb.Helpers.StoreResolver

  setup do
    previous = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")

    on_exit(fn ->
      if previous,
        do: Application.put_env(:emakola, :store_subdomain_base, previous),
        else: Application.delete_env(:emakola, :store_subdomain_base)
    end)

    archived =
      create_store!()
      |> Ash.Changeset.for_update(:archive, %{reason: "closed"})
      |> Ash.update!(authorize?: false)

    {:ok, archived: archived}
  end

  test "the resolver tells an archived shop apart from one that never existed", %{
    archived: archived
  } do
    assert {:error, :gone} = StoreResolver.resolve(archived.slug)
    assert {:error, :not_found} = StoreResolver.resolve("never-was-a-shop")
  end

  test "the short URL of an archived shop answers 410", %{conn: conn, archived: archived} do
    assert_error_sent 410, fn -> get(conn, "/#{archived.slug}") end
  end

  test "the branded host of an archived shop answers 410", %{conn: conn, archived: archived} do
    assert_error_sent 410, fn -> %{conn | host: "#{archived.slug}.makola.io"} |> get("/") end
  end

  test "a slug that never existed still goes home", %{conn: conn} do
    conn = get(conn, "/never-was-a-shop")
    assert redirected_to(conn, 302) == "/"
  end
end
