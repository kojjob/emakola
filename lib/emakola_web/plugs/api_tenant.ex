defmodule EmakolaWeb.Plugs.ApiTenant do
  @moduledoc """
  Resolves the Ash tenant for `/api/v1` requests from the `X-Store-ID` header.

  The store id must belong to a store the authenticated merchant (the Ash
  actor, set by `ApiBearerAuth`) is a member of. Anything else — missing
  header, malformed UUID, missing actor, or a store the merchant has no
  membership in — is a uniform 403 so the API does not leak which store
  ids exist.
  """

  @behaviour Plug

  import Plug.Conn

  require Ash.Query

  alias Emakola.Accounts.{Merchant, StoreMembership}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with %Merchant{} = merchant <- Ash.PlugHelpers.get_actor(conn),
         [raw_store_id] <- get_req_header(conn, "x-store-id"),
         # Rebind to the cast result: Ecto.UUID.cast normalizes to lowercase,
         # and only the canonical form may exist past this point (policy
         # checks and PubSub topics compare tenant ids as strings).
         {:ok, store_id} <- Ecto.UUID.cast(raw_store_id),
         true <- member?(merchant, store_id) do
      Ash.PlugHelpers.set_tenant(conn, store_id)
    else
      _ ->
        conn
        |> put_resp_content_type("application/vnd.api+json", nil)
        |> send_resp(
          403,
          Jason.encode!(%{
            errors: [
              %{
                status: "403",
                code: "forbidden",
                detail: "X-Store-ID header missing or store not accessible"
              }
            ]
          })
        )
        |> halt()
    end
  end

  defp member?(%Merchant{id: merchant_id}, store_id) do
    StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.exists?(authorize?: false)
  end
end
