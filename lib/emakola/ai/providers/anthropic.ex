defmodule Emakola.AI.Providers.Anthropic do
  @moduledoc """
  Anthropic Claude implementation of `Emakola.AI.Provider`.

  Calls the Anthropic Messages API through the injectable `:http_client`
  (`Emakola.HTTPClient.Req` in prod, `HTTPClientMock` in test) and returns a
  neutral `Emakola.AI.Response`, **capturing the API's `usage` block** (input /
  output tokens) so callers can track cost. Translates the request's neutral
  content blocks (string text or `%{type: :image|:text}` vision blocks) into
  Anthropic's wire shape, and decodes the first JSON object when
  `response_format: :json` was requested.

  Ships dark: no `:anthropic_api_key` → `{:error, :not_configured}`, no spend.
  """

  @behaviour Emakola.AI.Provider

  alias Emakola.AI.{Request, Response}

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"

  @impl true
  def complete(%Request{} = request) do
    case api_key() do
      nil ->
        {:error, :not_configured}

      key ->
        headers = [
          {"x-api-key", key},
          {"anthropic-version", @api_version},
          {"content-type", "application/json"}
        ]

        case http_client().post(@api_url,
               json: build_body(request),
               headers: headers,
               receive_timeout: 60_000
             ) do
          {:ok, %{"content" => content} = raw} ->
            text = extract_text(content)

            {:ok,
             %Response{
               text: text,
               parsed: maybe_parse(request.response_format, text),
               model: raw["model"] || request.model,
               usage: extract_usage(raw["usage"]),
               raw: raw
             }}

          {:ok, other} ->
            {:error, {:unexpected_response, other}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # -- request --

  defp build_body(%Request{} = request) do
    body = %{
      model: request.model,
      max_tokens: request.max_tokens,
      messages: Enum.map(request.messages, &translate_message/1)
    }

    if request.system, do: Map.put(body, :system, request.system), else: body
  end

  defp translate_message(%{role: role, content: content}) do
    %{role: to_string(role), content: translate_content(content)}
  end

  defp translate_content(content) when is_binary(content), do: content
  defp translate_content(blocks) when is_list(blocks), do: Enum.map(blocks, &translate_block/1)

  defp translate_block(%{type: :text, text: text}), do: %{type: "text", text: text}

  defp translate_block(%{type: :image, url: url}),
    do: %{type: "image", source: %{type: "url", url: url}}

  # -- response --

  defp extract_text(content) when is_list(content) do
    case Enum.find_value(content, fn
           %{"type" => "text", "text" => text} -> text
           %{"text" => text} -> text
           _ -> nil
         end) do
      nil -> nil
      text -> String.trim(text)
    end
  end

  defp extract_text(_), do: nil

  # Models sometimes wrap JSON in prose or code fences; extract the first object.
  defp maybe_parse(:json, text) when is_binary(text) do
    with [json] <- Regex.run(~r/\{.*\}/s, text),
         {:ok, map} <- Jason.decode(json) do
      map
    else
      _ -> nil
    end
  end

  defp maybe_parse(_format, _text), do: nil

  defp extract_usage(%{} = usage) do
    %{
      input_tokens: usage["input_tokens"] || 0,
      output_tokens: usage["output_tokens"] || 0,
      cache_read: usage["cache_read_input_tokens"] || 0,
      cache_creation: usage["cache_creation_input_tokens"] || 0
    }
  end

  defp extract_usage(_),
    do: %{input_tokens: 0, output_tokens: 0, cache_read: 0, cache_creation: 0}

  defp http_client, do: Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)
  defp api_key, do: Application.get_env(:emakola, :anthropic_api_key)
end
