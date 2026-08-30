defmodule Emakola.Notifications.Reach do
  @moduledoc """
  Which channels will actually reach a person.

  **Never assume email.** Most Makola merchants and buyers do not use it, so
  a notification sent only by email is, for them, a notification that was
  never sent. Phone comes first and email is the fallback — the opposite of
  the order most e-commerce software assumes.

  Two kinds of message, and the difference matters:

    * `:transactional` — something they asked for by buying (order placed,
      shipped, delivered; a login code). An opt-out never suppresses these.
    * `:marketing` — a campaign. Suppressed by `marketing_opt_out_at`,
      because every message costs the merchant money and consent is the
      whole point of the opt-out.

  WhatsApp is listed ahead of SMS wherever a phone exists: it is free to the
  recipient, familiar to this audience, and cheaper for the merchant. Whether
  a given WhatsApp send actually goes out still depends on an approved
  template — this module answers "can we reach them", not "did it arrive".
  """

  @type audience :: :transactional | :marketing
  @type channel :: :whatsapp | :sms | :email

  @doc """
  The ordered channels that can reach `person`, best first.

  Returns `[]` when nothing can — which callers should treat as a real
  outcome worth recording, not as success.
  """
  @spec channels_for(map(), audience()) :: [channel()]
  def channels_for(person, audience) when audience in [:transactional, :marketing] do
    if suppressed?(person, audience) do
      []
    else
      phone_channels(person) ++ email_channels(person)
    end
  end

  @doc "True when at least one channel can reach them."
  @spec reachable?(map(), audience()) :: boolean()
  def reachable?(person, audience), do: channels_for(person, audience) != []

  # An opt-out is about marketing only. Telling someone their order shipped
  # is information they asked for by buying, not a message they opted out of.
  defp suppressed?(person, :marketing), do: not is_nil(opt_out_at(person))
  defp suppressed?(_person, :transactional), do: false

  defp opt_out_at(person), do: Map.get(person, :marketing_opt_out_at)

  defp phone_channels(person) do
    if present?(Map.get(person, :phone)), do: [:whatsapp, :sms], else: []
  end

  defp email_channels(person) do
    if present?(Map.get(person, :email)), do: [:email], else: []
  end

  # Ash.CiString (emails) does not implement String.trim/1, so normalise
  # through to_string/1 first — the same trap that has crashed String.first
  # on CiString emails elsewhere in this codebase.
  defp present?(nil), do: false
  defp present?(value), do: value |> to_string() |> String.trim() != ""
end
