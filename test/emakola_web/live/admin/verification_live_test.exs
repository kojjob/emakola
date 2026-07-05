defmodule EmakolaWeb.Admin.VerificationLiveTest do
  @moduledoc """
  Merchant KYC page: submit (with a private ID upload) → pending; a rejected
  submission shows the reason + a resubmit form.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Mox
  import Phoenix.LiveViewTest

  alias Emakola.Stores

  setup :verify_on_exit!

  @small_png Base.decode64!(
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
             )

  setup %{conn: conn} do
    {conn, _merchant, store} = setup_authenticated_merchant(conn)
    %{conn: conn, store: store}
  end

  test "a store with no submission sees the form", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/verification")
    assert html =~ "Submit for review"
  end

  test "submitting with an ID document creates a pending verification", %{
    conn: conn,
    store: store
  } do
    stub(Emakola.StorageMock, :upload, fn _binary, _path, _opts ->
      {:ok, "https://s3.example/key"}
    end)

    {:ok, view, _html} = live(conn, ~p"/admin/verification")
    Mox.allow(Emakola.StorageMock, self(), view.pid)

    upload =
      file_input(view, "#verification-form", :id_document, [
        %{name: "id.png", content: @small_png, type: "image/png"}
      ])

    render_upload(upload, "id.png")

    html =
      view
      |> element("#verification-form")
      |> render_submit(%{
        "verification" => %{
          "business_name" => "Ama Trades",
          "id_type" => "ghana_card",
          "id_number" => "GHA-123"
        }
      })

    assert html =~ "under review"

    assert {:ok, v} = Stores.get_store_verification(store.id, authorize?: false)
    assert v.status == :pending
    assert v.business_name == "Ama Trades"
    assert v.id_document_key
  end

  test "requires an ID document", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/verification")

    html =
      view
      |> element("#verification-form")
      |> render_submit(%{
        "verification" => %{
          "business_name" => "Ama",
          "id_type" => "ghana_card",
          "id_number" => "X"
        }
      })

    assert html =~ "attach a photo or PDF"
  end

  test "a rejected submission shows the reason and a resubmit form", %{conn: conn, store: store} do
    {:ok, v} =
      Stores.submit_store_verification(
        %{
          store_id: store.id,
          business_name: "A",
          id_type: :ghana_card,
          id_number: "X",
          id_document_key: "k"
        },
        authorize?: false
      )

    {:ok, _} = Stores.reject_store_verification(v, %{reason: "Blurry photo"}, authorize?: false)

    {:ok, _view, html} = live(conn, ~p"/admin/verification")
    assert html =~ "Blurry photo"
    assert html =~ "Resubmit for review"
  end
end
