defmodule EmakolaWeb.QRScan do
  @moduledoc """
  Reading a scanned code — the mirror of `EmakolaWeb.QR`, which writes them.

  ## A scan is never a destination

  What comes back off a camera is a string that a stranger may have printed and
  taped to a parcel. The dangerous shape is *decode → treat as URL → follow it*,
  because that hands an authenticated merchant session to whoever printed the
  sticker.

  So the decoded string is only ever read as a **claim about an identifier**:

      decode → extract the identifier → resolve inside the acting store → act

  The host in the payload is discarded rather than validated. That sounds looser
  than checking it, but it is strictly safer here, because the security does not
  rest on the string at all — the lookup is scoped by a `store_id` the caller
  takes from the session, never from the code. A payload naming `evil.example`
  or another merchant's slug can therefore only ever resolve to one of the
  scanning merchant's own orders, or to nothing.

  Discarding the host also survives the thing a strict check would break: a slip
  printed before a domain change, or under the apex while subdomains were dark,
  still scans.

  ## Absence is `:not_found`

  A code for another store's order returns `:not_found`, never `:forbidden` —
  the same posture `Emakola.Orders.CustomerDelivery` takes — so the scanner
  cannot be used to probe which order numbers exist elsewhere on the platform.
  """

  require Ash.Query

  # Order numbers look like ORD-20260416-72A4U2. The cap is far above any real
  # one and exists so a QR carrying a wall of text is refused in memory rather
  # than becoming a database query.
  @max_payload 512

  @doc """
  Resolves a scanned string to one of `store_id`'s own orders.

  Accepts anything our slip might carry — a full tracking URL, with or without
  a query string or trailing slash — as well as a bare order number typed or
  scanned on its own.

  Returns `{:ok, order}`, `{:error, :not_found}` when nothing in this store
  matches, or `{:error, :unrecognised}` when the payload could not contain an
  order number at all.
  """
  @spec resolve_order(term(), binary()) ::
          {:ok, Emakola.Orders.Order.t()} | {:error, :not_found | :unrecognised}
  def resolve_order(scanned, store_id) when is_binary(store_id) do
    with {:ok, candidate} <- candidate_identifier(scanned) do
      lookup(candidate, store_id)
    end
  end

  # -- reading the payload ----------------------------------------------------

  defp candidate_identifier(scanned) when is_binary(scanned) do
    trimmed = String.trim(scanned)

    cond do
      trimmed == "" -> {:error, :unrecognised}
      byte_size(trimmed) > @max_payload -> {:error, :unrecognised}
      true -> extract(trimmed)
    end
  end

  defp candidate_identifier(_not_a_string), do: {:error, :unrecognised}

  # `/track/<order_number>` is the shape our own slip carries. Everything before
  # it — scheme, host, store slug — is deliberately ignored; see the moduledoc.
  defp extract(payload) do
    case Regex.run(~r{/track/([^/?#\s]+)}, payload) do
      [_, order_number] -> validate(URI.decode(order_number))
      nil -> validate(payload)
    end
  end

  # Without this, any scanned text would reach the database as a query. An order
  # number is a compact token, so anything carrying a space, a scheme separator
  # or punctuation is refused here — which is what turns `javascript:alert(1)`
  # and a WiFi-config QR into `:unrecognised` rather than a lookup.
  defp validate(candidate) do
    if candidate =~ ~r/^[A-Za-z0-9._-]{1,64}$/ do
      {:ok, candidate}
    else
      {:error, :unrecognised}
    end
  end

  # -- resolving it -----------------------------------------------------------

  # Scoped by the store_id the caller holds, which comes from the session. The
  # scanned string contributes the order number and nothing else.
  defp lookup(order_number, store_id) do
    Emakola.Orders.Order
    |> Ash.Query.filter(order_number == ^order_number and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [order]} -> {:ok, order}
      _ -> {:error, :not_found}
    end
  end
end
