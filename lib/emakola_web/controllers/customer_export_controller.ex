defmodule EmakolaWeb.CustomerExportController do
  @moduledoc """
  The customers list as a CSV. Same session auth as ExportController: this
  route sits outside the live_session and never meets Hooks.RequireAuth.
  """
  use EmakolaWeb, :controller

  NimbleCSV.define(EmakolaWeb.CustomerCsv, separator: ",", escape: "\"")

  @header ~w(name phone email orders paid_total_ghs last_bought joined)

  def customers_csv(conn, _params) do
    with {:ok, merchant} <- resolve_merchant(conn),
         {:ok, store} <- resolve_store(merchant),
         :ok <- check_store_active(store) do
      customers = Emakola.Customers.list_customers_by_store!(store.id, authorize?: false)

      body =
        [@header | Enum.map(customers, &row/1)]
        |> EmakolaWeb.CustomerCsv.dump_to_iodata()
        |> IO.iodata_to_binary()

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="#{export_filename(store.slug)}")
      )
      |> send_resp(200, body)
    else
      {:error, :unauthenticated} ->
        conn |> put_status(401) |> text("Unauthorized")

      {:error, :no_store} ->
        conn
        |> put_flash(:error, "No store found. Complete onboarding first.")
        |> redirect(to: "/dashboard")

      {:error, :store_locked} ->
        conn |> put_status(403) |> text("Store locked")
    end
  end

  # Mirrors Hooks.RequireActiveStore's gate — only the platform lifecycle
  # `status` locks the export, same as it locks the admin LiveViews.
  defp check_store_active(%{status: status}) when status in [:suspended, :blocked, :archived],
    do: {:error, :store_locked}

  defp check_store_active(_store), do: :ok

  defp export_filename(slug) do
    sanitized = (slug || "") |> String.replace(~r/[^a-zA-Z0-9_-]/, "")
    name = if sanitized == "", do: "store", else: sanitized
    "#{name}-customers.csv"
  end

  defp row(customer) do
    [
      csv_safe(customer.name || ""),
      phone_cell(customer.phone),
      csv_safe((customer.email && to_string(customer.email)) || ""),
      Integer.to_string(customer.order_count || 0),
      cedis(customer.paid_total || 0),
      date(customer.last_order_at),
      date(customer.inserted_at)
    ]
  end

  # A valid E.164 number is digits and a leading "+" — never a formula, so it
  # exports as-is. Anything else (bad data, a formula string typed as a
  # "phone") goes through the same escape as every other free-text cell.
  defp phone_cell(phone) when is_binary(phone) do
    if Emakola.Accounts.PhoneAuth.valid?(phone), do: phone, else: csv_safe(phone)
  end

  defp phone_cell(_phone), do: ""

  # A cell starting with = + - @ is a formula to Excel and LibreOffice, and a
  # buyer types their own name. A leading apostrophe makes it text.
  defp csv_safe(<<first, _::binary>> = value) when first in [?=, ?+, ?-, ?@, ?\t, ?\r],
    do: "'" <> value

  defp csv_safe(value), do: value

  defp cedis(pesewas),
    do:
      "#{div(pesewas, 100)}.#{pesewas |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")}"

  defp date(nil), do: ""
  defp date(at), do: at |> DateTime.to_date() |> Date.to_iso8601()

  defp resolve_merchant(conn) do
    case EmakolaWeb.AuthTokens.verify_subject(get_session(conn, "user_token")) do
      {:error, _reason} ->
        {:error, :unauthenticated}

      {:ok, subject} ->
        case AshAuthentication.subject_to_user(subject, Emakola.Accounts.Merchant) do
          {:ok, merchant} ->
            if Emakola.Accounts.access_allowed?(merchant),
              do: {:ok, merchant},
              else: {:error, :unauthenticated}

          _ ->
            {:error, :unauthenticated}
        end
    end
  end

  defp resolve_store(merchant) do
    with {:ok, membership} when not is_nil(membership) <-
           Emakola.Accounts.get_merchant_store_membership(merchant.id, authorize?: false),
         {:ok, loaded} <- Ash.load(membership, :store, authorize?: false) do
      {:ok, loaded.store}
    else
      _ -> {:error, :no_store}
    end
  end
end
