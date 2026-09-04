defmodule EmakolaWeb.Admin.VerificationLiveTest do
  @moduledoc """
  Merchant business-details page: submit a shop name → pending; a rejected
  submission shows the reason + a resubmit form.

  The page collects no documents at all. The national-ID fields went because
  L.I. 2523 makes requesting them an offence; the "business paper" upload went
  because it landed in the same public bucket as everything else, and a sole
  trader's licence or tax receipt is their identity by another name. These
  tests pin that neither can come back.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Mox
  import Phoenix.LiveViewTest

  alias Emakola.Stores

  setup :verify_on_exit!

  setup %{conn: conn} do
    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  test "a store with no submission sees the form", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/verification")
    assert html =~ "Send for review"
  end

  test "the page never asks for a national ID", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/admin/verification")

    refute html =~ "Ghana Card"
    refute html =~ "ID number"
    refute html =~ "ID type"
    refute has_element?(view, "#verification-form input[name='verification[id_number]']")
    refute has_element?(view, "#verification-form select[name='verification[id_type]']")
  end

  test "points the merchant at the wallet proof instead", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/verification")
    assert has_element?(view, ~s{a[href="/admin/payouts"]})
  end

  test "submitting a shop name alone creates a pending verification", %{
    conn: conn,
    store: store
  } do
    {:ok, view, _html} = live(conn, ~p"/admin/verification")

    html =
      view
      |> element("#verification-form")
      |> render_submit(%{"verification" => %{"business_name" => "Ama Trades"}})

    assert html =~ "checking your details"

    assert {:ok, v} = Stores.get_store_verification(store.id, authorize?: false)
    assert v.status == :pending
    assert v.business_name == "Ama Trades"
    assert is_nil(v.id_document_key)
    assert is_nil(v.id_number)
  end

  test "the page never asks for a document of any kind", %{conn: conn} do
    # verify_on_exit! with no StorageMock stub: if this page touched storage
    # in any way, the test would fail on exit.
    {:ok, view, html} = live(conn, ~p"/admin/verification")

    refute has_element?(view, "#verification-form input[type='file']")
    refute has_element?(view, "#verification-form [phx-drop-target]")
    refute html =~ "Business paper"
    refute html =~ "Take a photo"
  end

  test "requires a shop name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/verification")

    html =
      view
      |> element("#verification-form")
      |> render_submit(%{"verification" => %{"business_name" => ""}})

    assert html =~ "enter your shop name"
  end

  test "a rejected submission shows the reason and a resubmit form", %{conn: conn, store: store} do
    {:ok, v} =
      Stores.submit_store_verification(
        %{store_id: store.id, business_name: "A"},
        authorize?: false
      )

    {:ok, _} =
      Stores.reject_store_verification(v, %{reason: "Name unreadable"}, authorize?: false)

    {:ok, _view, html} = live(conn, ~p"/admin/verification")
    assert html =~ "Name unreadable"
    assert html =~ "Send again"
  end
end
