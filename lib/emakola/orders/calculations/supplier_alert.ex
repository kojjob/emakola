defmodule Emakola.Orders.Calculations.SupplierAlert do
  @moduledoc """
  One value per order answering "does a supplier need me?", so the orders LIST
  can say it without the merchant opening anything.

  Before this, escalation lived only inside an order's detail page. The clock
  fired, the bell rang, and the merchant landed on a list that looked entirely
  normal — which is close to the chasing the clock exists to end.

  Returns, most urgent first:

    * `:blocked`     — a supplier declined, or stopped answering entirely. The
                       merchant has to re-source, cancel or refund.
    * `:unreachable` — a message never reached the supplier. Nobody has been
                       asked to ship anything yet.
    * `:waiting`     — chased and still silent.
    * `:accepted`    — a supplier said they have it. Reassurance, not a task.
    * `nil`          — nothing worth a chip: no supplier groups, or all of them
                       already shipped, delivered or cancelled.

  Unlike `Emakola.Orders.Calculations.FulfillmentStatus`, this one never raises
  on a status it has not met. That calculation's `raise` took down every order
  view the first time a new status appeared, and this one is loaded in exactly
  the same places — a list chip is not worth a 500.
  """
  use Ash.Resource.Calculation

  # Statuses where a supplier still owes the merchant something. Anything else
  # has either been handled or is over.
  @open [:pending, :notified, :declined]

  @impl true
  def load(_query, _opts, _context) do
    [
      fulfillments:
        Ash.Query.select(Emakola.Orders.Fulfillment, [
          :status,
          :supplier_id,
          :accepted_at,
          :escalation_level,
          :last_send_error
        ])
    ]
  end

  @impl true
  def calculate(orders, _opts, _context) do
    Enum.map(orders, &alert(&1.fulfillments))
  end

  defp alert(fulfillments) when is_list(fulfillments) do
    open =
      Enum.filter(fulfillments, fn f ->
        not is_nil(f.supplier_id) and f.status in @open
      end)

    cond do
      open == [] -> nil
      Enum.any?(open, &blocked?/1) -> :blocked
      Enum.any?(open, &unreachable?/1) -> :unreachable
      Enum.any?(open, &waiting?/1) -> :waiting
      Enum.any?(open, &(not is_nil(&1.accepted_at))) -> :accepted
      true -> nil
    end
  end

  defp alert(_not_loaded), do: nil

  defp blocked?(f), do: f.status == :declined or f.escalation_level >= 3
  defp unreachable?(f), do: not is_nil(f.last_send_error)
  defp waiting?(f), do: f.escalation_level >= 1 and is_nil(f.accepted_at)
end
