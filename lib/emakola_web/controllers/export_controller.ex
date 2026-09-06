defmodule EmakolaWeb.ExportController do
  @moduledoc """
  Controller for exporting analytics data as downloadable files.

  Authentication follows the same session-based pattern used by the admin
  LiveViews: the merchant token is stored in session as `user_token`, and
  the store is resolved via StoreMembership.
  """
  use EmakolaWeb, :controller

  require Logger

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
            "#{slug_segment(store.slug)}-analytics-" <>
              "#{Date.to_string(date_range.first)}-to-#{Date.to_string(date_range.last)}.pdf"

          conn
          |> put_resp_content_type("application/pdf")
          |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
          |> send_resp(200, pdf_binary)

        {:error, reason} ->
          Logger.error("[Export] PDF report generation failed: #{inspect(reason)}")

          conn
          |> put_flash(:error, "We couldn't generate that PDF report. Please try again.")
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

  # `Store.slug` carries only a length cap and a unique identity — no format
  # constraint — and both :create and :update_settings accept it, so its shape
  # is enforced only by whichever caller happens to slugify. Plug rejects
  # control characters in header values, so this is not CRLF injection; a
  # quote in a slug would simply break the filename quoting.
  #
  # Deliberately duplicated from CustomerExportController.export_filename/2,
  # which is private there, rather than extracted: the two controllers sit on
  # adjacent router lines and must not disagree about this.
  defp slug_segment(slug) do
    sanitized = (slug || "") |> String.replace(~r/[^a-zA-Z0-9_-]/, "")
    if sanitized == "", do: "store", else: sanitized
  end

  defp resolve_merchant(conn) do
    case EmakolaWeb.AuthTokens.verify_subject(get_session(conn, "user_token")) do
      {:error, _reason} ->
        {:error, :unauthenticated}

      {:ok, subject} ->
        case AshAuthentication.subject_to_user(subject, Emakola.Accounts.Merchant) do
          # Unverified is refused here, not just in the LiveViews. Every other
          # merchant surface sits behind Hooks.RequireAuth; this route is a
          # plain controller and never meets that hook, so without this clause
          # a merchant locked out of the app could still pull a report out of
          # it. 401 rather than a redirect to /auth/verify: nothing links here
          # except /admin/reports, which they cannot reach either way.
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
