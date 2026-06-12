defmodule Emakola.Accounts.Changes.GeneratePlatformInviteToken do
  @moduledoc """
  Generates the invite token on platform-invite creation.

  32 random bytes are url-base64 encoded into a raw token exposed to the
  caller only via record metadata (`invite.__metadata__.raw_token`) — it
  is never persisted. The SHA-256 hex digest goes in `token_hash`, and
  `expires_at` is set 7 days out.
  """

  use Ash.Resource.Change

  @expiry_days 7

  @impl true
  def change(changeset, _opts, _context) do
    raw = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    hash = :sha256 |> :crypto.hash(raw) |> Base.encode16(case: :lower)

    changeset
    |> Ash.Changeset.force_change_attribute(:token_hash, hash)
    |> Ash.Changeset.force_change_attribute(
      :expires_at,
      DateTime.add(DateTime.utc_now(), @expiry_days, :day)
    )
    |> Ash.Changeset.after_action(fn _changeset, invite ->
      {:ok, Ash.Resource.put_metadata(invite, :raw_token, raw)}
    end)
  end
end
