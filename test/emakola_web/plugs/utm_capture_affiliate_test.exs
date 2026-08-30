defmodule EmakolaWeb.Plugs.UtmCaptureAffiliateTest do
  @moduledoc """
  An affiliate link's token has to survive the walk from click to checkout,
  or nobody gets paid. This is the first leg: URL → session.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias Emakola.Affiliates
  alias Emakola.Affiliates.Programme
  alias EmakolaWeb.Plugs.UtmCapture

  setup do
    {_merchant, store} = create_merchant_with_store!()
    product = create_product!(store, status: :active, title: "Kente Cloth")

    {:ok, affiliate} =
      Affiliates.register(%{
        phone: "0201234567",
        name: "Ama",
        momo_number: "0201234567",
        momo_provider: "mtn"
      })

    {:ok, _programme} = Programme.enable(store.id, 1_000)
    {:ok, link} = Programme.link_for(affiliate, store.id, product.id)

    %{link: link, affiliate: affiliate, store: store}
  end

  defp run(conn, params) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Map.put(:params, params)
    |> Map.put(:query_params, params)
    |> UtmCapture.call([])
  end

  test "captures an affiliate token into the session", %{conn: conn, link: link} do
    conn = run(conn, %{"aff" => link.token})

    assert UtmCapture.from_session(conn)["affiliate_token"] == link.token
  end

  test "counts the click once per session, not once per page view", %{conn: conn, link: link} do
    conn = run(conn, %{"aff" => link.token})
    # Same session, same token, second page: the affiliate did not earn a
    # second click by the buyer navigating.
    _conn = run(conn, %{"aff" => link.token})

    {:ok, reloaded} = Programme.find_link(link.token)
    assert reloaded.click_count == 1
  end

  test "an unknown token is captured but counts nothing", %{conn: conn} do
    # A stranger typing ?aff=whatever must not create a row or raise.
    conn = run(conn, %{"aff" => "not-a-real-token"})

    assert UtmCapture.from_session(conn)["affiliate_token"] == "not-a-real-token"
    assert {:error, :not_found} = Programme.find_link("not-a-real-token")
  end

  test "a share token and an affiliate token can coexist", %{conn: conn, link: link} do
    # The two systems attribute independently; one must not clobber the other.
    conn = run(conn, %{"aff" => link.token, "share" => "some-share-token"})

    attribution = UtmCapture.from_session(conn)
    assert attribution["affiliate_token"] == link.token
    assert attribution["share_token"] == "some-share-token"
  end
end
