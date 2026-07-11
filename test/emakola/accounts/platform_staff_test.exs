defmodule Emakola.Accounts.PlatformStaffTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.User

  defp set_platform_permissions!(user, attrs) do
    user
    |> Ash.Changeset.for_update(:set_platform_permissions, attrs)
    |> Ash.update!(authorize?: false)
  end

  defp set_platform_permissions(user, attrs) do
    user
    |> Ash.Changeset.for_update(:set_platform_permissions, attrs)
    |> Ash.update(authorize?: false)
  end

  defp deactivate_staff(user) do
    user
    |> Ash.Changeset.for_update(:deactivate_staff, %{})
    |> Ash.update(authorize?: false)
  end

  describe "read :platform_staff" do
    test "returns owners and permission holders, excludes plain users" do
      owner = create_platform_owner!()

      staff =
        create_user!()
        |> set_platform_permissions!(%{platform_permissions: [:manage_stores]})

      plain = create_user!()

      ids =
        User
        |> Ash.Query.for_read(:platform_staff)
        |> Ash.read!(authorize?: false)
        |> Enum.map(& &1.id)

      assert owner.id in ids
      assert staff.id in ids
      refute plain.id in ids
    end
  end

  describe "update :set_platform_permissions" do
    test "updates permissions and owner flag" do
      user = create_user!()

      updated =
        set_platform_permissions!(user, %{
          is_owner: true,
          platform_permissions: [:manage_team, :view_audit_log]
        })

      assert updated.is_owner
      assert updated.platform_permissions == [:manage_team, :view_audit_log]
    end

    test "rejects permissions outside the catalog" do
      user = create_user!()

      assert {:error, _} =
               set_platform_permissions(user, %{platform_permissions: [:hack_the_planet]})
    end

    test "demoting the only active owner errors" do
      owner = create_platform_owner!()

      assert {:error, %Ash.Error.Invalid{}} =
               set_platform_permissions(owner, %{is_owner: false})
    end

    test "demoting one of two active owners succeeds" do
      owner = create_platform_owner!()
      _other_owner = create_platform_owner!()

      assert {:ok, demoted} = set_platform_permissions(owner, %{is_owner: false})
      refute demoted.is_owner
    end

    test "a deactivated owner does not count towards the owner quorum" do
      owner = create_platform_owner!()
      other_owner = create_platform_owner!()
      {:ok, _} = deactivate_staff(other_owner)

      assert {:error, %Ash.Error.Invalid{}} =
               set_platform_permissions(owner, %{is_owner: false})
    end
  end

  describe "update :deactivate_staff" do
    test "sets deactivated_at" do
      staff =
        create_user!()
        |> set_platform_permissions!(%{platform_permissions: [:manage_stores]})

      assert {:ok, deactivated} = deactivate_staff(staff)
      assert %DateTime{} = deactivated.deactivated_at
    end

    test "deactivating the only active owner errors" do
      owner = create_platform_owner!()

      assert {:error, %Ash.Error.Invalid{}} = deactivate_staff(owner)
    end

    test "deactivating one of two active owners succeeds" do
      owner = create_platform_owner!()
      _other_owner = create_platform_owner!()

      assert {:ok, deactivated} = deactivate_staff(owner)
      assert deactivated.deactivated_at
    end
  end

  describe "update :reactivate_staff" do
    test "clears deactivated_at" do
      staff =
        create_user!()
        |> set_platform_permissions!(%{platform_permissions: [:manage_stores]})

      {:ok, deactivated} = deactivate_staff(staff)
      assert deactivated.deactivated_at

      reactivated =
        deactivated
        |> Ash.Changeset.for_update(:reactivate_staff, %{})
        |> Ash.update!(authorize?: false)

      assert is_nil(reactivated.deactivated_at)
    end
  end
end
