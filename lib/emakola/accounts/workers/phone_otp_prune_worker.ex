defmodule Emakola.Accounts.Workers.PhoneOtpPruneWorker do
  @moduledoc """
  Oban cron worker that deletes spent phone OTP rows from `phone_otps`.

  Removes rows that are consumed (`consumed_at` set) or expired
  (`expires_at` in the past), leaving only live, unused codes. Runs daily;
  without it the table grows forever. Idempotent — deleting already-absent
  rows is a no-op.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query

  alias Emakola.Accounts.PhoneOtp
  alias Emakola.Repo

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    from(o in PhoneOtp,
      where: not is_nil(o.consumed_at) or o.expires_at < ^now
    )
    |> Repo.delete_all()

    :ok
  end
end
