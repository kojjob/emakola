defmodule Emakola.Accounts.PlatformPermissionsTest do
  use ExUnit.Case, async: true

  alias Emakola.Accounts.PlatformPermissions

  describe "all/0" do
    test "returns the full permission catalog" do
      assert PlatformPermissions.all() == [
               :manage_stores,
               :manage_merchants,
               :manage_team,
               :view_audit_log,
               :manage_billing,
               :manage_settings
             ]
    end
  end

  describe "staff?/1" do
    test "nil is not staff" do
      refute PlatformPermissions.staff?(nil)
    end

    test "deactivated owner is not staff" do
      user = %{is_owner: true, deactivated_at: DateTime.utc_now(), platform_permissions: []}
      refute PlatformPermissions.staff?(user)
    end

    test "active owner is staff" do
      user = %{is_owner: true, deactivated_at: nil, platform_permissions: []}
      assert PlatformPermissions.staff?(user)
    end

    test "active user with at least one permission is staff" do
      user = %{is_owner: false, deactivated_at: nil, platform_permissions: [:manage_stores]}
      assert PlatformPermissions.staff?(user)
    end

    test "plain active user with no permissions is not staff" do
      user = %{is_owner: false, deactivated_at: nil, platform_permissions: []}
      refute PlatformPermissions.staff?(user)
    end

    test "partial map with no known staff fields is not staff" do
      refute PlatformPermissions.staff?(%{name: "Alice"})
    end
  end

  describe "allowed?/2" do
    test "owner bypasses permission checks" do
      user = %{is_owner: true, deactivated_at: nil, platform_permissions: []}

      assert PlatformPermissions.allowed?(user, :manage_stores)
      assert PlatformPermissions.allowed?(user, :manage_billing)
    end

    test "nil user is never allowed" do
      refute PlatformPermissions.allowed?(nil, :manage_stores)
    end

    test "deactivated user is never allowed, even an owner" do
      deactivated = %{
        is_owner: true,
        deactivated_at: DateTime.utc_now(),
        platform_permissions: [:manage_stores]
      }

      refute PlatformPermissions.allowed?(deactivated, :manage_stores)
    end

    test "allowed when permission is present" do
      user = %{is_owner: false, deactivated_at: nil, platform_permissions: [:manage_team]}

      assert PlatformPermissions.allowed?(user, :manage_team)
    end

    test "denied when permission is absent" do
      user = %{is_owner: false, deactivated_at: nil, platform_permissions: [:manage_team]}

      refute PlatformPermissions.allowed?(user, :manage_stores)
    end

    test "partial map with nil platform_permissions returns false without raising" do
      user = %{is_owner: false, deactivated_at: nil, platform_permissions: nil}

      refute PlatformPermissions.allowed?(user, :manage_stores)
    end
  end

  describe "valid?/1" do
    test "true for catalog members" do
      for permission <- PlatformPermissions.all() do
        assert PlatformPermissions.valid?(permission)
      end
    end

    test "false for anything else" do
      refute PlatformPermissions.valid?(:hack_the_planet)
      refute PlatformPermissions.valid?("manage_stores")
      refute PlatformPermissions.valid?(nil)
    end
  end

  describe "cast_list/1" do
    test "casts valid permission strings to atoms" do
      assert PlatformPermissions.cast_list(["manage_stores", "view_audit_log"]) ==
               [:manage_stores, :view_audit_log]
    end

    test "drops invalid and garbage entries" do
      assert PlatformPermissions.cast_list([
               "manage_team",
               "not_a_permission",
               "drop table users;",
               "",
               "manage_billing"
             ]) == [:manage_team, :manage_billing]
    end

    test "empty list casts to empty list" do
      assert PlatformPermissions.cast_list([]) == []
    end
  end
end
