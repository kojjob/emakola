defmodule Emakola.Infra.FlyCerts do
  @moduledoc """
  Fly.io certificate provisioning over its GraphQL API.

  Merchants point their own domain at the app; Fly gets a free Let's Encrypt
  certificate for it once DNS resolves. This wraps the three operations we
  need so no Fly field name leaks into the rest of the codebase.

  **Ships dark.** Without `FLY_API_TOKEN` every function returns
  `{:error, :not_configured}` and makes no network call.

  ## The trap

  GraphQL answers **HTTP 200 with an `"errors"` key** when a request fails, and
  `Emakola.HTTPClient.Req` maps every 2xx to `{:ok, body}`. Without the
  explicit check in `request/2`, every Fly failure would read as success and
  the worker's error branch would be unreachable.
  """

  @behaviour Emakola.Infra.FlyCertsBehaviour

  require Logger

  defmodule Status do
    @moduledoc "A certificate's state, in our own vocabulary rather than Fly's."

    @type t :: %__MODULE__{}

    defstruct [
      :hostname,
      :client_status,
      :dns_validation_hostname,
      :dns_validation_target,
      :rate_limited_until,
      configured?: false,
      apex?: false,
      acme_alpn?: false,
      acme_dns?: false,
      acme_http?: false,
      ready?: false,
      validation_errors: []
    ]
  end

  @cert_fields """
  hostname
  clientStatus
  isConfigured
  isApex
  isAcmeAlpnConfigured
  isAcmeDnsConfigured
  isAcmeHttpConfigured
  dnsValidationHostname
  dnsValidationTarget
  rateLimitedUntil
  validationErrors { message }
  """

  # Fly reports this once the certificate is issued and serving.
  @ready_status "Ready"

  @doc "True when a Fly API token is configured and certificates can be issued."
  @spec configured?() :: boolean()
  def configured?, do: is_binary(config(:api_token)) and config(:api_token) != ""

  @impl true
  def add_certificate(hostname) do
    query = """
    mutation($appId: ID!, $hostname: String!) {
      addCertificate(appId: $appId, hostname: $hostname) {
        certificate { #{@cert_fields} }
      }
    }
    """

    with {:ok, data} <- request(query, hostname) do
      {:ok, parse_status(get_in(data, ["addCertificate", "certificate"]))}
    end
  end

  @impl true
  def get_certificate(hostname) do
    query = """
    query($appId: String!, $hostname: String!) {
      app(name: $appId) {
        certificate(hostname: $hostname) { #{@cert_fields} }
      }
    }
    """

    with {:ok, data} <- request(query, hostname) do
      {:ok, parse_status(get_in(data, ["app", "certificate"]))}
    end
  end

  @impl true
  def delete_certificate(hostname) do
    query = """
    mutation($appId: ID!, $hostname: String!) {
      deleteCertificate(appId: $appId, hostname: $hostname) {
        app { name }
      }
    }
    """

    with {:ok, _data} <- request(query, hostname), do: :ok
  end

  defp request(query, hostname) do
    if configured?() do
      body = %{
        query: query,
        variables: %{appId: config(:app_name), hostname: hostname}
      }

      config(:endpoint)
      |> http_client().post(
        json: body,
        headers: [
          {"authorization", "Bearer #{config(:api_token)}"},
          {"content-type", "application/json"}
        ],
        receive_timeout: 15_000
      )
      |> handle_response()
    else
      {:error, :not_configured}
    end
  end

  # A 200 with an "errors" key is a FAILURE. See the moduledoc.
  defp handle_response({:ok, %{"errors" => [_ | _] = errors}}) do
    messages = Enum.map(errors, &Map.get(&1, "message", "unknown error"))
    Logger.warning("[fly_certs] request failed: #{inspect(messages)}")
    {:error, {:fly_error, messages}}
  end

  defp handle_response({:ok, %{"data" => data}}), do: {:ok, data}
  defp handle_response({:ok, other}), do: {:error, {:fly_unexpected_response, other}}
  defp handle_response({:error, reason}), do: {:error, reason}

  defp parse_status(nil), do: nil

  defp parse_status(cert) do
    %Status{
      hostname: cert["hostname"],
      client_status: cert["clientStatus"],
      configured?: cert["isConfigured"] == true,
      apex?: cert["isApex"] == true,
      acme_alpn?: cert["isAcmeAlpnConfigured"] == true,
      acme_dns?: cert["isAcmeDnsConfigured"] == true,
      acme_http?: cert["isAcmeHttpConfigured"] == true,
      ready?: cert["clientStatus"] == @ready_status,
      dns_validation_hostname: cert["dnsValidationHostname"],
      dns_validation_target: cert["dnsValidationTarget"],
      rate_limited_until: cert["rateLimitedUntil"],
      validation_errors: parse_errors(cert["validationErrors"])
    }
  end

  defp parse_errors(nil), do: []
  defp parse_errors(errors), do: Enum.map(errors, &Map.get(&1, "message", "unknown error"))

  defp config(key) do
    :emakola
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default(key))
  end

  defp default(:app_name), do: "emakola"
  defp default(:endpoint), do: "https://api.fly.io/graphql"
  defp default(_), do: nil

  defp http_client, do: Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
end
