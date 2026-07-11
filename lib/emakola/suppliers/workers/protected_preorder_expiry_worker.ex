defmodule Emakola.Suppliers.Workers.ProtectedPreorderExpiryWorker do
  @moduledoc "Enforces preorder refund deadlines and overdue production milestones."
  use Oban.Worker, queue: :payments, max_attempts: 5, unique: [period: 300, fields: [:args]]
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"preorder_id" => id}}) do
    case Emakola.Suppliers.ProtectedPreorders.fail_and_refund(
           id,
           "Automatic deadline or milestone failure"
         ) do
      {:ok, results} ->
        if Enum.any?(results, &match?({:error, _, _}, &1)),
          do: {:error, :refund_failed},
          else: :ok

      {:error, :failure_not_due} ->
        :ok
    end
  end

  def perform(%Oban.Job{}) do
    Emakola.Suppliers.ProtectedPreorder
    |> Ash.Query.filter(
      status in [:open, :funded, :production] or
        (status in [:failed, :refunded] and
           exists(deposits, status in [:paid, :refunding, :refund_failed]))
    )
    |> Ash.read!(authorize?: false)
    |> Enum.filter(&Emakola.Suppliers.ProtectedPreorders.due_for_failure?/1)
    |> Enum.each(fn preorder -> %{preorder_id: preorder.id} |> new() |> Oban.insert!() end)

    :ok
  end
end
