defmodule EmakolaWeb.Plugs.UtmCaptureTest do
  @moduledoc """
  Pins the contract for `UtmCapture`:

    * Captures all 5 utm_* params plus the `?ref=whatsapp` shortcut
    * First-touch wins — second request without UTMs doesn't clear session
    * New UTMs from a later request overwrite earlier values (last source attribution)
    * Stamps `first_seen_at` on first capture, never overwrites it
    * Empty params or non-binary values are no-ops
    * `from_session/1` returns %{} when session has no captured attribution
  """
  use EmakolaWeb.ConnCase, async: true

  alias EmakolaWeb.Plugs.UtmCapture

  setup %{conn: conn} do
    {:ok, conn: init_test_session(conn, %{})}
  end

  describe "call/2 — capture" do
    test "captures all 5 utm_* params", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{
          "utm_source" => "instagram",
          "utm_medium" => "bio_link",
          "utm_campaign" => "spring-2026",
          "utm_content" => "story-2",
          "utm_term" => "ankara dress"
        })
        |> UtmCapture.call([])

      attribution = UtmCapture.from_session(conn)

      assert attribution["utm_source"] == "instagram"
      assert attribution["utm_medium"] == "bio_link"
      assert attribution["utm_campaign"] == "spring-2026"
      assert attribution["utm_content"] == "story-2"
      assert attribution["utm_term"] == "ankara dress"
      assert attribution["first_seen_at"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
    end

    test "captures an Earn share token for checkout attribution", %{conn: conn} do
      conn = conn |> Map.put(:params, %{"share" => "safe-share-token"}) |> UtmCapture.call([])
      conn = UtmCapture.call(conn, [])

      assert UtmCapture.from_session(conn)["share_token"] == "safe-share-token"
      assert Plug.Conn.get_session(conn, "earn_share_clicks") == ["safe-share-token"]
    end

    test "captures only valid sales-team attribution identifiers", %{conn: conn} do
      team_id = Ecto.UUID.generate()

      valid =
        conn
        |> Map.put(:params, %{"sales_team" => team_id})
        |> UtmCapture.call([])

      assert UtmCapture.from_session(valid)["sales_team_id"] == team_id

      invalid =
        init_test_session(build_conn(), %{})
        |> Map.put(:params, %{"sales_team" => "not-a-uuid"})
        |> UtmCapture.call([])

      assert UtmCapture.from_session(invalid) == %{}
    end

    test "captures only the params that are present", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"utm_source" => "tiktok"})
        |> UtmCapture.call([])

      attribution = UtmCapture.from_session(conn)

      assert attribution["utm_source"] == "tiktok"
      refute Map.has_key?(attribution, "utm_medium")
    end

    test "ignores empty string utm values", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"utm_source" => "", "utm_medium" => "story"})
        |> UtmCapture.call([])

      attribution = UtmCapture.from_session(conn)

      refute Map.has_key?(attribution, "utm_source")
      assert attribution["utm_medium"] == "story"
    end

    test "is a no-op when no utm or ref params are present", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"page" => "1"})
        |> UtmCapture.call([])

      assert UtmCapture.from_session(conn) == %{}
    end

    test "captures click_to_whatsapp when ?ref=whatsapp", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"ref" => "whatsapp", "utm_source" => "whatsapp"})
        |> UtmCapture.call([])

      attribution = UtmCapture.from_session(conn)

      assert attribution["click_to_whatsapp"] == true
      assert attribution["utm_source"] == "whatsapp"
    end

    test "ignores other ref values", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"ref" => "google", "utm_source" => "google"})
        |> UtmCapture.call([])

      attribution = UtmCapture.from_session(conn)

      refute Map.has_key?(attribution, "click_to_whatsapp")
    end
  end

  describe "call/2 — first-touch / last-source semantics" do
    test "first-touch: a later request without UTMs does not clear session", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"utm_source" => "instagram"})
        |> UtmCapture.call([])

      attribution_after_first = UtmCapture.from_session(conn)
      assert attribution_after_first["utm_source"] == "instagram"

      # Second request with no UTM params
      conn =
        conn
        |> Map.put(:params, %{})
        |> UtmCapture.call([])

      attribution_after_second = UtmCapture.from_session(conn)
      assert attribution_after_second["utm_source"] == "instagram"
      # first_seen_at preserved from first request
      assert attribution_after_second["first_seen_at"] == attribution_after_first["first_seen_at"]
    end

    test "last-source: new UTMs overwrite the older values", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"utm_source" => "instagram"})
        |> UtmCapture.call([])

      first_seen = UtmCapture.from_session(conn)["first_seen_at"]

      conn =
        conn
        |> Map.put(:params, %{"utm_source" => "tiktok", "utm_campaign" => "drop-3"})
        |> UtmCapture.call([])

      attribution = UtmCapture.from_session(conn)

      assert attribution["utm_source"] == "tiktok"
      assert attribution["utm_campaign"] == "drop-3"
      # first_seen_at preserved, NOT overwritten
      assert attribution["first_seen_at"] == first_seen
    end
  end

  describe "from_session/1" do
    test "returns empty map when nothing was captured", %{conn: conn} do
      assert UtmCapture.from_session(conn) == %{}
    end
  end
end
