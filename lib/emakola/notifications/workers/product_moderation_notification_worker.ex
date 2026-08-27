defmodule Emakola.Notifications.Workers.ProductModerationNotificationWorker do
  @moduledoc """
  Oban worker that notifies a merchant when the platform takes down or reinstates
  one of their products.

  Loads the product (+ its store) and sends an SMS to the store's `contact_phone`
  and a plain-text email to its `contact_email`, skipping whichever channel isn't
  filled in. Mirrors `VerificationStatusNotificationWorker`: idempotent, with a
  `unique` window absorbing retry storms and a double-clicked moderation action.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3,
    unique: [period: 600, fields: [:args]]

  require Ash.Query
  require Logger

  @events [:product_taken_down, :product_reinstated]

  @doc "Enqueues a product-moderation notification. Never raises."
  @spec enqueue(binary(), atom()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(product_id, event) when is_binary(product_id) and event in @events do
    %{"product_id" => product_id, "event" => Atom.to_string(event)}
    |> new()
    |> Oban.insert()
  rescue
    exception ->
      Logger.error(
        "[ProductModerationNotificationWorker] enqueue raised: #{Exception.message(exception)}"
      )

      {:error, {:enqueue_raised, Exception.message(exception)}}
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_id" => product_id, "event" => event_string}}) do
    event = Emakola.SafeAtom.to_atom_in(event_string, @events, :product_taken_down)

    case load_product(product_id) do
      {:ok, product} ->
        # Every member, not just the owner: a shop where only the owner hears
        # about a takedown is a shop where staff keep selling a delisted item.
        Emakola.Notifications.notify_store(product.store_id, :product_moderated, %{
          title: moderation_bell_title(event, product),
          action_url: "/admin/products"
        })

        results = [maybe_send_sms(product, event), maybe_send_email(product, event)]

        if Enum.any?(results, &match?({:error, _}, &1)) do
          Logger.error(
            "[ProductModerationNotificationWorker] delivery failed for product #{product_id}: #{inspect(results)}"
          )

          {:error, :notification_delivery_failed}
        else
          :ok
        end

      {:error, reason} ->
        Logger.error(
          "[ProductModerationNotificationWorker] product #{product_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # ── Private ─────────────────────────────────────────────────────

  defp load_product(product_id) do
    Emakola.Catalog.Product
    |> Ash.Query.filter(id == ^product_id)
    |> Ash.Query.load(:store)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :product_not_found}
      {:ok, product} -> {:ok, product}
      {:error, reason} -> {:error, reason}
    end
  end

  defp moderation_bell_title(:product_reinstated, product), do: "#{product.title} is back up"
  defp moderation_bell_title(_taken_down, product), do: "#{product.title} was taken down"

  defp maybe_send_sms(%{store: %{contact_phone: phone} = store} = product, event)
       when is_binary(phone) and phone != "" do
    sms_provider().send_sms(phone, message(product, event), store_id: store.id)
  end

  defp maybe_send_sms(_product, _event), do: :ok

  defp maybe_send_email(%{store: %{contact_email: email} = store} = product, event)
       when is_binary(email) and email != "" do
    Swoosh.Email.new()
    |> Swoosh.Email.to({store.name || "", email})
    |> Swoosh.Email.from(Emakola.Mailer.from_address("Makola"))
    |> Swoosh.Email.subject(subject(event))
    |> Swoosh.Email.text_body(message(product, event))
    |> Emakola.Mailer.deliver()
  end

  defp maybe_send_email(_product, _event), do: :ok

  defp subject(:product_taken_down), do: "A product was removed from your Makola store"
  defp subject(:product_reinstated), do: "A product was reinstated on your Makola store"

  defp message(%{title: title} = product, :product_taken_down),
    do:
      "#{store_name(product)}: \"#{title}\" was removed by Makola for a policy violation. Sign in for details."

  defp message(%{title: title} = product, :product_reinstated),
    do:
      "#{store_name(product)}: \"#{title}\" has been reinstated and is visible to customers again."

  defp store_name(%{store: %{name: name}}) when is_binary(name), do: name
  defp store_name(_), do: "Your store"

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end
end
