defmodule EmakolaWeb.Storefront.DownloadController do
  @moduledoc """
  Customer-facing download endpoint.

      GET /s/:store_slug/downloads/:id

  Resolves the current customer from the session, verifies they own the
  `Emakola.Fulfillment.DownloadGrant`, then delegates to
  `Emakola.Fulfillment.DownloadService` for URL issuance + counter
  bookkeeping + limit/expiry enforcement. On success, redirects to the
  presigned URL.

  ## Status code map

      302 Found                — happy path; redirect to presigned URL
      401 Unauthorized         — no customer session
      404 Not Found            — grant doesn't exist OR not owned by
                                 this customer (we deliberately don't
                                 distinguish — see below)
      410 Gone                 — grant expired or download limit reached
      503 Service Unavailable  — storage adapter failure

  ## Why 404 for not-owner instead of 403

  Returning 403 ("exists but forbidden") confirms the grant ID exists,
  enabling ID enumeration. 404 ("no such grant for you") leaks nothing.

  ## Why 410 Gone for expired/limit, not 404

  The resource *existed* and the buyer *had access* — a semantic
  difference from "never existed." 410 tells browsers and intermediaries
  to stop retrying and not cache as "not found."

  ## Guest grants

  Grants with `customer_id == nil` (guest checkout) are not accessible
  via this endpoint — they need a signed token delivered via email. The
  controller refuses them with 404 to preserve the no-leak property.
  Token-based guest flow is a separate slice.
  """
  use EmakolaWeb, :controller

  alias Emakola.Fulfillment.DownloadService

  def show(conn, %{"id" => id}) do
    with {:ok, customer} <- current_customer(conn),
         {:ok, grant} <- load_grant(id),
         :ok <- check_ownership(grant, customer) do
      respond(conn, DownloadService.issue_url(grant))
    else
      :no_session -> send_resp(conn, 401, "")
      {:error, :not_found} -> send_resp(conn, 404, "")
      {:error, :not_owner} -> send_resp(conn, 404, "")
    end
  end

  defp respond(conn, {:ok, url}), do: redirect(conn, external: url)

  defp respond(conn, {:error, :expired}),
    do: send_resp(conn, 410, "This download link has expired.")

  defp respond(conn, {:error, :limit_reached}),
    do: send_resp(conn, 410, "Download limit reached for this purchase.")

  defp respond(conn, {:error, {:storage, _reason}}),
    do: send_resp(conn, 503, "Download temporarily unavailable. Please try again.")

  defp current_customer(conn) do
    case get_session(conn, "customer_token") do
      nil ->
        :no_session

      token ->
        case AshAuthentication.subject_to_user(token, Emakola.Customers.Customer) do
          {:ok, customer} -> {:ok, customer}
          _ -> :no_session
        end
    end
  end

  defp load_grant(id) do
    case Emakola.Fulfillment.get_download_grant(id, authorize?: false) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, grant} ->
        {:ok, Ash.load!(grant, :digital_file, authorize?: false)}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  # Guest grants (customer_id nil) are not accessible via the
  # session-authenticated endpoint — they require the token flow.
  defp check_ownership(%{customer_id: nil}, _customer), do: {:error, :not_owner}
  defp check_ownership(%{customer_id: id}, %{id: id}), do: :ok
  defp check_ownership(_grant, _customer), do: {:error, :not_owner}
end
