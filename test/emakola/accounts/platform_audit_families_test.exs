defmodule Emakola.Accounts.PlatformAuditFamiliesTest do
  @moduledoc """
  The audit log's two classifications of an action: its family (what the
  ledger filters by) and its severity (what colour it wears). Both must
  cover every action the resource can record, or a new action would fall
  through the filters unseen.
  """
  use ExUnit.Case, async: true

  alias Emakola.Accounts.PlatformAuditFamilies, as: Families
  alias Emakola.Accounts.PlatformAuditLog

  defp all_actions do
    Ash.Resource.Info.attribute(PlatformAuditLog, :action).constraints[:one_of]
  end

  test "every recordable action belongs to exactly one family" do
    for action <- all_actions() do
      family = Families.family_of(action)
      assert family in Families.keys(), "#{action} has no family"
      assert action in Families.actions(family)
    end

    assert Families.keys() |> Enum.flat_map(&Families.actions/1) |> Enum.sort() ==
             Enum.sort(all_actions())
  end

  test "families carry display labels in filter order" do
    assert Families.families() == [
             sign_ins: "Sign-ins",
             staff: "Staff",
             stores: "Stores",
             moderation: "Moderation",
             directory: "Directory",
             finance: "Finance",
             announcements: "Announcements"
           ]
  end

  test "severity_of: destructive red, cautionary amber, restorative green, the rest neutral" do
    assert Families.severity_of(:store_blocked) == :red
    assert Families.severity_of(:sign_in_failed) == :red
    assert Families.severity_of(:store_suspended) == :amber
    assert Families.severity_of(:impersonation_started) == :amber
    assert Families.severity_of(:store_reactivated) == :green
    assert Families.severity_of(:sign_in_succeeded) == :green
    assert Families.severity_of(:permissions_changed) == :neutral
    assert Families.severity_of(:payout_approved) == :neutral
  end

  test "severity_actions/1 partitions every action across the four severities" do
    partitioned = Enum.flat_map([:red, :amber, :green, :neutral], &Families.severity_actions/1)

    assert Enum.sort(partitioned) == Enum.sort(all_actions())
  end
end
