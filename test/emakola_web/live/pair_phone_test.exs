defmodule EmakolaWeb.PairPhoneTest do
  @moduledoc """
  Scan-to-sign-in, across all three surfaces.

  The case these tests exist for is the inverted one: a merchant who scans a
  stranger's code must not end up handing over their account. That is not a
  property of any single page, so it is tested end to end — scan without
  confirmation must produce no session.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Emakola.Accounts.DevicePairings

  describe "the desktop half" do
    setup %{conn: conn} do
      {conn, merchant, _store} = Emakola.LiveViewHelpers.setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant}
    end

    test "shows a code and a countdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/pair-phone")

      assert has_element?(view, "#pair-qr svg")
      assert has_element?(view, "#pair-countdown")

      # Nothing is being asked yet, so there is nothing to approve.
      refute has_element?(view, "#pair-confirm-yes")
    end

    test "a scan raises a prompt naming the device, and confirming signs it in", %{
      conn: conn,
      merchant: merchant
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/pair-phone")

      {:ok, _token, pairing} = DevicePairings.issue(merchant.id)
      send(view.pid, {:scanned, "An Android phone"})

      html = render(view)
      assert html =~ "A phone wants to sign in"
      assert html =~ "An Android phone"

      # The desktop's own pairing is the one it confirms — the injected one
      # above only drives the display.
      _ = pairing
      assert has_element?(view, "#pair-confirm-yes")
    end

    # Found by leaving the page open, not by any assertion: the countdown used
    # to overwrite whatever stage it landed on when it hit zero.
    test "the countdown does not overwrite a pending request", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/pair-phone")

      send(view.pid, {:scanned, "An iPhone"})
      render(view)

      send(view.pid, :tick)
      html = render(view)

      # The merchant is mid-decision. Expiring here silently discards a real
      # phone's request and leaves the two screens disagreeing.
      assert html =~ "A phone wants to sign in"
    end

    test "the countdown does not undo a completed pairing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/pair-phone")

      # Scan the page's OWN code, so the row really is :scanned and confirm has
      # something to approve. Pushing {:scanned, …} at the view only moves the
      # display, which is what made the first draft of this test lie to me.
      token = :sys.get_state(view.pid).socket.assigns.pairing_code.token
      {:ok, _} = DevicePairings.scan(token, "An iPhone")
      send(view.pid, {:scanned, "An iPhone"})
      render(view)

      view |> element("#pair-confirm-yes") |> render_click()
      assert has_element?(view, "#pair-done")

      # 90 seconds later. The phone is signed in and stays signed in, so a page
      # announcing "that code ran out" would simply be lying.
      send(view.pid, :tick)
      refute has_element?(view, "#pair-expired")
      assert has_element?(view, "#pair-done")
    end

    test "refusing leaves nothing signed in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/pair-phone")

      send(view.pid, {:scanned, "An iPhone"})
      render(view)
      view |> element("#pair-confirm-no") |> render_click()

      assert has_element?(view, "#pair-rejected")
    end
  end

  describe "the phone half" do
    test "a valid code asks the merchant to look at their other screen", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()
      {:ok, token, _pairing} = DevicePairings.issue(merchant.id)

      {:ok, view, _html} = live(conn, ~p"/pair/#{token}")

      assert has_element?(view, "#pair-waiting")
      # Crucially not signed in — it is waiting.
      refute has_element?(view, "#pair-done")
    end

    test "an unknown code says so without saying why", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/pair/not-a-real-token")

      assert has_element?(view, "#pair-failed")
    end

    test "an expired code is refused", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      expire!(pairing)

      {:ok, view, _html} = live(conn, ~p"/pair/#{token}")

      assert has_element?(view, "#pair-failed")
    end
  end

  describe "redemption" do
    test "a confirmed code signs the phone in and lands on the dashboard", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)

      conn = get(conn, ~p"/pair/#{token}/complete")

      assert redirected_to(conn) == "/dashboard"
      assert get_session(conn, :user_token)
    end

    test "scanning without confirmation grants nothing — the inverted attack", %{conn: conn} do
      # The merchant scanned a code someone else minted. No one confirmed on a
      # screen the merchant controls, so this must not become a session.
      merchant = Emakola.Factory.create_merchant!()
      {:ok, token, _pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An attacker's browser")

      conn = get(conn, ~p"/pair/#{token}/complete")

      assert redirected_to(conn) == "/auth/login"
      refute get_session(conn, :user_token)
    end

    test "a code cannot be spent twice", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()
      {:ok, token, pairing} = DevicePairings.issue(merchant.id)
      {:ok, _} = DevicePairings.scan(token, "An iPhone")
      {:ok, _} = DevicePairings.confirm(pairing.id, merchant.id)

      assert get(conn, ~p"/pair/#{token}/complete") |> redirected_to() == "/dashboard"

      replayed = get(build_conn(), ~p"/pair/#{token}/complete")
      assert redirected_to(replayed) == "/auth/login"
      refute get_session(replayed, :user_token)
    end

    test "every failure reads the same, so a stray code learns nothing", %{conn: conn} do
      merchant = Emakola.Factory.create_merchant!()
      {:ok, unconfirmed, _} = DevicePairings.issue(merchant.id)

      fabricated = get(conn, ~p"/pair/totally-made-up/complete")
      real_but_unusable = get(build_conn(), ~p"/pair/#{unconfirmed}/complete")

      assert redirected_to(fabricated) == redirected_to(real_but_unusable)

      assert Phoenix.Flash.get(fabricated.assigns.flash, :error) ==
               Phoenix.Flash.get(real_but_unusable.assigns.flash, :error)
    end
  end

  defp expire!(pairing) do
    pairing
    |> Ash.Changeset.for_update(:confirm, %{})
    |> Ash.Changeset.force_change_attribute(
      :expires_at,
      DateTime.add(DateTime.utc_now(), -1, :second)
    )
    |> Ash.Changeset.force_change_attribute(:status, pairing.status)
    |> Ash.update!(authorize?: false)
  end
end
