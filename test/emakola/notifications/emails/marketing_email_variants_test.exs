defmodule Emakola.Notifications.Emails.MarketingEmailVariantsTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Emails.MarketingEmail

  describe "founding_seller_letter/1" do
    setup do
      html =
        MarketingEmail.founding_seller_letter(%{
          first_name: "Ama",
          sender_name: "Kojo",
          honest_line:
            "MoMo checkout switches on when Paystack approves us. Cash on delivery works today.",
          reply_time: "a few hours",
          unsubscribe_url: "https://makola.io/email/stop?t=abc"
        })

      %{html: html}
    end

    test "reads as a letter to one person", %{html: html} do
      assert html =~ "Free shop, set up for you."
      assert html =~ "Hi Ama,"
      assert html =~ "If you do not sell, we earn nothing."
    end

    test "lists what founding sellers get", %{html: html} do
      assert html =~ "What founding sellers get"
      assert html =~ "Your shop built for you"
      assert html =~ "The lowest fee we will ever charge, locked in for good"
      assert html =~ "Your customers and your data stay yours"
    end

    test "says the honest line before they ask", %{html: html} do
      assert html =~ "Cash on delivery works today."
    end

    test "makes WhatsApp the only action, signed by the sender", %{html: html} do
      assert html =~ ~s(href="https://wa.me/233200000000")
      assert html =~ "Message me on WhatsApp"
      assert html =~ "I reply within a few hours."
      assert html =~ "Kojo"
      assert html =~ "Founder, Makola.io"
    end

    test "never quotes a fee percentage in the visible copy", %{html: html} do
      visible_text = Regex.replace(~r/<[^>]+>/, html, " ")
      refute visible_text =~ ~r/\d+(\.\d+)?\s*%/
    end

    test "has no honest line block when none is given" do
      html = MarketingEmail.founding_seller_letter(%{first_name: "Ama", sender_name: "Kojo"})
      refute html =~ "Cash on delivery"
      assert html =~ "I reply within a day."
    end
  end

  describe "campaign_push/1" do
    setup do
      html =
        MarketingEmail.campaign_push(%{
          campaign_name: "Christmas orders",
          headline: "Get your shop ready for December.",
          date_line: "1 to 24 December",
          intro: "Two things to do this week so orders find you.",
          tiles: [
            %{
              image_url: "https://cdn/x.jpg",
              title: "Put up your best five items",
              line: "A photo and a price is enough."
            },
            %{image_url: nil, title: "Share your link on Status", line: "Once a day."}
          ],
          cta_label: "Open my shop",
          cta_url: "https://makola.io/admin",
          note: "Delivery slots fill early in December."
        })

      %{html: html}
    end

    test "opens on a navy hero with the large lockup, campaign name, and date", %{html: html} do
      assert html =~ ~s(width="44" height="44")
      assert html =~ "Christmas orders"
      assert html =~ "Get your shop ready for December."
      assert html =~ "1 to 24 December"
    end

    test "numbers the tiles and shows a photo only where one is given", %{html: html} do
      assert html =~ "One"
      assert html =~ "Two"
      assert html =~ ~s(src="https://cdn/x.jpg")
      assert html =~ "Put up your best five items"
      assert html =~ "Share your link on Status"
    end

    test "has one button and a note that points to WhatsApp", %{html: html} do
      assert html =~ ~s(href="https://makola.io/admin")
      assert html =~ "Open my shop"
      assert html =~ "Delivery slots fill early in December."
      assert html =~ ~s(href="https://wa.me/233200000000")
    end

    test "escapes staff copy" do
      html =
        MarketingEmail.campaign_push(%{
          campaign_name: "<x>",
          headline: "a & b",
          cta_label: "Go",
          cta_url: "https://makola.io"
        })

      assert html =~ "&lt;x&gt;"
      assert html =~ "a &amp; b"
      refute html =~ "<x>"
    end
  end
end
