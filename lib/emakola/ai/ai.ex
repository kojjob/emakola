defmodule Emakola.AI do
  @moduledoc """
  The AI domain and service facade — the single entry point for every AI feature.

  Features call `generate/3` and never touch HTTP, models, or prompts directly.
  The facade builds the request from `Emakola.AI.Prompts`, dispatches to the
  configured `Emakola.AI.Provider`, then records an `Emakola.AI.Usage` row (tokens
  + cost + status) for every attempt — success, error, or ship-dark.

  Rate limiting stays a caller concern (workers/features use
  `Emakola.Content.RateLimiter` as they do today) so this layer has one job:
  generate and account.

      Emakola.AI.generate(:product_description, %{product: p, store: s}, store: s)
      #=> {:ok, %Emakola.AI.Response{text: "...", usage: %{...}}}
  """

  use Ash.Domain

  require Logger

  alias Emakola.AI.{Pricing, Prompts, Request, Response, Sanitizer}

  resources do
    resource Emakola.AI.Usage do
      define(:record_usage, action: :create)
      define(:usage_for_store, action: :usage_for_store, args: [:store_id])
    end
  end

  @doc """
  Generate AI content for `feature` from `inputs`.

  Options: `:store` (a store struct/map — its `id` scopes the usage record),
  `:store_id`, and `:actor_id`. Returns `{:ok, %Emakola.AI.Response{}}` or
  `{:error, reason}` (`:not_configured` when ship-dark). A usage row is recorded
  either way; usage logging never breaks the generation.
  """
  @spec generate(atom(), map(), keyword()) :: {:ok, Response.t()} | {:error, term()}
  def generate(feature, inputs, opts \\ []) do
    request = build_request(feature, inputs, opts)
    {elapsed_us, result} = :timer.tc(fn -> provider().complete(request) end)
    finalize(request, result, div(elapsed_us, 1000))
  end

  defp build_request(feature, inputs, opts) do
    base = Prompts.build(feature, inputs)
    %{base | feature: feature, store_id: resolve_store_id(opts), actor_id: opts[:actor_id]}
  end

  defp resolve_store_id(opts) do
    cond do
      opts[:store_id] -> opts[:store_id]
      store = opts[:store] -> Map.get(store, :id) || Map.get(store, "id")
      true -> nil
    end
  end

  defp finalize(%Request{} = request, {:ok, %Response{} = response}, latency_ms) do
    response = Sanitizer.clean(response)
    cost = Pricing.cost_microusd(request.model, response.usage)
    record(request, :success, response, latency_ms, cost, nil)
    {:ok, response}
  end

  defp finalize(%Request{} = request, {:error, :not_configured} = error, latency_ms) do
    record(request, :not_configured, nil, latency_ms, 0, "not_configured")
    error
  end

  defp finalize(%Request{} = request, {:error, reason} = error, latency_ms) do
    record(request, :error, nil, latency_ms, 0, truncate(inspect(reason)))
    error
  end

  defp record(%Request{} = request, status, response, latency_ms, cost, error) do
    usage = (response && response.usage) || %{}

    %{
      store_id: request.store_id,
      feature: to_string(request.feature),
      provider: provider_name(),
      model: (response && response.model) || request.model,
      input_tokens: Map.get(usage, :input_tokens, 0),
      output_tokens: Map.get(usage, :output_tokens, 0),
      cost_microusd: cost,
      status: status,
      latency_ms: latency_ms,
      actor_id: request.actor_id,
      error: error
    }
    |> record_usage(authorize?: false)

    :ok
  rescue
    exception ->
      Logger.warning("AI usage logging failed: #{Exception.message(exception)}")
      :ok
  end

  defp provider, do: Application.get_env(:emakola, :ai_provider, Emakola.AI.Providers.Anthropic)

  defp provider_name do
    case provider() do
      Emakola.AI.Providers.Anthropic -> "anthropic"
      other -> other |> Module.split() |> List.last() |> Macro.underscore()
    end
  end

  defp truncate(string), do: String.slice(string, 0, 1000)
end
