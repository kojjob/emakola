defmodule Emakola.Repo.Migrations.AddUniqueOpenCreditAgreementIndex do
  @moduledoc """
  DB backstop for the service-level guard: a borrower store may hold at most
  one open (accepted or active) trade-credit agreement at a time. Two open
  agreements previously crashed every checkout for the store (read_one!).
  """

  use Ecto.Migration

  def up do
    create(
      unique_index(:partner_credit_agreements, [:borrower_store_id],
        where: "status IN ('accepted', 'active')",
        name: :partner_credit_agreements_one_open_per_borrower_index
      )
    )
  end

  def down do
    drop(
      index(:partner_credit_agreements, [:borrower_store_id],
        name: :partner_credit_agreements_one_open_per_borrower_index
      )
    )
  end
end
