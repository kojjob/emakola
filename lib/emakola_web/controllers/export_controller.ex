defmodule EmakolaWeb.ExportController do
  @moduledoc """
  Controller for exporting analytics data as downloadable files.

  Authentication follows the same session-based pattern used by the admin
  LiveViews: the merchant token is stored in session as `user_token`, and
  the store is resolved via StoreMembership.
  """
  use EmakolaWeb, :controller

  require Ash.Query

  @doc """
  Generates and sends a PDF analytics report for the authenticated
  merchant's store.

  Query params:
  - `start_date` (YYYY-MM-DD) -- defaults to 30 days ago
  - `end_date`   (YYYY-MM-DD) -- defaults to today
  """
  def analytics_pdf(conn, params) do
    with {:ok, merchant} <- resolve_merchant(conn),
         {:ok, store} <- resolve_store(merchant),
         {:ok, date_range} <- parse_date_range(params) do
      case Emakola.Analytics.PdfReport.generate(store, date_range) do
        {:ok, pdf_base64} ->
          pdf_binary = Base.decode64!(pdf_base64)

          filename =
            "#{store.slug || "store"}-analytics-#{Date.to_string(date_range.first)}-to-#{Date.to_string(date_range.last)}.pdf"

          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_resp(200, pdf_binary)

        {:error, reason} ->
          conn
          |> put_flash(:error, "Failed to generate PDF report: #{inspect(reason)}")
          |> redirect(to: "/admin/reports")
      end
    else
      {:error, :unauthenticated} ->
        conn
        |> put_status(401)
        |> text("Unauthorized")

      {:error, :no_store} ->
        conn
        |> put_flash(:error, "No store found. Complete onboarding first.")
        |> redirect(to: "/dashboard")

      {:error, :invalid_dates} ->
        conn
        |> put_flash(:error, "Invalid date range provided.")
        |> redirect(to: "/admin/reports")
    end
  end

  # ── Private helpers ──────────────────────────────────────────────

  defp resolve_merchant(conn) do
    case get_session(conn, "user_token") do
      nil ->
        {:error, :unauthenticated}

      token ->
        case AshAuthentication.subject_to_user(token, Emakola.Accounts.Merchant) do
          {:ok, merchant} -> {:ok, merchant}
          _ -> {:error, :unauthenticated}
        end
    end
  end

  defp resolve_store(merchant) do
    case Emakola.Accounts.StoreMembership
         |> Ash.Query.filter(merchant_id: merchant.id)
         |> Ash.Query.load(:store)
         |> Ash.Query.limit(1)
         |> Ash.read(authorize?: false) do
      {:ok, [membership | _]} -> {:ok, membership.store}
      _ -> {:error, :no_store}
    end
  end

  defp parse_date_range(params) do
    today = Date.utc_today()
    default_start = Date.add(today, -30)

    with {:ok, start_date} <- parse_date(params["start_date"], default_start),
         {:ok, end_date} <- parse_date(params["end_date"], today) do
      if Date.compare(start_date, end_date) in [:lt, :eq] do
        {:ok, Date.range(start_date, end_date)}
      else
        {:error, :invalid_dates}
      end
    end
  end

  defp parse_date(nil, default), do: {:ok, default}
  defp parse_date("", default), do: {:ok, default}

  defp parse_date(date_string, _default) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_dates}
    end
  end
end
