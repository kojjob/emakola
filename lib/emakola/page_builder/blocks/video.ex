defmodule Emakola.PageBuilder.Blocks.Video do
  @moduledoc """
  Video block — embeds a video from YouTube, Vimeo, or a direct file URL
  (mp4/webm/mov). Renders inside a 16:9 frame with optional caption.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `video_url` | string \\| nil | nil — accepts YouTube watch/embed/share URL, Vimeo URL, or direct file URL |
  | `poster_url` | string \\| nil | nil — used as preview frame for direct-file videos |
  | `caption` | string \\| nil | nil |

  YouTube and Vimeo URLs are converted to player embed URLs at render time.
  Anything starting with `http(s)://` (or `/`) and not matching either platform
  is treated as a direct file URL and rendered with the native `<video>` tag.
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  alias Emakola.PageBuilder.SafeUrl

  @impl true
  def type, do: "video"

  @impl true
  def name, do: "Video"

  @impl true
  def icon, do: "videocam"

  @impl true
  def default_content do
    %{
      video_url: nil,
      poster_url: nil,
      caption: nil
    }
  end

  @impl true
  def render(assigns) do
    embed = video_embed(assigns.content[:video_url])
    assigns = assign(assigns, :embed, embed)

    ~H"""
    <section :if={@embed != :invalid} class="py-10 sm:py-14">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <figure>
          <div class="relative aspect-video rounded-2xl overflow-hidden bg-stone-900">
            <%= case @embed do %>
              <% {:youtube, embed_url} -> %>
                <iframe
                  src={embed_url}
                  title={@content[:caption] || "Video"}
                  class="absolute inset-0 w-full h-full"
                  frameborder="0"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowfullscreen
                >
                </iframe>
              <% {:vimeo, embed_url} -> %>
                <iframe
                  src={embed_url}
                  title={@content[:caption] || "Video"}
                  class="absolute inset-0 w-full h-full"
                  frameborder="0"
                  allow="autoplay; fullscreen; picture-in-picture"
                  allowfullscreen
                >
                </iframe>
              <% {:file, file_url} -> %>
                <video
                  src={file_url}
                  poster={SafeUrl.safe_url(@content[:poster_url])}
                  controls
                  preload="metadata"
                  class="absolute inset-0 w-full h-full object-contain"
                >
                </video>
              <% _ -> %>
            <% end %>
          </div>
          <figcaption
            :if={@content[:caption]}
            class="text-sm text-stone-500 mt-3 italic text-center"
          >
            {@content[:caption]}
          </figcaption>
        </figure>
      </div>
    </section>
    """
  end

  @impl true
  def edit_form(assigns) do
    ~H"""
    <p class="text-sm text-[#78716C]">
      Edit form coming with the page editor LiveView.
    </p>
    """
  end

  @doc """
  Recognises a video URL and returns either:
  - `{:youtube, embed_url}` for any YouTube URL
  - `{:vimeo, embed_url}` for any Vimeo URL
  - `{:file, url}` for direct http(s)/site-relative file URLs per `SafeUrl`
  - `:invalid` for nil, blank, or unrecognised input
  """
  def video_embed(nil), do: :invalid
  def video_embed(""), do: :invalid

  def video_embed(url) when is_binary(url) do
    cond do
      youtube_id = extract_youtube_id(url) ->
        {:youtube, "https://www.youtube.com/embed/#{youtube_id}"}

      vimeo_id = extract_vimeo_id(url) ->
        {:vimeo, "https://player.vimeo.com/video/#{vimeo_id}"}

      safe = SafeUrl.safe_url(url) ->
        {:file, safe}

      true ->
        :invalid
    end
  end

  defp extract_youtube_id(url) do
    cond do
      match = Regex.run(~r{youtube\.com/watch\?v=([\w-]+)}, url) -> Enum.at(match, 1)
      match = Regex.run(~r{youtu\.be/([\w-]+)}, url) -> Enum.at(match, 1)
      match = Regex.run(~r{youtube\.com/embed/([\w-]+)}, url) -> Enum.at(match, 1)
      true -> nil
    end
  end

  defp extract_vimeo_id(url) do
    case Regex.run(~r{vimeo\.com/(\d+)}, url) do
      [_, id] -> id
      _ -> nil
    end
  end
end
