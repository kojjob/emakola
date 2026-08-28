defmodule Emakola.Conversations.VoiceMessageTest do
  @moduledoc """
  A message that is a recording rather than typing.

  The point of the whole feature: a merchant who does not read or write
  fluently can still hold a conversation. That means `body` can no longer be
  required — but a message with neither words nor sound is still nothing, and
  must be refused.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Conversations

  setup do
    {merchant, store} = create_merchant_with_store!()
    customer = create_customer!(store, %{name: "Ama"})
    {:ok, thread} = Conversations.open_shop_thread(store.id, customer.id)

    %{merchant: merchant, store: store, customer: customer, thread: thread}
  end

  defp recording(overrides \\ %{}) do
    Map.merge(
      %{
        "kind" => "audio",
        # A path Storage.trusted_media_url?/1 actually trusts — the same gate
        # the storefront uses for review photos.
        "url" => "/uploads/stores/x/messages/y/abc.webm",
        "content_type" => "audio/webm",
        "duration_ms" => 4200
      },
      overrides
    )
  end

  describe "posting a recording" do
    test "a voice note needs no words", ctx do
      assert {:ok, message} =
               Conversations.post_message(ctx.thread, :customer, ctx.customer.id, nil,
                 attachments: [recording()]
               )

      assert is_nil(message.body)
      assert [%{"kind" => "audio"}] = message.attachments
    end

    test "words and a recording can travel together", ctx do
      assert {:ok, message} =
               Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Listen",
                 attachments: [recording()]
               )

      assert message.body == "Listen"
      assert length(message.attachments) == 1
    end

    test "neither words nor sound is still nothing", ctx do
      assert {:error, :empty_message} =
               Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "  ",
                 attachments: []
               )
    end

    test "a plain typed message still works and carries no attachments", ctx do
      assert {:ok, message} =
               Conversations.post_message(ctx.thread, :customer, ctx.customer.id, "Just words")

      assert message.body == "Just words"
      assert message.attachments == []
    end

    test "a recording notifies the other side like any message", ctx do
      {:ok, _} =
        Conversations.post_message(ctx.thread, :customer, ctx.customer.id, nil,
          attachments: [recording()]
        )

      types = ctx.merchant |> Emakola.Notifications.list_for() |> Enum.map(& &1.type)
      assert :new_message in types
    end

    test "a recording still broadcasts to the open conversation", ctx do
      Conversations.subscribe(ctx.thread.id)

      {:ok, message} =
        Conversations.post_message(ctx.thread, :customer, ctx.customer.id, nil,
          attachments: [recording()]
        )

      assert_receive {:new_message, received}
      assert received.id == message.id
    end
  end

  describe "what may be attached" do
    test "an attachment without a url is refused", ctx do
      assert {:error, _} =
               Conversations.post_message(ctx.thread, :customer, ctx.customer.id, nil,
                 attachments: [recording() |> Map.delete("url")]
               )
    end

    test "a url outside our own storage is refused", ctx do
      # Rendered straight into an <audio src>, so an arbitrary host would be
      # someone else's server playing through our page.
      assert {:error, _} =
               Conversations.post_message(ctx.thread, :customer, ctx.customer.id, nil,
                 attachments: [recording(%{"url" => "https://evil.example.com/x.webm"})]
               )
    end
  end
end
