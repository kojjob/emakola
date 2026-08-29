defmodule Emakola.Suppliers.SupplierAction do
  @moduledoc """
  The unauthenticated boundary a supplier acts through, from a link.

  `Emakola.Suppliers.InboundFulfillment` is the sibling of this module and is
  deliberately *not* merged with it. That one is an **authenticated cross-store**
  boundary: its first argument is a `Merchant`, every entry point runs
  `ensure_store_access/2` against `StoreMembership`, and it filters on
  `supplier.linked_store_id`. This one is an **unauthenticated capability**
  boundary with no actor at all. Putting two authorisation models behind one
  module's function names is how an `ensure_store_access` eventually gets
  skipped by the wrong branch, so they stay apart and converge only on the
  shared resource actions.

  The practical consequence is that an off-platform supplier — a local
  wholesaler on WhatsApp with no Makola account, which the dropshipping roadmap
  names as the primary persona — can finally answer for themselves. Until now
  only the merchant could click on their behalf.

  ## Why every function takes a token

  None of these take a fulfilment id. The token *is* the identifier, so there is
  no parameter for a caller to swap and "act on someone else's fulfilment" is
  not a case to be guarded — it is unrepresentable. `authorize/1` re-resolves
  from scratch on every call, so a stale button on a fulfilment the merchant
  cancelled a moment ago fails cleanly instead of writing.

  ## What the token is not allowed to reach

  A `supplier_id: nil` fulfilment is the merchant's **own-stock** group. Nothing
  mints tokens for those, but the filter lives here rather than at the minting
  site because a future caller or a minting bug would otherwise hand a stranger
  the merchant's own order and the buyer's address with it.
  """

  require Ash.Query
  require Logger

  alias Emakola.Orders.Fulfillment
  alias EmakolaWeb.SupplierLinkTokens

  @type error ::
          :invalid_token
          | :expired_token
          | :revoked_token
          | :not_found
          | :not_actionable
          | :tracking_required
          | :tracking_too_long
          | :rate_limited
          | :stale

  @decline_reasons [:out_of_stock, :price_too_low, :cannot_deliver]

  # Ten writes per fulfilment per ten minutes. Keyed per fulfilment rather than
  # per IP because `get_connect_info(socket, :peer_data)` is nil in a
  # disconnected LiveView mount — IP keying in here would silently protect
  # nothing. Per-IP protection belongs on the route.
  @write_limit 10
  @write_window_ms 600_000

  @max_tracking_length 100

  # Not `~p`: this module is in the domain layer and the route lives in the web
  # layer, so a verified-route sigil here would couple the domain's compilation
  # to the router. The trade is that a rename of the route would not break the
  # build, so the LiveView test asserts this exact prefix still resolves.
  @path_prefix "/supply/"

  @doc """
  Resolves a token to the fulfilment it authorises.

  Read-only and not rate limited: a supplier refreshing the page must not lock
  themselves out of the buttons.
  """
  @spec authorize(term()) :: {:ok, Fulfillment.t()} | {:error, error()}
  def authorize(token) do
    with {:ok, {fulfillment_id, version}} <- verify(token),
         {:ok, fulfillment} <- fetch(fulfillment_id) do
      check_version(fulfillment, version)
    end
  end

  @doc """
  Records that the supplier has the goods.

  Stamps `accepted_at` and leaves `status` alone — see the resource for why
  that asymmetry matters. Idempotent, because the link is a capability and a
  supplier tapping twice is ordinary.
  """
  @spec accept(term()) :: {:ok, Fulfillment.t()} | {:error, error()}
  def accept(token) do
    write(token, fn fulfillment ->
      Emakola.Orders.supplier_accept_fulfillment(fulfillment, authorize?: false)
    end)
  end

  @doc """
  Records that the supplier cannot supply, and tells the merchant.

  The notification is sent after the write commits and can never roll it back —
  a decline nobody sees is worse than a decline that failed loudly.
  """
  @spec decline(term(), atom()) :: {:ok, Fulfillment.t()} | {:error, error()}
  def decline(token, reason \\ :out_of_stock) do
    reason = if reason in @decline_reasons, do: reason, else: :out_of_stock

    case write(token, fn fulfillment ->
           Emakola.Orders.supplier_decline_fulfillment(
             fulfillment,
             %{decline_reason: reason},
             authorize?: false
           )
         end) do
      {:ok, declined} ->
        notify_merchant_of_decline(declined)
        {:ok, declined}

      error ->
        error
    end
  end

  @doc "Records the shipment and its tracking number."
  @spec mark_sent(term(), term()) :: {:ok, Fulfillment.t()} | {:error, error()}
  def mark_sent(token, tracking_number) do
    with {:ok, tracking} <- normalize_tracking(tracking_number) do
      write(token, fn fulfillment ->
        Emakola.Orders.mark_fulfillment_shipped(
          fulfillment,
          %{tracking_number: tracking},
          authorize?: false
        )
      end)
    end
  end

  @doc """
  The link to hand the supplier.

  The only minting site. Callers that render many of these — the merchant's
  order page — should compute them once per load rather than per render; each
  one is an HMAC.
  """
  @spec action_url(Fulfillment.t()) :: String.t()
  def action_url(%Fulfillment{id: id, supplier_link_version: version}) do
    EmakolaWeb.Endpoint.url() <> @path_prefix <> SupplierLinkTokens.sign(id, version)
  end

  # ── Private ─────────────────────────────────────────────────────

  defp write(token, fun) do
    with {:ok, fulfillment} <- authorize(token),
         :ok <- rate_limit(fulfillment.id) do
      fulfillment |> fun.() |> map_write_result()
    end
  end

  defp verify(token) do
    case SupplierLinkTokens.verify(token) do
      {:ok, payload} -> {:ok, payload}
      {:error, :expired} -> {:error, :expired_token}
      {:error, _invalid_or_missing} -> {:error, :invalid_token}
    end
  end

  defp fetch(fulfillment_id) do
    Fulfillment
    |> Ash.Query.filter(id == ^fulfillment_id and not is_nil(supplier_id))
    |> Ash.Query.load([:supplier, :order, line_items: [variant: [product: :images]]])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, fulfillment} -> {:ok, fulfillment}
      {:error, _reason} -> {:error, :not_found}
    end
  end

  defp check_version(%Fulfillment{supplier_link_version: current} = fulfillment, presented) do
    if current == presented, do: {:ok, fulfillment}, else: {:error, :revoked_token}
  end

  defp rate_limit(fulfillment_id) do
    case Emakola.RateLimit.check_rate(
           "supplier_action:write:#{fulfillment_id}",
           @write_limit,
           @write_window_ms
         ) do
      {:allow, _count} -> :ok
      {:deny, _limit} -> {:error, :rate_limited}
    end
  end

  defp normalize_tracking(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :tracking_required}
      trimmed when byte_size(trimmed) > @max_tracking_length -> {:error, :tracking_too_long}
      trimmed -> {:ok, trimmed}
    end
  end

  defp normalize_tracking(_not_a_string), do: {:error, :tracking_required}

  # Ash error structs never cross this boundary — the LiveView pattern-matches
  # atoms so it can render one plain sentence a supplier can act on.
  defp map_write_result({:ok, fulfillment}), do: {:ok, fulfillment}
  defp map_write_result({:error, %Ash.Error.Changes.StaleRecord{}}), do: {:error, :stale}
  defp map_write_result({:error, _reason}), do: {:error, :not_actionable}

  defp notify_merchant_of_decline(fulfillment) do
    Emakola.Notifications.notify_store(fulfillment.store_id, :order_status_changed,
      title: supplier_name(fulfillment) <> ": out of stock",
      body: "Order #{order_number(fulfillment)}. Find another supplier or refund.",
      action_url: "/admin/orders/#{fulfillment.order_id}",
      metadata: %{"fulfillment_id" => fulfillment.id}
    )
  rescue
    exception ->
      Logger.error(
        "[SupplierAction] decline notification raised: #{Exception.message(exception)}"
      )

      :ok
  end

  defp supplier_name(%{supplier: %{name: name}}) when is_binary(name), do: name
  defp supplier_name(_fulfillment), do: "Supplier"

  defp order_number(%{order: %{order_number: number}}) when is_binary(number), do: number
  defp order_number(_fulfillment), do: ""
end
