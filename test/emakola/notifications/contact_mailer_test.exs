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
      assert {_, "ama@example.com"} = hd(email.reply_to)
      assert email.subject =~ "Help with payouts"
      assert email.text_body =~ "How do payouts work?"
      assert email.text_body =~ "ama@example.com"
    end)
  end
end
