defmodule Emakola.Fulfillment.Validations.LimitGuard do
  @moduledoc """
  Atomic validation that rejects a DownloadGrant increment when the grant
  has reached its configured `download_limit`.

  Implements `atomic/3` so the check is injected directly into the UPDATE's
  WHERE clause — making the guard truly atomic:

      UPDATE download_grants
      SET    downloaded_count = downloaded_count + 1
      WHERE  id = $1
        AND  NOT (download_limit IS NOT NULL AND downloaded_count >= download_limit)

  If the row is at its limit (or no longer exists), 0 rows are updated and
  Ash surfaces an `Ash.Error.Changes.InvalidChanges` error.
  `DownloadService` maps that to `{:error, :limit_reached}`.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidChanges

  @impl true
  def validate(_changeset, _opts, _context), do: :ok

  @impl true
  def atomic(_changeset, _opts, context) do
    {:atomic, [:downloaded_count, :download_limit],
     expr(not is_nil(download_limit) and downloaded_count >= download_limit),
     expr(
       error(^InvalidChanges, %{
         fields: [:downloaded_count],
         message: ^(context.message || "download limit reached")
       })
     )}
  end
end
