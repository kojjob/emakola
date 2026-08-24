defmodule Emakola.Accounts.DevicePairings do
  @moduledoc """
  Signing a merchant's phone in by showing it a code on their desktop.

  Owns the whole lifecycle of `Emakola.Accounts.DevicePairing`, whose policies
  forbid everything so this module is the only way in.

  ## The flow, and why it has four steps rather than two

      issue    desktop mints a code and shows it
      scan     phone reads it and ASKS — it is not signed in yet
      confirm  desktop names the phone and the merchant assents
      redeem   phone exchanges the code for a session, once

  The obvious design is two steps: show a code, scan it, done. That version is
  phishable in reverse. An attacker displays *their* pairing code — on a poster,
  in a support chat, on a screenshared call — the merchant scans it out of
  habit, and the attacker's browser is now signed in **as the merchant**. Short
  expiry and single-use do nothing about it; the attacker is standing by ready
  to use it.

  `confirm` is the answer. The phone's scan cannot authenticate anything on its
  own; it can only raise a request that the already-authenticated desktop must
  approve, having been told which device is asking. A merchant who scans a
  stranger's code sees no prompt on their own screen and nothing happens.

  ## Redemption is a controller's job

  `redeem/1` returns the merchant; it does not create a session, because a
  session here is a signed subject token in the session cookie
  (`EmakolaWeb.AuthTokens.sign_subject/1`) and only a controller can write one.
  Merchants do not use `Emakola.Accounts.UserSession` — that is platform staff
  only.
  """

  import Ecto.Query, only: [from: 2]

  require Ash.Query

  alias Emakola.Accounts.DevicePairing
  alias Emakola.Accounts.Merchant

  # Long enough to pick up a phone and line up the camera; short enough that a
  # code caught on someone else's photo is dead before they can use it.
  @ttl_seconds 90

  # 32 bytes. The digest is a lookup key, not a password hash — see the
  # resource's moduledoc for why this is SHA-256 and not bcrypt.
  @token_bytes 32

  # Every issued code is a live credential for its ninety seconds, so a session
  # that has been taken over should not be able to mint them without end. Ten a
  # minute is far above honest use — pairing a phone needs one, maybe two if the
  # camera fumbles.
  @issue_limit 10
  @issue_window_ms 60_000

  @doc """
  Mints a pairing code for `merchant_id`.

  Returns `{:ok, plaintext_token, pairing}`. The plaintext exists in memory long
  enough to be rendered as a QR and nowhere else — only its digest is stored.
  """
  @spec issue(binary()) :: {:ok, binary(), DevicePairing.t()} | {:error, term()}
  def issue(merchant_id) when is_binary(merchant_id) do
    case Emakola.RateLimit.check_rate(
           "device_pairing_issue:" <> merchant_id,
           @issue_limit,
           @issue_window_ms
         ) do
      {:allow, _count} -> do_issue(merchant_id)
      {:deny, _retry_after} -> {:error, :rate_limited}
    end
  end

  defp do_issue(merchant_id) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(@token_bytes), padding: false)

    attrs = %{
      merchant_id: merchant_id,
      token_digest: digest(token),
      expires_at: DateTime.add(DateTime.utc_now(), @ttl_seconds, :second)
    }

    case DevicePairing
         |> Ash.Changeset.for_create(:issue, attrs)
         |> Ash.create(authorize?: false) do
      {:ok, pairing} -> {:ok, token, pairing}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Records that a phone read the code, and what kind of phone it was.

  Deliberately does not authenticate anything. It moves the pairing to
  `:scanned` so the desktop can show the merchant what is asking.
  """
  @spec scan(binary(), binary()) :: {:ok, DevicePairing.t()} | {:error, atom()}
  def scan(token, device_description) when is_binary(token) do
    with {:ok, pairing} <- fetch(token),
         :ok <- unexpired(pairing) do
      pairing
      |> Ash.Changeset.for_update(:mark_scanned, %{scanned_by: truncate(device_description)})
      |> Ash.update(authorize?: false)
      |> normalise()
    end
  end

  def scan(_token, _device), do: {:error, :not_found}

  @doc """
  The merchant, on the desktop that minted the code, assents to the phone.

  Scoped by `merchant_id` so one merchant cannot approve another's pairing, and
  refused unless a phone has actually scanned — confirming into thin air would
  leave a code that signs in whoever finds it next.
  """
  @spec confirm(binary(), binary()) :: {:ok, DevicePairing.t()} | {:error, atom()}
  def confirm(pairing_id, merchant_id) when is_binary(pairing_id) and is_binary(merchant_id) do
    with {:ok, pairing} <- fetch_owned(pairing_id, merchant_id),
         :ok <- unexpired(pairing),
         :ok <- require_scanned(pairing) do
      pairing
      |> Ash.Changeset.for_update(:confirm, %{})
      |> Ash.update(authorize?: false)
      |> normalise()
    end
  end

  @doc "The merchant refuses a phone they do not recognise."
  @spec reject(binary(), binary()) :: {:ok, DevicePairing.t()} | {:error, atom()}
  def reject(pairing_id, merchant_id) when is_binary(pairing_id) and is_binary(merchant_id) do
    with {:ok, pairing} <- fetch_owned(pairing_id, merchant_id) do
      pairing
      |> Ash.Changeset.for_update(:reject, %{})
      |> Ash.update(authorize?: false)
      |> normalise()
    end
  end

  @doc """
  Exchanges a confirmed code for the merchant it authenticates, exactly once.

  The row is locked `FOR UPDATE` across the check-and-consume, so two phones
  holding the same photographed code cannot both come away with a session — the
  loser re-reads a row that is already `:consumed` and gets `:not_found`.
  """
  @spec redeem(binary()) :: {:ok, Merchant.t()} | {:error, atom()}
  def redeem(token) when is_binary(token) do
    Emakola.Repo.transaction(fn ->
      case locked_pairing(token) do
        nil ->
          {:validation_error, :not_found}

        pairing ->
          with :ok <- unexpired(pairing),
               :ok <- require_confirmed(pairing) do
            consume!(pairing)
          else
            {:error, reason} ->
              audit_refusal(pairing, reason)
              {:validation_error, reason}
          end
      end
    end)
    |> unwrap()
  end

  def redeem(_token), do: {:error, :not_found}

  # -- lookup -----------------------------------------------------------------

  defp fetch(token) do
    DevicePairing
    |> Ash.Query.filter(token_digest == ^digest(token))
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [pairing]} -> {:ok, pairing}
      _ -> {:error, :not_found}
    end
  end

  # A pairing that does not belong to this merchant is :not_found rather than
  # :forbidden, so the confirm endpoint cannot be used to discover that some
  # other merchant has a pairing in flight.
  defp fetch_owned(pairing_id, merchant_id) do
    DevicePairing
    |> Ash.Query.filter(id == ^pairing_id and merchant_id == ^merchant_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [pairing]} -> {:ok, pairing}
      _ -> {:error, :not_found}
    end
  end

  # Consumed rows are excluded here rather than checked after, so a replay reads
  # as :not_found — the same answer a fabricated token gets, which is what stops
  # the endpoint from confirming that a code once existed.
  defp locked_pairing(token) do
    Emakola.Repo.one(
      from(p in "device_pairings",
        where: p.token_digest == ^digest(token) and p.status != "consumed",
        lock: "FOR UPDATE",
        select: %{
          id: p.id,
          merchant_id: p.merchant_id,
          status: p.status,
          expires_at: p.expires_at
        }
      )
    )
  end

  # -- guards -----------------------------------------------------------------

  # Accepts both shapes on purpose: the Ash read returns a DateTime, while the
  # schemaless FOR UPDATE query in `locked_pairing/1` hands back a NaiveDateTime
  # because there is no schema to cast against. Both are UTC.
  defp unexpired(%{expires_at: %DateTime{} = expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :gt,
      do: :ok,
      else: {:error, :expired}
  end

  defp unexpired(%{expires_at: %NaiveDateTime{} = expires_at}) do
    unexpired(%{expires_at: DateTime.from_naive!(expires_at, "Etc/UTC")})
  end

  defp require_scanned(%{status: status}) when status in [:scanned, "scanned"], do: :ok
  defp require_scanned(_pairing), do: {:error, :not_scanned}

  defp require_confirmed(%{status: status}) when status in [:confirmed, "confirmed"], do: :ok
  defp require_confirmed(_pairing), do: {:error, :not_confirmed}

  # -- consumption ------------------------------------------------------------

  defp consume!(pairing) do
    {1, _} =
      Emakola.Repo.update_all(
        from(p in "device_pairings", where: p.id == ^pairing.id),
        set: [status: "consumed", consumed_at: DateTime.utc_now()]
      )

    # Both ids come back from the schemaless query as raw 16-byte binaries —
    # fine for the update's own WHERE, but Ash wants the canonical string form.
    merchant_id = Ecto.UUID.load!(pairing.merchant_id)

    # A pairing is a sign-in with no password, so it has to leave a trace. An
    # account taken over this way would otherwise be invisible afterwards.
    Emakola.Audit.log(
      :device_paired,
      "DevicePairing",
      Ecto.UUID.load!(pairing.id),
      merchant_id,
      nil
    )

    Ash.get!(Merchant, merchant_id, authorize?: false)
  end

  # Someone presenting a code that cannot be redeemed is worth finding in a log:
  # an unconfirmed redemption is the inverted-phishing attempt itself.
  defp audit_refusal(pairing, reason) do
    Emakola.Audit.log(
      :device_pairing_refused,
      "DevicePairing",
      Ecto.UUID.load!(pairing.id),
      Ecto.UUID.load!(pairing.merchant_id),
      nil,
      metadata: %{"reason" => to_string(reason)}
    )
  end

  # -- plumbing ---------------------------------------------------------------

  defp digest(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

  defp truncate(nil), do: "Unknown device"
  defp truncate(text) when is_binary(text), do: String.slice(text, 0, 200)
  defp truncate(_), do: "Unknown device"

  defp normalise({:ok, record}), do: {:ok, record}
  defp normalise({:error, _}), do: {:error, :not_found}

  defp unwrap({:ok, {:validation_error, reason}}), do: {:error, reason}
  defp unwrap({:ok, result}), do: {:ok, result}
  defp unwrap({:error, {:validation_error, reason}}), do: {:error, reason}
  defp unwrap({:error, reason}), do: {:error, reason}
end
