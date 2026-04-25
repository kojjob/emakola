defmodule Emakola.AccountsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Accounts.{User, Organisation, Membership}
  import Emakola.Factory

  describe "User registration" do
    test "creates user with password" do
      assert {:ok, user} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: unique_email(),
                 password: "Password123!",
                 password_confirmation: "Password123!"
               })
               |> Ash.create(authorize?: false)

      assert user.email
      assert user.hashed_password
    end

    test "rejects duplicate email" do
      email = unique_email()

      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!(authorize?: false)

      assert {:error, _} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: email,
                 password: "Password123!",
                 password_confirmation: "Password123!"
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "Organisation" do
    test "creates org with auto-slug" do
      assert {:ok, org} =
               Organisation
               |> Ash.Changeset.for_create(:create, %{name: "My Cool Company"})
               |> Ash.create(authorize?: false)

      assert org.name == "My Cool Company"
      assert org.slug == "my-cool-company"
    end

    test "slug uniqueness" do
      Organisation
      |> Ash.Changeset.for_create(:create, %{name: "Unique Org"})
      |> Ash.create!(authorize?: false)

      assert {:error, _} =
               Organisation
               |> Ash.Changeset.for_create(:create, %{name: "Unique Org"})
               |> Ash.create(authorize?: false)
    end
  end

  describe "Membership" do
    test "creates membership linking user and org" do
      user = create_user!()
      org = create_organisation!()

      assert {:ok, membership} =
               Membership
               |> Ash.Changeset.for_create(:create, %{
                 role: :member,
                 user_id: user.id,
                 organisation_id: org.id
               })
               |> Ash.create(authorize?: false)

      assert membership.role == :member
    end

    test "prevents duplicate user/org membership" do
      user = create_user!()
      org = create_organisation!()

      create_membership!(user, org)

      assert {:error, _} =
               Membership
               |> Ash.Changeset.for_create(:create, %{
                 role: :admin,
                 user_id: user.id,
                 organisation_id: org.id
               })
               |> Ash.create(authorize?: false)
    end

    test "supports role change" do
      user = create_user!()
      org = create_organisation!()
      membership = create_membership!(user, org, :member)

      assert {:ok, updated} =
               membership
               |> Ash.Changeset.for_update(:change_role, %{role: :admin})
               |> Ash.update(authorize?: false)

      assert updated.role == :admin
    end
  end
end
