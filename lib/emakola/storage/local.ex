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
end
