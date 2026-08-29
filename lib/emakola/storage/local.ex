defmodule Emakola.Storage.Local do
  @moduledoc """
  Local filesystem storage for development. Writes to priv/static/uploads/.
  """

  @behaviour Emakola.Storage

  @upload_dir "priv/static/uploads"

  @impl true
  def upload(binary, path, _opts \\ []) do
    dest = Path.join(@upload_dir, path)
    dest |> Path.dirname() |> File.mkdir_p!()
    File.write!(dest, binary)
    {:ok, "/uploads/#{path}"}
  end

  @impl true
  def replicate("/uploads/" <> source_path, destination_path, opts) do
    with :ok <- validate_path(source_path),
         {:ok, binary} <- File.read(Path.join(@upload_dir, source_path)) do
      upload(binary, destination_path, opts)
    end
  end

  def replicate(_source_url, _destination_path, _opts), do: {:error, :untrusted_source_url}

  @impl true
  def object_key("/uploads/" <> path) do
    case validate_path(path) do
      :ok -> {:ok, path}
      error -> error
    end
  end

  def object_key(_url), do: {:error, :untrusted_source_url}

  @impl true
  def get(path) do
    with :ok <- validate_path(path) do
      File.read(Path.join(@upload_dir, path))
    end
  end

  @impl true
  def delete(path) do
    dest = Path.join(@upload_dir, path)

    case File.rm(dest) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presigned_url(path, _opts \\ []) do
    {:ok, "/uploads/#{path}"}
  end

  defp validate_path(path) do
    if path != "" and Path.type(path) == :relative and ".." not in Path.split(path),
      do: :ok,
      else: {:error, :untrusted_source_url}
  end
end
