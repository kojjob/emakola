defmodule EmakolaWeb.HonestMarketingCopyTest do
  @moduledoc """
  "Join over 500+ merchants" and "Seconds from checkout to payout" are not
  true, and the Terms/Privacy links under the signup button pointed at "#".
  The signup page is the first thing every new merchant reads; it does not
  get to open with a lie or a dead link.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "no page claims a merchant count", %{conn: conn} do
    for path <- ["/auth/register", "/auth/login"] do
      {:ok, _view, html} = live(Phoenix.ConnTest.init_test_session(conn, %{}), path)
      refute html =~ "500+", "#{path} still claims a merchant count"
    end

    landing = conn |> get("/") |> html_response(200)
    refute landing =~ "500+", "the landing stats band still claims a merchant count"
    refute landing =~ "Seconds", "the landing stats band still promises payout in seconds"
  end

  test "Terms and Privacy under the forms link to the real pages", %{conn: conn} do
    for path <- ["/auth/register", "/auth/login"] do
      {:ok, view, _html} = live(Phoenix.ConnTest.init_test_session(conn, %{}), path)

      assert has_element?(view, ~s{a[href="/terms"]}, "Terms of Service"),
             "#{path}: Terms of Service does not link to /terms"

      assert has_element?(view, ~s{a[href="/privacy"]}, "Privacy Policy"),
             "#{path}: Privacy Policy does not link to /privacy"
    end
  end
end
