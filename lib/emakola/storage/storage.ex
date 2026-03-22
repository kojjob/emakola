defmodule Emakola.Storage do
  @moduledoc """
  Behaviour for file storage operations.

  Implementations:
  - `Emakola.Storage.S3` — production (S3-compatible)
  - `Emakola.Storage.Local` — development (local filesystem)
  - Mox mock — testing

  Configure via:
    config :emakola, :storage, Emakola.Storage.S3
  """

  @type upload_opts :: [content_type: String.t(), acl: String.t()]

  @doc "Upload binary data to the given path. Returns {:ok, public_url} or {:error, reason}."
  @callback upload(binary :: binary(), path :: String.t(), opts :: upload_opts()) ::
              {:ok, String.t()} | {:error, term()}

  @doc "Delete a file at the given path."
  @callback delete(path :: String.t()) :: :ok | {:error, term()}

  @doc "Generate a presigned URL for temporary access."
  @callback presigned_url(path :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @doc "Get the configured storage implementation."
  def impl do
    Application.get_env(:emakola, :storage, Emakola.Storage.S3)
  end

  def upload(binary, path, opts \\ []), do: impl().upload(binary, path, opts)
  def delete(path), do: impl().delete(path)
  def presigned_url(path, opts \\ []), do: impl().presigned_url(path, opts)
end
