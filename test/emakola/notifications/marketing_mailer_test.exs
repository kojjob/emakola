defmodule Emakola.Notifications.MarketingMailerTest do
  use ExUnit.Case, async: true
  import Swoosh.TestAssertions

  alias Emakola.Notifications.MarketingMailer

  test "deliver_picture_first/2 sends the picture-first template with a text fallback" do
    {:ok, _} =
      MarketingMailer.deliver_picture_first("ama@example.com", %{
        subject: "Your shop, one link, free",
        headline: "Your shop. One link. Free.",
        body: "Customers pick and order from your link.",
        cta_label: "Set up my shop",
        cta_url: "https://makola.io/register"
      })

    assert_email_sent(fn email ->
      assert {_, "ama@example.com"} = hd(email.to)
      assert {"Makola.io", _} = email.from
      assert email.subject == "Your shop, one link, free"
      assert email.html_body =~ "Your shop. One link. Free."
      assert email.html_body =~ "cowrie-coin.png"
      assert email.text_body =~ "Your shop. One link. Free."
      assert email.text_body =~ "https://makola.io/register"
    end)
  end

  test "deliver_update/2 falls back to the headline as the subject" do
    {:ok, _} =
      MarketingMailer.deliver_update("kofi@example.com", %{
        headline: "Orders now show on your phone",
        body: "Open the app and you see every order.",
        items: [%{title: "Cash on delivery", line: "On every checkout.", url: nil}]
      })

    assert_email_sent(fn email ->
      assert email.subject == "Orders now show on your phone"
      assert email.html_body =~ "Also this month"
      assert email.text_body =~ "Cash on delivery"
    end)
  end
end
