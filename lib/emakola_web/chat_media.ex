defmodule EmakolaWeb.ChatMedia do
  @moduledoc """
  Upload plumbing shared by every chat surface: merchants, staff and buyers
  attach the same way, so the rules live once.

  Accept is an extension list, deliberately: a MIME accept list raises at
  mount for the types iOS Safari records (a shipped bug elsewhere in this
  app), and extensions behave across pickers.
  """

  import Phoenix.LiveView

  require Logger

  @extensions ~w(.jpg .jpeg .png .webp .gif .mp3 .m4a .ogg .wav .aac .mp4 .webm .mov)

  # Videos from a phone camera get big fast; 25 MB holds a short clip while
  # staying survivable on the mobile data most of our users are on.
  @max_file_size 25_000_000

  def allow(socket) do
    allow_upload(socket, :chat_media,
      accept: @extensions,
      max_entries: 4,
      max_file_size: @max_file_size,
      auto_upload: true
    )
  end

  @doc "True when the composer holds files that would ride the next send."
  def pending?(socket) do
    socket.assigns.uploads.chat_media.entries != []
  end

  @doc """
  Moves finished uploads into storage under the thread and returns
  attachment maps in the shape `Conversations.post_message/5` accepts.
  """
  def consume(socket, thread_id) do
    consume_uploaded_entries(socket, :chat_media, fn %{path: path}, entry ->
      filename =
        "#{System.os_time(:millisecond)}_#{entry.client_name}"
        |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")

      storage_path = "chat/#{thread_id}/#{filename}"

      case Emakola.Storage.upload(File.read!(path), storage_path, content_type: entry.client_type) do
        {:ok, url} ->
          {:ok, %{"url" => url, "content_type" => entry.client_type, "name" => entry.client_name}}

        {:error, reason} ->
          Logger.error("[chat_media] upload failed: #{inspect(reason)}")
          {:ok, nil}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
