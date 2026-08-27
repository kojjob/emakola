defmodule Emakola.Notifications.PreferencesTest do
  @moduledoc """
  What a person wants, intersected with what can reach them.

  `Reach` answers "can we reach them" — has a phone, has an email, has not
  opted out of marketing. `Preferences` answers "do they want this, now".
  Neither is the whole answer, and preferences must never widen what Reach
  allows: choosing SMS does not conjure a phone number.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Notifications.Preferences

  setup do
    {merchant, store} = create_merchant_with_store!()
    %{merchant: merchant, store: store}
  end

  # A merchant with a phone as well as the email every merchant has (it is
  # their password login), so a narrowed result is always the preference
  # talking and never a missing contact detail.
  defp reachable_merchant do
    create_merchant!(%{phone: "+23324#{System.unique_integer([:positive])}"})
  end

  describe "defaults" do
    test "a merchant who has set nothing is reachable on their best channel", ctx do
      channels = Preferences.channels_for(ctx.merchant, :order_placed)

      assert :in_app in channels
    end

    test "in-app is always offered — the bell costs nothing and needs no phone", ctx do
      assert :in_app in Preferences.channels_for(ctx.merchant, :new_message)
    end
  end

  describe "turning a channel off" do
    test "a channel the merchant switched off is dropped", ctx do
      {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

      channels = Preferences.channels_for(ctx.merchant, :new_message)

      assert channels == [:in_app]
      refute :sms in channels
    end

    test "switching one event off leaves the others alone", ctx do
      {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

      assert :in_app in Preferences.channels_for(ctx.merchant, :order_placed)
    end

    test "one merchant's choice does not touch another's", ctx do
      other = create_merchant!()
      {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

      assert Preferences.channels_for(other, :new_message) != []
    end
  end

  describe "composition with Reach" do
    test "a preference cannot conjure a channel Reach refuses", ctx do
      # A buyer with a phone and no email — the common case in this market,
      # and why Customer.email is nullable. A merchant cannot stand in here:
      # their email is their password login, so they always have one.
      buyer = create_customer!(ctx.store, %{name: "Ama", phone: "+233241234567", email: nil})
      {:ok, _} = Preferences.put_channels(buyer, :new_message, [:in_app, :sms, :email])

      channels = Preferences.channels_for(buyer, :new_message)

      assert :sms in channels
      # Wanted, but there is no address to send it to.
      refute :email in channels
      # The bell still works — it needs no contact detail at all.
      assert :in_app in channels
    end

    test "a buyer with no contact details at all still gets the bell", ctx do
      buyer = create_customer!(ctx.store, %{name: "Kofi", phone: "+233240000000"})
      {:ok, _} = Preferences.put_channels(buyer, :new_message, [:in_app, :sms])

      # Reach returns [] once the phone goes, so only the bell survives.
      stripped = %{buyer | phone: nil, email: nil}

      assert Preferences.channels_for(stripped, :new_message) == [:in_app]
    end

    test "the result is an intersection, not a replacement" do
      merchant = reachable_merchant()
      {:ok, _} = Preferences.put_channels(merchant, :new_message, [:in_app, :sms])

      channels = Preferences.channels_for(merchant, :new_message)

      assert :sms in channels
      # WhatsApp is reachable but not wanted.
      refute :whatsapp in channels
    end
  end

  describe "events that ignore preferences" do
    test "a merchant cannot silence the message saying they got paid", ctx do
      {:ok, _} = Preferences.put_channels(ctx.merchant, :payout_sent, [])

      channels = Preferences.channels_for(ctx.merchant, :payout_sent)

      assert :in_app in channels
    end

    test "nor the one saying an order arrived", ctx do
      {:ok, _} = Preferences.put_channels(ctx.merchant, :order_placed, [])

      assert :in_app in Preferences.channels_for(ctx.merchant, :order_placed)
    end

    test "but a chatty one can be silenced down to the bell", ctx do
      {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [])

      # Even "off" keeps the bell: a row is written either way, and hiding it
      # would mean a merchant with notifications off has no record at all.
      assert Preferences.channels_for(ctx.merchant, :new_message) == [:in_app]
    end
  end

  describe "quiet hours" do
    test "a chatty notification inside the window is held", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      at = ~U[2026-08-26 23:30:00Z]

      assert Preferences.quiet?(ctx.merchant, :new_message, at)
    end

    test "outside the window nothing is held", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      assert refute_quiet(ctx.merchant, :new_message, ~U[2026-08-26 14:00:00Z])
    end

    test "a window that crosses midnight covers both sides of it", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      assert Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 23:00:00Z])
      assert Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 02:00:00Z])
      assert refute_quiet(ctx.merchant, :new_message, ~U[2026-08-26 07:00:00Z])
    end

    test "a same-day window does not wrap", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[13:00:00], ~T[14:00:00])

      assert Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 13:30:00Z])
      assert refute_quiet(ctx.merchant, :new_message, ~U[2026-08-26 12:30:00Z])
      assert refute_quiet(ctx.merchant, :new_message, ~U[2026-08-26 15:00:00Z])
    end

    test "money still gets through at 2am", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      refute Preferences.quiet?(ctx.merchant, :payout_sent, ~U[2026-08-26 02:00:00Z])
    end

    test "no quiet hours set means never quiet", ctx do
      assert refute_quiet(ctx.merchant, :new_message, ~U[2026-08-26 03:00:00Z])
    end

    test "the window is read in the merchant's own offset", ctx do
      # Nigeria is UTC+1 with no DST. 22:00 local is 21:00 UTC.
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])
      {:ok, _} = Preferences.put_utc_offset(ctx.merchant, 60)

      assert Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 21:30:00Z])
      assert refute_quiet(ctx.merchant, :new_message, ~U[2026-08-26 20:30:00Z])
    end

    test "when the window ends, in the merchant's offset", ctx do
      {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

      # 23:30 UTC → held until 06:00 the next morning, six and a half hours.
      resume_at = Preferences.quiet_until(ctx.merchant, ~U[2026-08-26 23:30:00Z])

      assert DateTime.compare(resume_at, ~U[2026-08-27 06:00:00Z]) == :eq
    end
  end

  defp refute_quiet(owner, event, at), do: not Preferences.quiet?(owner, event, at)
end
