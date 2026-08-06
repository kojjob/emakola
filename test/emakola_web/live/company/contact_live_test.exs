defmodule EmakolaWeb.Company.ContactLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  test "renders form and support channels", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

    assert has_element?(view, "#contact-form")
    assert has_element?(view, "#contact-form input[name='contact[email]']")
    assert has_element?(view, "a[href^='https://wa.me/']")
    assert has_element?(view, "a[href='mailto:support@makola.io']")
  end

  test "valid submission sends an email and shows success", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

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

    assert has_element?(view, "#contact-success")
    assert_email_sent(fn email -> assert {_, "support@makola.io"} = hd(email.to) end)
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

    assert has_element?(view, "#contact-success")
    refute_email_sent()
  end

  test "invalid email shows an error and sends nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/contact")

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

    assert has_element?(view, "#contact-form-error")
    refute_email_sent()
  end
end
