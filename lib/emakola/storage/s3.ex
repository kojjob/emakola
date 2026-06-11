defmodule Emakola.Storage.S3 do
  @moduledoc """
  S3-compatible storage implementation.

  Uses ExAws.S3 for upload, delete, and presigned URL generation.
  Configured via application environment:

    config :emakola, :s3_bucket, "my-bucket"
    config :emakola, :s3_region, "eu-west-1"
  """

  @behaviour Emakola.Storage

  @impl true
  def upload(binary, path, opts \\ []) do
    bucket = bucket()
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    acl = Keyword.get(opts, :acl, "public-read")

    case bucket
         |> ExAws.S3.put_object(path, binary,
           content_type: content_type,
           acl: acl
         )
         |> ExAws.request() do
      {:ok, _response} ->
        {:ok, public_url(path)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(path) do
    case bucket()
         |> ExAws.S3.delete_object(path)
         |> ExAws.request() do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presigned_url(path, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)

    config = ExAws.Config.new(:s3, region: region())

    case ExAws.S3.presigned_url(config, :get, bucket(), path, expires_in: expires_in) do
      {:ok, url} -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  defp bucket do
    Application.get_env(:emakola, :s3_bucket, "emakola-uploads")
  end

  defp region do
    Application.get_env(:emakola, :s3_region, "eu-west-1")
  end

  defp public_url(path) do
    # When a custom endpoint is configured (Tigris, MinIO, etc.), build a
    # virtual-hosted URL against it; otherwise fall back to AWS S3.
    case Application.get_env(:ex_aws, :s3, [])[:host] do
      nil -> "https://#{bucket()}.s3.#{region()}.amazonaws.com/#{path}"
      host -> "https://#{bucket()}.#{host}/#{path}"
    end
  end
end
