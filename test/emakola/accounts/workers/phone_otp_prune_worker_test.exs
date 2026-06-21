defmodule Emakola.Accounts.Workers.PhoneOtpPruneWorkerTest do
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Accounts.PhoneOtp
  alias Emakola.Accounts.Workers.PhoneOtpPruneWorker

  defp issue(attrs) do
    PhoneOtp
    |> Ash.Changeset.for_create(
      :issue,
      Map.merge(
        %{
          phone: "+233501234567",
          code_hash: "hashed",
          purpose: :merchant,
          expires_at: DateTime.add(DateTime.utc_now(), 600, :second)
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  test "prunes expired and consumed OTPs but keeps live ones" do
    expired = issue(%{expires_at: DateTime.add(DateTime.utc_now(), -60, :second)})

    consumed =
      issue(%{})
      |> Ash.Changeset.for_update(:consume, %{})
      |> Ash.update!(authorize?: false)

    live = issue(%{})

    assert :ok = perform_job(PhoneOtpPruneWorker, %{})

    remaining =
      PhoneOtp
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    assert remaining == [live.id]
    refute expired.id in remaining
    refute consumed.id in remaining
  end
end
