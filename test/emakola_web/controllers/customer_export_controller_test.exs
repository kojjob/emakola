defmodule EmakolaWeb.CustomerExportControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.AuthTokens

  @path "/admin/export/customers.csv"

  test "no session is 401", %{conn: conn} do
    assert response(get(conn, @path), 401) == "Unauthorized"
  end

  test "a merchant downloads their customers with paid money", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama Serwaa", phone: "+233241111111"})

    create_order!(store, %{
      subtotal: 12_550,
      total: 12_550,
      status: :confirmed,
      customer_id: customer.id
    })

    create_order!(store, %{subtotal: 900, total: 900, status: :pending, customer_id: customer.id})

    {_other_merchant, other_store} = create_merchant_with_store!()
    create_customer!(other_store, %{name: "Not Yours"})

    signed = merchant |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

    conn =
      conn
      |> init_test_session(%{})
      |> put_session(:user_token, signed)
      |> get(@path)

    assert response_content_type(conn, :csv) =~ "text/csv"
    body = response(conn, 200)
    assert body =~ "name,phone,email,orders,paid_total_ghs,last_bought,joined"
    assert body =~ "Ama Serwaa,+233241111111,"
    assert body =~ ",2,125.50,"
    refute body =~ "Not Yours"
  end

  test "a name that looks like a formula is exported as text", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    create_customer!(store, %{name: "=HYPERLINK(\"http://evil\")", phone: "+233241111111"})
    signed = merchant |> AshAuthentication.user_to_subject() |> AuthTokens.sign_subject()

    body =
      conn
      |> init_test_session(%{})
      |> put_session(:user_token, signed)
      |> get(@path)
      |> response(200)

    assert body =~ "'=HYPERLINK"
  end
end
