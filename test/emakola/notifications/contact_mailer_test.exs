defmodule Emakola.Notifications.ContactMailerTest do
  use ExUnit.Case, async: true
  import Swoosh.TestAssertions

  alias Emakola.Notifications.ContactMailer

  test "delivers a contact message to the configured address with reply-to" do
    {:ok, _} =
      ContactMailer.deliver_contact_message(%{
        name: "Ama",
        email: "ama@example.com",
        subject: "Help with payouts",
        message: "How do payouts work?"
      })

    assert_email_sent(fn email ->
      assert {_, "support@emakola.com"} = hd(email.to)
      # reply_to must be a SINGLE recipient tuple, not a list — the Resend
      # adapter's format_recipient/1 has no clause for a list and raises in prod.
      assert {_, "ama@example.com"} = email.reply_to
      assert email.subject =~ "Help with payouts"
      assert email.text_body =~ "How do payouts work?"
      assert email.text_body =~ "ama@example.com"
    end)
  end
end
