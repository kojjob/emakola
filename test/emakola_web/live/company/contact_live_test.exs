defmodule EmakolaWeb.Company.ContactLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  test "renders form and support channels", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/contact")
    assert html =~ "Contact us"
    assert html =~ ~s(name="contact[email]")
    assert html =~ "wa.me"
    assert html =~ ~s(href="mailto:support@emakola.com")
  end

  test "valid submission sends an email and shows success", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    html =
      view
      |> form("#contact-form",
        contact: %{
          name: "Ama",
          email: "ama@example.com",
          subject: "Hi",
          message: "Hello there",
          company_url: ""
        }
      )
      |> render_submit()

    assert html =~ "Thanks" or html =~ "sent"
    assert_email_sent(fn email -> assert {_, "support@emakola.com"} = hd(email.to) end)
  end

  test "honeypot filled drops the submission silently (no email)", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    view
    |> form("#contact-form",
      contact: %{
        name: "Bot",
        email: "bot@example.com",
        subject: "spam",
        message: "spam",
        company_url: "http://spam.example"
      }
    )
    |> render_submit()

    refute_email_sent()
  end

  test "invalid email shows an error and sends nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    html =
      view
      |> form("#contact-form",
        contact: %{
          name: "Ama",
          email: "not-an-email",
          subject: "Hi",
          message: "Hello",
          company_url: ""
        }
      )
      |> render_submit()

    assert html =~ "valid email"
    refute_email_sent()
  end
end
