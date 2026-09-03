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

  test "deliver_founding_seller_letter/2 sends the letter with a WhatsApp link in the text" do
    {:ok, _} =
      MarketingMailer.deliver_founding_seller_letter("ama@example.com", %{
        first_name: "Ama",
        sender_name: "Kojo",
        honest_line: "Cash on delivery works today."
      })

    assert_email_sent(fn email ->
      assert email.subject == "Free shop, set up for you."
      assert email.html_body =~ "Hi Ama,"
      assert email.text_body =~ "https://wa.me/233200000000"
      assert email.text_body =~ "Cash on delivery works today."
    end)
  end

  test "deliver_campaign_push/2 sends the campaign with its tiles in the text" do
    {:ok, _} =
      MarketingMailer.deliver_campaign_push("ama@example.com", %{
        campaign_name: "Christmas orders",
        headline: "Get your shop ready for December.",
        tiles: [%{title: "Put up five items", line: "A photo is enough."}],
        cta_label: "Open my shop",
        cta_url: "https://makola.io/admin"
      })

    assert_email_sent(fn email ->
      assert email.subject == "Get your shop ready for December."
      assert email.html_body =~ "Christmas orders"
      assert email.text_body =~ "- Put up five items: A photo is enough."
      assert email.text_body =~ "https://makola.io/admin"
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
