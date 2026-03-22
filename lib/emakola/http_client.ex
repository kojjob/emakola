defmodule Emakola.HTTPClient do
  @moduledoc "Behaviour for HTTP client, allowing mock injection in tests."

  @callback post(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
end
