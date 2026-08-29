defmodule Emakola.Stores.DirectoryCuration do
  @moduledoc """
  Staff overrides on directory featuring — the human hand on the computed
  ranking, with three properties the plan calls non-negotiable:

  **Immediate.** "Bar this shop now" that waits for the 02:30 worker is not
  a bar. Every write here updates the standing row AND the Store read-cache
  in one transaction, so the public page changes on the next render. The
  worker re-derives the same answer that night.

  **Reasoned.** A blank reason is refused. The reason is what makes the
  audit log worth reading six months later.

  **Audited.** Every write lands in the platform audit log with the
  store_id the timeline reads filter on. Audit failures never abort the
  curation write — `PlatformAudit.log/4` does not raise.

  Expiry is asymmetric on purpose: pins default to #{30} days, because an
  editorial decision should be re-earned rather than accumulate into a
  legacy list nobody remembers creating; exclusions default to forever,
  because a safety decision persists until a human reverses it.

  Called with `authorize?: false` from platform surfaces gated on
  `:manage_stores`, like every curation write in this codebase.
  """

  alias Emakola.Accounts.PlatformAudit
  alias Emakola.Stores.DirectoryStanding
  alias Emakola.Stores.Store

  @pin_days 30

  @doc "Pins a shop into `slot`, or clears the pin when `slot` is nil."
  @spec override_slot(DirectoryStanding.t(), atom() | nil, String.t(), term()) ::
          {:ok, DirectoryStanding.t()} | {:error, term()}
  def override_slot(standing, slot, reason, staff) do
    with :ok <- require_reason(reason) do
      until = if slot, do: DateTime.add(DateTime.utc_now(), @pin_days, :day)

      write(
        standing,
        %{
          override_slot: slot,
          override_reason: String.trim(reason),
          override_until: until,
          override_by_id: staff_id(staff),
          override_at: DateTime.utc_now()
        },
        cache_slot: slot || standing.slot,
        audit: if(slot, do: :directory_slot_overridden, else: :directory_slot_override_cleared),
        reason: reason,
        staff: staff,
        extra: %{
          "slot" => slot && Atom.to_string(slot),
          "until" => until && DateTime.to_iso8601(until)
        }
      )
    end
  end

  @doc "Bars a shop from every slot, or readmits it."
  @spec set_excluded(DirectoryStanding.t(), boolean(), String.t(), term()) ::
          {:ok, DirectoryStanding.t()} | {:error, term()}
  def set_excluded(standing, excluded?, reason, staff) do
    with :ok <- require_reason(reason) do
      write(
        standing,
        %{
          override_excluded: excluded?,
          override_reason: String.trim(reason),
          # An exclusion holds until reversed — no expiry.
          override_until: nil,
          override_by_id: staff_id(staff),
          override_at: DateTime.utc_now()
        },
        cache_slot: if(excluded?, do: nil, else: standing.slot),
        audit: if(excluded?, do: :directory_store_excluded, else: :directory_store_readmitted),
        reason: reason,
        staff: staff,
        extra: %{}
      )
    end
  end

  # ── Internals ──────────────────────────────────────────────────────────

  defp write(standing, attrs, opts) do
    Emakola.Repo.transaction(fn ->
      updated =
        standing
        |> Ash.Changeset.for_update(:override, attrs)
        |> Ash.update!(authorize?: false)

      Store
      |> Ash.get!(standing.store_id, authorize?: false)
      |> Ash.Changeset.for_update(:set_directory_standing, %{
        directory_slot: opts[:cache_slot]
      })
      |> Ash.update!(authorize?: false)

      store = Ash.get!(Store, standing.store_id, authorize?: false)

      PlatformAudit.log(
        opts[:audit],
        opts[:staff],
        Map.merge(
          %{
            "store_id" => standing.store_id,
            "store_slug" => store.slug,
            "reason" => String.trim(opts[:reason])
          },
          opts[:extra]
        )
      )

      updated
    end)
  end

  defp require_reason(reason) when is_binary(reason) do
    if String.trim(reason) == "", do: {:error, :reason_required}, else: :ok
  end

  defp require_reason(_other), do: {:error, :reason_required}

  defp staff_id(%{id: id}), do: id
  defp staff_id(_), do: nil
end
