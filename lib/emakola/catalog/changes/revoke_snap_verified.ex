defmodule Emakola.Catalog.Changes.RevokeSnapVerified do
  @moduledoc """
  Any image add/remove/reorder on a snap-verified product revokes the badge.
  The photo is the promise (spec: docs/superpowers/specs/2026-08-05-snap-to-shop-design.md);
  enforcement lives here, in the domain layer, so no UI path can dodge it.

  ## Options

    * `:only_if_changing` — when set, the hook only fires if that attribute is
      actually present in the changeset. Used on Image's `:update` action
      (which also accepts `:alt_text`) so text-only edits — including the AI
      alt-text backfill in `Content.Workers.ImageAltTextWorker`, which calls
      this same action — don't silently revoke a badge no photo actually
      changed. `:create` and `:destroy` pass no option and always fire.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _ctx) do
    if fires?(changeset, opts) do
      Ash.Changeset.after_action(changeset, fn _changeset, result ->
        revoke(result.product_id, result.store_id)
        {:ok, result}
      end)
    else
      changeset
    end
  end

  defp fires?(changeset, opts) do
    case Keyword.get(opts, :only_if_changing) do
      nil -> true
      attribute -> Ash.Changeset.changing_attribute?(changeset, attribute)
    end
  end

  defp revoke(nil, _store_id), do: :ok

  defp revoke(product_id, store_id) do
    case Ash.get(Emakola.Catalog.Product, product_id, tenant: store_id, authorize?: false) do
      {:ok, %{snap_verified: true} = product} ->
        product
        |> Ash.Changeset.for_update(:set_snap_verified, %{snap_verified: false},
          tenant: store_id,
          authorize?: false
        )
        |> Ash.update!()

        :ok

      _ ->
        :ok
    end
  end
end
