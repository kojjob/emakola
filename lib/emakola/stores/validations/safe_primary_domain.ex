defmodule Emakola.Stores.Validations.SafePrimaryDomain do
  @moduledoc """
  Guards the merchant-facing `:update`, which accepts `primary?` and
  `serve_in_place?` together.

  Two rules, both protecting the canonical URL:

    * a domain may only be primary while it is `:active` — canonical must never
      point at a host that is not serving;
    * a primary `:custom` domain must serve in place. If it redirected, it would
      301 to its own canonical, which is itself.
  """

  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    primary? = Ash.Changeset.get_attribute(changeset, :primary?)
    serve_in_place? = Ash.Changeset.get_attribute(changeset, :serve_in_place?)

    cond do
      primary? and changeset.data.status != :active ->
        error(:primary?, "can only be set on a domain that is live")

      primary? and changeset.data.type == :custom and not serve_in_place? ->
        error(:serve_in_place?, "must stay on for your primary domain")

      true ->
        :ok
    end
  end

  defp error(field, message) do
    {:error, Ash.Error.Changes.InvalidAttribute.exception(field: field, message: message)}
  end
end
