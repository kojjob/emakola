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

  @doc "Copy a trusted object already owned by this storage backend to a new path."
  @callback replicate(source_url :: String.t(), path :: String.t(), opts :: upload_opts()) ::
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
  def replicate(source_url, path, opts \\ []), do: impl().replicate(source_url, path, opts)
  def delete(path), do: impl().delete(path)
  def presigned_url(path, opts \\ []), do: impl().presigned_url(path, opts)

  @doc """
  Whether a URL points at media this platform serves or stores: a local
  upload path (`Local` adapter), a bundled static asset, or an object on
  the configured S3 public host. Render-side gates (theme hero sections)
  use this to keep arbitrary remote URLs out of `src` positions.
  """
  @spec trusted_media_url?(term()) :: boolean()
  def trusted_media_url?(url) when is_binary(url) do
    String.starts_with?(url, "/uploads/") or
      String.starts_with?(url, "/images/") or
      String.starts_with?(url, Emakola.Storage.S3.public_base_url())
  end

  def trusted_media_url?(_url), do: false
end
