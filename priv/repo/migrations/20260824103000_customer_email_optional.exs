defmodule Emakola.Repo.Migrations.CustomerEmailOptional do
  @moduledoc """
  Lets a buyer exist with a phone and no email.

  Most buyers in this market do not use email, and requiring it made the
  WhatsApp signup ask for an address the buyer did not have. Reachability is
  enforced in the resource instead (`ContactDetailPresent`): a customer needs
  a phone or an email.

  The unique indexes on email keep working — Postgres treats NULLs as
  distinct, so any number of phone-only customers coexist.
  """

  use Ecto.Migration

  def up do
    alter table(:customers) do
      modify(:email, :citext, null: true)
    end
  end

  def down do
    # Irreversible in the presence of phone-only customers: restoring the
    # constraint would fail on any row this change made possible. Deleting
    # those buyers to satisfy a schema rollback would be worse than the
    # rollback failing loudly here.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM customers WHERE email IS NULL) THEN
        RAISE EXCEPTION
          'cannot restore customers.email NOT NULL: phone-only customers exist';
      END IF;
    END $$;
    """)

    alter table(:customers) do
      modify(:email, :citext, null: false)
    end
  end
end
