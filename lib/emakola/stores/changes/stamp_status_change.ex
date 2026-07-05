defmodule Emakola.Stores.Changes.StampStatusChange do
  @moduledoc """
  Records when a Store's lifecycle `status` last changed by stamping
  `status_changed_at` with the current time.

  Used by the platform lifecycle actions (`:suspend`, `:block`, `:archive`,
  `:reactivate`). The stamp is a denormalized convenience for the admin UI;
  the platform audit log remains the system of record for the full history.

  These actions set a timestamp from Elixir, so they run with
  `require_atomic?(false)` — consistent with `:update_settings`.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(changeset, :status_changed_at, DateTime.utc_now())
  end
end
