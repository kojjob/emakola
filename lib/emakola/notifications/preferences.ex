defmodule Emakola.Notifications.Preferences do
  @moduledoc """
  What a person wants told to them, and when.

  This is the second of two gates and never the only one.
  `Emakola.Notifications.Reach` decides what *can* reach someone — do they
  have a phone, an email, have they opted out of marketing. This module
  decides what they *want*. The answer is the intersection, so a preference
  can only ever narrow: choosing SMS does not conjure a phone number.

  Two things are deliberately not choosable.

  **The bell is always on.** `:in_app` costs nothing, needs no contact detail,
  and the row is written regardless — hiding it would leave a merchant who
  turned notifications off with no record at all, which is worse than noise.

  **Money and orders cannot be silenced.** A merchant must not be able to
  switch off the message saying they were paid, or that someone bought
  something. Those are in `@always_on` and ignore both the overrides and quiet
  hours.
  """

  alias Emakola.Notifications.Reach
  alias Emakola.Notifications.Settings

  require Ash.Query
  require Logger

  @type channel :: :in_app | :whatsapp | :sms | :email

  # Events a person may not switch off, and that quiet hours do not hold.
  # Deliberately short: everything here is money arriving, work appearing, or
  # a platform decision about their livelihood.
  @always_on ~w(order_placed payment_received payout_sent verification_result product_moderated)a

  # What each event does by default when nobody has chosen otherwise. Phone
  # first, matching Reach's ordering and this market's habits.
  @defaults %{
    order_placed: [:in_app, :whatsapp, :sms],
    order_status_changed: [:in_app],
    payment_received: [:in_app, :whatsapp, :sms],
    payout_sent: [:in_app, :whatsapp, :sms],
    # SMS included so the default preserves what MessageNudgeWorker already
    # did — it has always nudged anyone with a phone. Dropping it here would
    # silently switch off a shipped feature for every merchant who never
    # visits the settings page.
    new_message: [:in_app, :whatsapp, :sms],
    verification_result: [:in_app, :whatsapp, :sms],
    product_moderated: [:in_app, :whatsapp],
    supplier_connection: [:in_app],
    announcement: [:in_app],
    billing_warning: [:in_app, :email],
    system: [:in_app]
  }

  @doc """
  The channels to actually use for `owner` and `event_type`.

  Always includes `:in_app`. Everything else is the person's choice
  intersected with what `Reach` says can get to them.
  """
  @spec channels_for(map(), atom(), keyword()) :: [channel()]
  def channels_for(owner, event_type, opts \\ []) do
    audience = Keyword.get(opts, :audience, :transactional)
    wanted = wanted_channels(owner, event_type)
    reachable = Reach.channels_for(owner, audience)

    # in_app is not a Reach channel — it needs no contact detail — so it is
    # added rather than intersected.
    [:in_app | Enum.filter(wanted, &(&1 in reachable))]
    |> Enum.uniq()
  end

  @doc "True when `event_type` should be held until this person's quiet hours end."
  @spec quiet?(map(), atom(), DateTime.t()) :: boolean()
  def quiet?(owner, event_type, at) do
    cond do
      event_type in @always_on ->
        false

      true ->
        case settings(owner) do
          %{quiet_hours_start: %Time{} = start, quiet_hours_end: %Time{} = finish} = record ->
            within?(local_time(at, record.utc_offset_minutes), start, finish)

          _ ->
            false
        end
    end
  end

  @doc """
  When this person's quiet window ends, as a UTC instant.

  Returns `at` unchanged when they are not in one, so a caller can schedule
  against it without branching.
  """
  @spec quiet_until(map(), DateTime.t()) :: DateTime.t()
  def quiet_until(owner, at) do
    case settings(owner) do
      %{quiet_hours_end: %Time{} = finish} = record ->
        resume_at(at, finish, record.utc_offset_minutes)

      _ ->
        at
    end
  end

  @doc "Records the channels this person wants for one event."
  @spec put_channels(map(), atom(), [channel()]) :: {:ok, Settings.t()} | {:error, term()}
  def put_channels(owner, event_type, channels) do
    record = settings(owner)

    overrides =
      Map.put(
        record.overrides,
        to_string(event_type),
        Enum.map(channels, &to_string/1)
      )

    put(owner, %{overrides: overrides})
  end

  @doc "Records this person's quiet window. Passing nils clears it."
  @spec put_quiet_hours(map(), Time.t() | nil, Time.t() | nil) ::
          {:ok, Settings.t()} | {:error, term()}
  def put_quiet_hours(owner, start, finish) do
    put(owner, %{quiet_hours_start: start, quiet_hours_end: finish})
  end

  @doc "Records the UTC offset the quiet window is read in. Ghana 0, Nigeria 60."
  @spec put_utc_offset(map(), integer()) :: {:ok, Settings.t()} | {:error, term()}
  def put_utc_offset(owner, minutes) when is_integer(minutes) do
    put(owner, %{utc_offset_minutes: minutes})
  end

  @doc "This person's stored settings, or the unsaved defaults."
  @spec settings(map()) :: Settings.t()
  def settings(owner) do
    kind = owner_kind(owner)

    Settings
    |> Ash.Query.for_read(:for_owner, %{owner_kind: kind, owner_id: owner.id})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Settings{} = record} ->
        record

      _ ->
        # Never persisted on read: someone who has not opened the settings
        # page should not have a row, and reading must not create one.
        %Settings{owner_kind: kind, owner_id: owner.id, overrides: %{}, utc_offset_minutes: 0}
    end
  end

  @doc "The default channels for an event, before anyone chooses otherwise."
  @spec defaults_for(atom()) :: [channel()]
  def defaults_for(event_type), do: Map.get(@defaults, event_type, [:in_app])

  @doc "Events that cannot be switched off and that quiet hours never hold."
  @spec always_on() :: [atom()]
  def always_on, do: @always_on

  # ── Private ──────────────────────────────────────────────────────

  defp wanted_channels(owner, event_type) do
    if event_type in @always_on do
      defaults_for(event_type)
    else
      record = settings(owner)

      case Map.fetch(record.overrides, to_string(event_type)) do
        {:ok, channels} when is_list(channels) -> Enum.map(channels, &cast_channel/1)
        _ -> defaults_for(event_type)
      end
    end
  end

  # The overrides map is jsonb, so its values arrive as strings from a
  # round-trip. An allowlist rather than String.to_atom/1 — this is stored
  # data that a settings form ultimately wrote.
  defp cast_channel(value) when is_atom(value), do: value

  defp cast_channel(value) do
    Emakola.SafeAtom.to_atom_in(value, [:in_app, :whatsapp, :sms, :email], nil)
  end

  defp local_time(at, offset_minutes) do
    at |> DateTime.add(offset_minutes * 60, :second) |> DateTime.to_time()
  end

  # A window that crosses midnight (22:00–06:00) is two ranges, not one.
  defp within?(time, start, finish) do
    if Time.compare(start, finish) == :lt do
      Time.compare(time, start) != :lt and Time.compare(time, finish) == :lt
    else
      Time.compare(time, start) != :lt or Time.compare(time, finish) == :lt
    end
  end

  # The next instant at which local time reads `finish`.
  defp resume_at(at, finish, offset_minutes) do
    local = DateTime.add(at, offset_minutes * 60, :second)

    candidate =
      local
      |> DateTime.to_date()
      |> DateTime.new!(finish, "Etc/UTC")

    candidate =
      if DateTime.compare(candidate, local) == :gt do
        candidate
      else
        DateTime.add(candidate, 86_400, :second)
      end

    DateTime.add(candidate, -offset_minutes * 60, :second)
  end

  defp put(owner, attrs) do
    record = settings(owner)

    params =
      attrs
      |> Map.put(:owner_kind, owner_kind(owner))
      |> Map.put(:owner_id, owner.id)
      |> then(fn params ->
        # An upsert rewrites the whole row, so anything not being changed has
        # to be carried forward or it silently resets to the column default.
        %{
          overrides: record.overrides,
          quiet_hours_start: record.quiet_hours_start,
          quiet_hours_end: record.quiet_hours_end,
          utc_offset_minutes: record.utc_offset_minutes
        }
        |> Map.merge(params)
      end)

    Settings
    |> Ash.Changeset.for_create(:put, params)
    |> Ash.create(authorize?: false)
  end

  defp owner_kind(%Emakola.Accounts.User{}), do: :user
  defp owner_kind(%Emakola.Accounts.Merchant{}), do: :merchant
  defp owner_kind(%Emakola.Customers.Customer{}), do: :customer
end
