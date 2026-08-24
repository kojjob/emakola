defmodule Emakola.Stores.Validations.DomainStatusIn do
  @moduledoc """
  Guards a `StoreDomain` state transition by checking the status the row
  *currently* holds, before this action's changes are applied.

  `Ash.Changeset.get_attribute/2` would return the value the action is setting,
  so it cannot express "you may only activate a domain that is verifying".
  This reads `changeset.data` instead.
  """

  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :from) do
      {:ok, from} when is_list(from) -> {:ok, opts}
      _ -> {:error, "`:from` must be a list of allowed statuses"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    allowed = Keyword.fetch!(opts, :from)
    current = changeset.data.status

    if current in allowed do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :status,
         message: "cannot be changed from #{current} by this action"
       )}
    end
  end
end
