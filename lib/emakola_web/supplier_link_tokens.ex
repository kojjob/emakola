defmodule EmakolaWeb.SupplierLinkTokens do
  @moduledoc """
  Signs and verifies the capability token behind a supplier's action link.

  A dropship supplier is often a local wholesaler reachable only on WhatsApp.
  They have no Makola account and never will, so the only thing that can
  authorise them to act on one fulfilment is a link — pasted into a chat by the
  merchant, or appended to the dispatch SMS.

  `EmakolaWeb.TrackingTokens` is the closest sibling and the model for this one:
  a capability token bound to a single record and handed to an anonymous party,
  distinct enough from AshAuthentication session subjects to earn its own module
  and its own salt rather than overloading `EmakolaWeb.AuthTokens`.

  ## Why the payload carries a version

  The token is `[fulfillment_id, supplier_link_version]`. A signed token cannot
  be un-issued, and a merchant who pastes a link into the wrong WhatsApp group
  needs it dead now, not in thirty days. Bumping
  `Fulfillment.supplier_link_version` invalidates every token minted before it,
  which buys revocation for the price of one integer column instead of a token
  table with its own resource, policies and expiry sweep. The honest cost is
  that there is no per-view audit trail; if that is ever required, that is the
  argument for the stored row.

  Verification is deliberately cheap and DB-free — a forged token fails the HMAC
  before any id exists, so flooding the route costs one hash per request.

  ## Shape is part of the contract

  `verify/1` rejects any payload that is not exactly a two-element
  `[binary, integer]` list, even when the signature is valid. A validly-signed
  token of the wrong shape means something else minted it under this salt, and
  trusting it would be trusting the salt over the contract.
  """

  @salt "supplier_action_v1"

  # A fulfilment nobody has touched in thirty days is a dead order, not a
  # pending one — and a link that outlives the order it belongs to is a leak
  # waiting to happen. Revocation covers the urgent case; this covers the
  # forgotten one.
  @max_age 60 * 60 * 24 * 30

  @doc "Signs a fulfillment id and link version into a supplier action token."
  @spec sign(String.t(), pos_integer()) :: String.t()
  def sign(fulfillment_id, version) when is_binary(fulfillment_id) and is_integer(version) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @salt, [fulfillment_id, version])
  end

  @doc """
  Verifies a supplier action token.

  Returns `{:ok, {fulfillment_id, version}}`, or `{:error, :invalid | :expired |
  :missing}`. Never raises, whatever it is handed — the input is a URL segment
  typed or forwarded by a stranger.
  """
  @spec verify(term()) :: {:ok, {String.t(), pos_integer()}} | {:error, atom()}
  def verify(signed) when is_binary(signed) do
    case Phoenix.Token.verify(EmakolaWeb.Endpoint, @salt, signed, max_age: @max_age) do
      {:ok, [fulfillment_id, version]}
      when is_binary(fulfillment_id) and is_integer(version) ->
        {:ok, {fulfillment_id, version}}

      {:ok, _wrong_shape} ->
        {:error, :invalid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify(_not_a_token), do: {:error, :missing}

  @doc "Seconds a freshly minted supplier action token stays valid."
  @spec max_age() :: pos_integer()
  def max_age, do: @max_age
end
