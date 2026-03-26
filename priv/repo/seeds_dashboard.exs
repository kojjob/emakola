# priv/repo/seeds_dashboard.exs
#
# Run AFTER main seeds: mix run priv/repo/seeds_dashboard.exs
# Or: mix ecto.reset && mix run priv/repo/seeds.exs && mix run priv/repo/seeds_dashboard.exs
#
# Adds 30 days of historical order data so dashboard charts, recent-orders
# lists, and low-stock alerts panels look populated with realistic data.

require Ash.Query

IO.puts("Seeding dashboard historical data...")

# ── Helpers ──────────────────────────────────────────────────────────────────

defmodule DashboardSeeds do
  @doc "Backdate inserted_at and updated_at by N days from now."
  def backdate!(table, id, days_ago) do
    ts =
      DateTime.utc_now()
      |> DateTime.add(-days_ago * 86_400, :second)
      |> DateTime.truncate(:second)

    {:ok, uuid_binary} = Ecto.UUID.dump(id)

    Emakola.Repo.query!(
      "UPDATE #{table} SET inserted_at = $1, updated_at = $1 WHERE id = $2",
      [ts, uuid_binary]
    )
  end

  def random_phone do
    prefix = Enum.random(["24", "25", "54", "55", "20", "50"])
    suffix = :rand.uniform(9_999_999) |> Integer.to_string() |> String.pad_leading(7, "0")
    "+233#{prefix}#{suffix}"
  end
end

# ── Load existing stores and variants ────────────────────────────────────────

store1 =
  Emakola.Accounts.Store
  |> Ash.Query.filter(slug == "kente-kingdom")
  |> Ash.read_one!(authorize?: false)

store2 =
  Emakola.Accounts.Store
  |> Ash.Query.filter(slug == "accra-fresh")
  |> Ash.read_one!(authorize?: false)

variants1 =
  Emakola.Catalog.Variant
  |> Ash.Query.filter(store_id == ^store1.id)
  |> Ash.read!(authorize?: false)

variants2 =
  Emakola.Catalog.Variant
  |> Ash.Query.filter(store_id == ^store2.id)
  |> Ash.read!(authorize?: false)

IO.puts("  Found #{length(variants1)} variants for Kente Kingdom")
IO.puts("  Found #{length(variants2)} variants for Accra Fresh Market")

# ── Ghanaian names for realistic customers ───────────────────────────────────

first_names =
  ~w(Kwame Kofi Yaw Kojo Kwesi Kwadwo Akua Ama Afua Adwoa Akosua Yaa Afia Adjoa Abena Esi Nana Efua)

last_names =
  ~w(Asante Mensah Boateng Owusu Osei Darko Adjei Amponsah Badu Frimpong Tetteh Acheampong Appiah Bonsu)

# ── Create customers spread over 30 days ────────────────────────────────────

IO.puts("  Creating historical customers...")

customers1 =
  for i <- 1..12 do
    name = "#{Enum.random(first_names)} #{Enum.random(last_names)}"

    customer =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:create, %{
        email: "cust.kk.#{i}.#{System.unique_integer([:positive])}@example.com",
        name: name,
        phone: DashboardSeeds.random_phone(),
        store_id: store1.id
      })
      |> Ash.create!()

    days_ago = Enum.random(1..28)
    DashboardSeeds.backdate!("customers", customer.id, days_ago)
    {customer, days_ago}
  end

customers2 =
  for i <- 1..10 do
    name = "#{Enum.random(first_names)} #{Enum.random(last_names)}"

    customer =
      Emakola.Customers.Customer
      |> Ash.Changeset.for_create(:create, %{
        email: "cust.af.#{i}.#{System.unique_integer([:positive])}@example.com",
        name: name,
        phone: DashboardSeeds.random_phone(),
        store_id: store2.id
      })
      |> Ash.create!()

    days_ago = Enum.random(1..28)
    DashboardSeeds.backdate!("customers", customer.id, days_ago)
    {customer, days_ago}
  end

IO.puts("  Created #{length(customers1) + length(customers2)} customers")

# ── Helper to create orders for a store ──────────────────────────────────────

