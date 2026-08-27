defmodule Emakola.Repo.Migrations.AddPlatformCustomerThreads do
  @moduledoc """
  A third thread kind: Makola talking to a buyer.

  Until now a buyer could only reach their shop. When the complaint is about
  the shop — or about a payment the shop cannot see — there was nowhere for it
  to go except a contact form that became an email nobody could reply to in
  the app.

  ## Getting uniqueness without a partial index

  A `:platform_customer` thread carries a `customer_id` and **no** `store_id`,
  so `conversation_threads_one_per_buyer_index (store_id, customer_id)` gives
  it nothing: Postgres treats NULLs as distinct, every null-store row is
  unique regardless of customer, and each "open" would make another thread.
  That NULL behaviour is exactly what the original conversations migration
  relied on to let platform threads coexist under the buyer index.

  The obvious fix — a partial index `WHERE kind = 'platform_customer'` — is
  not available. These actions are upserts, `ON CONFLICT` needs an index whose
  predicate it can match, and an upsert against a partial index fails with
  42P10, as that same migration records.

  `(kind, customer_id)` is plain, and correct here because a customer row
  belongs to exactly one store (`Customers.Customer` is tenant-scoped by
  `store_id`). So one customer_id has at most one shop thread, making
  `(shop_buyer, customer)` unique too, while `(platform_merchant, NULL)` rows
  stay mutually distinct under ordinary NULL semantics and are left alone.
  """

  use Ecto.Migration

  def up do
    create(
      unique_index(:conversation_threads, [:kind, :customer_id],
        name: "conversation_threads_one_thread_per_kind_per_customer_index"
      )
    )
  end

  def down do
    drop(
      index(:conversation_threads, [:kind, :customer_id],
        name: "conversation_threads_one_thread_per_kind_per_customer_index"
      )
    )
  end
end
