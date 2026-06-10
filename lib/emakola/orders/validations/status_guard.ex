defmodule Emakola.Orders.Validations.StatusGuard do
  @moduledoc false
  # Moved to Emakola.Validations.StatusGuard. This thin wrapper is kept
  # so any lingering compile-time references do not break.
  use Ash.Resource.Validation

  @impl true
  defdelegate init(opts), to: Emakola.Validations.StatusGuard

  @impl true
  defdelegate validate(changeset, opts, context), to: Emakola.Validations.StatusGuard
end