defmodule DashboardSeeds.OrderCreator do
  @doc """
  Create historical orders for a store from a pool of {customer, days_ago} tuples.
  """
  def create_orders(store_id, customer_pool, variants, count) do
    # Duplicate the pool so we can pick more orders than customers
    expanded = customer_pool ++ customer_pool ++ customer_pool
    picks = Enum.take_random(expanded, count)

    Enum.each(picks, fn {customer, days_ago} ->
      variant = Enum.random(variants)
      qty = Enum.random(1..3)
      delivery_fee = Enum.random([0, 1500, 2000, 3000, 4500])

      case Emakola.Orders.CheckoutService.checkout!(
             store_id,
             [%{variant_id: variant.id, quantity: qty}],
             customer_id: customer.id,
             delivery_fee: delivery_fee
           ) do
        {:ok, order} ->
          # Backdate the order and its line items
          DashboardSeeds.backdate!("orders", order.id, days_ago)

          line_items =
            Emakola.Orders.LineItem
            |> Ash.Query.filter(order_id == ^order.id)
            |> Ash.read!(authorize?: false)

          for li <- line_items do
            DashboardSeeds.backdate!("line_items", li.id, days_ago)
          end

          # Create payment -- 85% success, 15% failed
          status = if :rand.uniform(100) <= 85, do: :success, else: :failed
          gateway = Enum.random([:paystack, :hubtel])

          payment =
            Emakola.Payments.Payment
            |> Ash.Changeset.for_create(:create, %{
              store_id: store_id,
              order_id: order.id,
              amount: order.total,
              currency: "GHS",
              gateway: gateway,
              gateway_reference:
                "SEED_#{:crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower) |> binary_part(0, 12)}",
              customer_email: to_string(customer.email)
            })
            |> Ash.create!()

          if status == :success do
            payment
            |> Ash.Changeset.for_update(:mark_success, %{
              gateway_response: %{"status" => "success", "channel" => "mobile_money"}
            })
            |> Ash.update!()

            # Advance some orders through the status lifecycle
            advance_order_status(order)
          else
            payment
            |> Ash.Changeset.for_update(:mark_failed, %{
              gateway_response: %{"status" => "failed", "reason" => "insufficient_funds"}
            })
            |> Ash.update!()
          end

          DashboardSeeds.backdate!("payments", payment.id, days_ago)

        {:error, reason} ->
          IO.puts("    Skipping order (#{inspect(reason)})")
      end
    end)
  end

  defp advance_order_status(order) do
    case Enum.random([:pending, :confirmed, :processing, :shipped, :delivered]) do
      :pending ->
        :ok

      :confirmed ->
        order |> Ash.Changeset.for_update(:confirm, %{}) |> Ash.update!()

      :processing ->
        {:ok, order} =
          order |> Ash.Changeset.for_update(:confirm, %{}) |> Ash.update()

        if order, do: order |> Ash.Changeset.for_update(:start_processing, %{}) |> Ash.update()

      :shipped ->
        with {:ok, order} <- order |> Ash.Changeset.for_update(:confirm, %{}) |> Ash.update(),
             {:ok, order} <-
               order |> Ash.Changeset.for_update(:start_processing, %{}) |> Ash.update() do
          order |> Ash.Changeset.for_update(:mark_shipped, %{}) |> Ash.update()
        end

      :delivered ->
        with {:ok, order} <- order |> Ash.Changeset.for_update(:confirm, %{}) |> Ash.update(),
             {:ok, order} <-
               order |> Ash.Changeset.for_update(:start_processing, %{}) |> Ash.update(),
             {:ok, order} <-
               order |> Ash.Changeset.for_update(:mark_shipped, %{}) |> Ash.update() do
          order |> Ash.Changeset.for_update(:mark_delivered, %{}) |> Ash.update()
        end
    end
  end
end

# ── Create historical orders ─────────────────────────────────────────────────

IO.puts("  Creating historical orders for Kente Kingdom...")
DashboardSeeds.OrderCreator.create_orders(store1.id, customers1, variants1, 18)

IO.puts("  Creating historical orders for Accra Fresh Market...")
DashboardSeeds.OrderCreator.create_orders(store2.id, customers2, variants2, 15)

# ── Set a few variants to low stock for alerts panel ─────────────────────────

IO.puts("  Setting low-stock variants...")

low_stock_variants = Enum.take_random(variants1, 2) ++ Enum.take_random(variants2, 1)

for v <- low_stock_variants do
  target = Enum.random(1..5)

  v
  |> Ash.Changeset.for_update(:update, %{stock_quantity: target})
  |> Ash.update!()
end

IO.puts("")
IO.puts("Dashboard seed data complete!")
IO.puts("  ~22 new customers across both stores")
IO.puts("  ~33 historical orders backdated across 30 days")
IO.puts("  3 low-stock variants for alerts panel")
IO.puts("  ~15% failed payments for payment status variety")
