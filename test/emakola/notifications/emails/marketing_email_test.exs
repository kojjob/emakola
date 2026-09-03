defmodule Emakola.Notifications.Emails.MarketingEmailTest do
  use ExUnit.Case, async: true

  alias Emakola.Notifications.Emails.MarketingEmail

  defp base_url, do: EmakolaWeb.Endpoint.url()

  describe "picture_first/1" do
    setup do
      html =
        MarketingEmail.picture_first(%{
          headline: "Your shop. One link. Free.",
          body: "Customers pick what they want and order from your link.",
          cta_label: "Set up my shop",
          cta_url: "https://makola.io/register",
          unsubscribe_url: "https://makola.io/email/stop?t=abc"
        })

      %{html: html}
    end

    test "opens with the coin logo served from an absolute URL", %{html: html} do
      assert html =~ "src=\"#{base_url()}/images/email/cowrie-coin.png\""
    end

    test "leads with the photo, then five words, then one button", %{html: html} do
      assert html =~ "src=\"#{base_url()}/images/landing/hero-market-woman.jpg\""
      assert html =~ "Your shop. One link. Free."
      assert html =~ "Customers pick what they want"
      assert html =~ ~s(href="https://makola.io/register")
      assert html =~ "Set up my shop"
    end

    test "walks through the three steps", %{html: html} do
      assert html =~ "Add a photo"
      assert html =~ "Share the link"
      assert html =~ "Get the order"
    end

    test "offers the platform WhatsApp number as a voice-note fallback", %{html: html} do
      assert html =~ ~s(href="https://wa.me/233200000000")
    end

    test "carries the unsubscribe link in the footer", %{html: html} do
      assert html =~ ~s(href="https://makola.io/email/stop?t=abc")
      assert html =~ "Stop these emails"
    end

    test "uses a custom hero photo when one is given" do
      html =
        MarketingEmail.picture_first(%{
          headline: "H",
          body: "B",
          cta_label: "Go",
          cta_url: "https://makola.io",
          hero_url: "https://cdn.example.com/ama.jpg"
        })

      assert html =~ ~s(src="https://cdn.example.com/ama.jpg")
      refute html =~ "hero-market-woman"
    end

    test "escapes merchant-facing copy" do
      html =
        MarketingEmail.picture_first(%{
          headline: "<script>alert(1)</script>",
          body: "Tom & Jerry",
          cta_label: "Go",
          cta_url: "https://makola.io"
        })

      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
      assert html =~ "Tom &amp; Jerry"
    end

    test "never uses table border-spacing, which Outlook drops", %{html: html} do
      refute html =~ "border-spacing"
    end
  end

  describe "update/1" do
    setup do
      html =
        MarketingEmail.update(%{
          update_type: "Update",
          month: "September 2026",
          headline: "Orders now show on your phone",
          body: "Open the app and you see every order.\nNothing to chase.",
          read_more_url: "https://makola.io/blog/orders",
          items: [
            %{
              title: "Cash on delivery",
              line: "Now on every checkout.",
              url: "https://makola.io/a"
            },
            %{title: "Faster photos", line: "Uploads take half the time.", url: nil},
            %{title: "Twi in the app", line: "Switch it in settings.", url: nil}
          ],
          action: %{
            headline: "Open your shop and check the new orders",
            label: "Open my shop",
            url: "https://makola.io/admin"
          },
          unsubscribe_url: "https://makola.io/email/stop?t=abc"
        })

      %{html: html}
    end

    test "opens with the coin logo, the update type, and the month", %{html: html} do
      assert html =~ "src=\"#{base_url()}/images/email/cowrie-coin.png\""
      assert html =~ "Update"
      assert html =~ "September 2026"
    end

    test "leads with the main thing and a read-more link", %{html: html} do
      assert html =~ "The main thing"
      assert html =~ "Orders now show on your phone"
      assert html =~ "Open the app and you see every order.<br>Nothing to chase."
      assert html =~ ~s(href="https://makola.io/blog/orders")
    end

    test "lists the short items, linking only the ones with a URL", %{html: html} do
      assert html =~ "Also this month"
      assert html =~ "Cash on delivery"
      assert html =~ "Faster photos"
      assert html =~ "Twi in the app"
      assert html =~ ~s(href="https://makola.io/a")
    end

    test "closes on one action", %{html: html} do
      assert html =~ "Do this today"
      assert html =~ "Open your shop and check the new orders"
      assert html =~ ~s(href="https://makola.io/admin")
      assert html =~ "Open my shop"
    end

    test "drops the items block entirely when there are none" do
      html = MarketingEmail.update(%{headline: "H", body: "B"})

      refute html =~ "Also this month"
      refute html =~ "Do this today"
      refute html =~ "Read the whole story"
    end

    test "shows the lead photo only when one is given" do
      with_photo =
        MarketingEmail.update(%{headline: "H", body: "B", lead_image_url: "https://x/y.jpg"})

      without = MarketingEmail.update(%{headline: "H", body: "B"})

      assert with_photo =~ ~s(src="https://x/y.jpg")
      refute without =~ "<img src=\"https://x/y.jpg\""
    end

    test "escapes staff-written copy" do
      html = MarketingEmail.update(%{headline: "<b>bold</b>", body: "a < b"})

      refute html =~ "<b>bold</b>"
      assert html =~ "&lt;b&gt;bold&lt;/b&gt;"
      assert html =~ "a &lt; b"
    end
  end
end
