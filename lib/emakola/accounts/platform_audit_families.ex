defmodule Emakola.Accounts.PlatformAuditFamilies do
  @moduledoc """
  Two classifications of a platform audit action, shared by the ledger's
  filters, its colours, and the CSV export: the FAMILY (which area of the
  platform the action touched) and the SEVERITY (how alarmed a reader
  should be). Every action `PlatformAuditLog` can record sits in exactly
  one family and one severity; the tests check both against the
  resource's own enum, so a new action cannot slip through unclassified.
  """

  @families [
    sign_ins: "Sign-ins",
    staff: "Staff",
    stores: "Stores",
    moderation: "Moderation",
    directory: "Directory",
    finance: "Finance",
    announcements: "Announcements"
  ]

  @actions %{
    sign_ins: [
      :sign_in_succeeded,
      :sign_in_failed,
      :totp_failed,
      :totp_enabled,
      :totp_disabled,
      :sign_out,
      :session_revoked,
      :sessions_force_revoked
    ],
    staff: [
      :invite_created,
      :invite_accepted,
      :invite_revoked,
      :permissions_changed,
      :owner_changed,
      :staff_deactivated,
      :staff_reactivated,
      :staff_removed,
      :impersonation_started,
      :impersonation_ended
    ],
    stores: [
      :store_suspended,
      :store_blocked,
      :store_archived,
      :store_reactivated,
      :domain_approved,
      :domain_rejected,
      :verification_approved,
      :verification_rejected
    ],
    moderation: [:product_taken_down, :product_reinstated],
    directory: [
      :directory_slot_overridden,
      :directory_slot_override_cleared,
      :directory_override_expired,
      :directory_store_excluded,
      :directory_store_readmitted,
      :store_featured,
      :store_unfeatured,
      :store_verified_badge_granted,
      :store_verified_badge_revoked
    ],
    finance: [
      :payout_approved,
      :payout_retried,
      :protection_force_released,
      :protection_refund_initiated
    ],
    announcements: [:announcement_published, :announcement_canceled]
  }

  @family_of for {family, actions} <- @actions, action <- actions, into: %{}, do: {action, family}

  @red [
    :sign_in_failed,
    :totp_failed,
    :sessions_force_revoked,
    :staff_deactivated,
    :staff_removed,
    :store_blocked,
    :store_archived,
    :verification_rejected,
    :product_taken_down
  ]
  @amber [
    :directory_store_excluded,
    :directory_slot_overridden,
    :store_unfeatured,
    :store_verified_badge_revoked,
    :session_revoked,
    :invite_revoked,
    :totp_disabled,
    :store_suspended,
    :impersonation_started,
    :announcement_canceled
  ]
  @green [
    :directory_store_readmitted,
    :store_featured,
    :store_verified_badge_granted,
    :sign_in_succeeded,
    :invite_accepted,
    :totp_enabled,
    :staff_reactivated,
    :store_reactivated,
    :verification_approved,
    :impersonation_ended,
    :product_reinstated,
    :announcement_published
  ]

  @doc "Families in filter order, as `{key, label}` pairs."
  def families, do: @families

  def keys, do: Keyword.keys(@families)

  def actions(family), do: Map.fetch!(@actions, family)

  def all_actions, do: @actions |> Map.values() |> List.flatten()

  @doc "The family an action belongs to; nil for an action the ledger has never heard of."
  def family_of(action), do: Map.get(@family_of, action)

  def severities, do: [:red, :amber, :green, :neutral]

  def severity_of(action) when action in @red, do: :red
  def severity_of(action) when action in @amber, do: :amber
  def severity_of(action) when action in @green, do: :green
  def severity_of(_action), do: :neutral

  def severity_actions(:red), do: @red
  def severity_actions(:amber), do: @amber
  def severity_actions(:green), do: @green
  def severity_actions(:neutral), do: all_actions() -- (@red ++ @amber ++ @green)
end
