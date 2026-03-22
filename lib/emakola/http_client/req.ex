defmodule Emakola.HTTPClient.Req do
  @moduledoc "Req-based HTTP client implementation."
  @behaviour Emakola.HTTPClient

  @impl true
  def post(url, opts \\ []) do
    opts
    |> Keyword.put(:url, url)
    |> Keyword.put(:method, :post)
    |> Req.request()
    |> handle_response()
  end

  @impl true
  def get(url, opts \\ []) do
    opts
    |> Keyword.put(:url, url)
    |> Keyword.put(:method, :get)
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
