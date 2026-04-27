defmodule Emakola.PageBuilder.Blocks.Audio do
  @moduledoc """
  Audio block — embeds a single audio file with native browser controls.
  Used for podcast episodes, voice notes, store-tour narration, etc.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `audio_url` | string \\| nil | nil — direct file URL (mp3/m4a/wav/ogg) |
  | `title` | string \\| nil | nil |
  | `subtitle` | string \\| nil | nil |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  @impl true
  def type, do: "audio"

  @impl true
  def name, do: "Audio"

  @impl true
  def icon, do: "graphic_eq"

  @impl true
  def default_content do
    %{
      audio_url: nil,
      title: nil,
      subtitle: nil
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@content[:audio_url]} class="py-10 sm:py-14">
      <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="bg-stone-50 rounded-2xl p-6 sm:p-8 border border-stone-200">
          <div class="flex items-start gap-4 mb-5">
            <div class="w-14 h-14 rounded-full bg-stone-900 flex items-center justify-center flex-shrink-0">
              <span class="material-symbols-outlined text-white" style="font-size: 28px;">
                graphic_eq
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <p :if={@content[:title]} class="text-base font-semibold text-stone-900 leading-tight">
                {@content[:title]}
              </p>
              <p :if={@content[:subtitle]} class="text-sm text-stone-500 mt-0.5">
                {@content[:subtitle]}
              </p>
            </div>
          </div>
          <audio src={@content[:audio_url]} controls preload="metadata" class="w-full">
            Your browser does not support the audio element.
          </audio>
        </div>
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
end
