defmodule Emakola.Validations.StatusGuard do
  @moduledoc """
  Reusable Ash validation that guards status transitions on any resource that
  has a `:status` attribute.

  Checks that the record's current `:status` attribute is in a set of allowed
  `from` states. Returns a clear error message when the transition is not
  permitted.

  ## Usage in the Order resource DSL

      update :confirm do
        validate {StatusGuard, from: [:pending], message: "can only confirm a pending order"}
        change set_attribute(:status, :confirmed)
      end

      update :cancel do
        validate {StatusGuard,
          from: [:pending, :confirmed, :processing, :shipped],
          message: "can only cancel an active order (not delivered or already cancelled)"}
        change set_attribute(:status, :cancelled)
      end

  ## Options

    * `:from` (required) — list of atoms representing valid source statuses
    * `:message` (optional) — error message string; defaults to a generic one
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    case Keyword.fetch(opts, :from) do
      {:ok, from} when is_list(from) and from != [] ->
        {:ok, opts}

      _ ->
        {:error,
         "StatusGuard requires a non-empty :from option (list of allowed source statuses)"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    from = Keyword.fetch!(opts, :from)
    status = Ash.Changeset.get_attribute(changeset, :status)

    if status in from do
      :ok
    else
      message =
        Keyword.get(
          opts,
          :message,
          "cannot transition from #{inspect(status)}; allowed: #{inspect(from)}"
        )

      {:error,
       Ash.Error.Changes.InvalidAttribute.exception(
         field: :status,
         message: message
       )}
    end
  end
end
