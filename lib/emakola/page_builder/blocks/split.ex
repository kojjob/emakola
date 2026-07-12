defmodule Emakola.PageBuilder.Blocks.Split do
  @moduledoc """
  Image + text split block. Two-column on desktop (image one side,
  copy + CTA on the other), stacks on mobile.

  ## Content fields

  | Field | Type | Default |
  |---|---|---|
  | `image_url` | string \\| nil | nil — falls back to gradient placeholder |
  | `image_position` | "left" \\| "right" | "left" |
  | `heading` | string | "Heading" |
  | `body` | string \\| nil | nil — split into paragraphs on blank lines |
  | `cta_label` | string \\| nil | nil |
  | `cta_url` | string \\| nil | nil |
  """

  @behaviour Emakola.PageBuilder.Block

  use Phoenix.Component

  alias Emakola.PageBuilder.SafeUrl

  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  @impl true
  def type, do: "split"

  @impl true
  def name, do: "Image + text"

  @impl true
  def icon, do: "vertical_split"

  @impl true
  def default_content do
    %{
      image_url: nil,
      image_position: "left",
      heading: "Heading",
      body: nil,
      cta_label: nil,
      cta_url: nil
    }
  end

  @impl true
  def render(assigns) do
    paragraphs =
      case assigns.content[:body] do
        body when is_binary(body) and body != "" ->
          String.split(body, ~r/\n\s*\n/, trim: true)

        _ ->
          []
      end

    assigns = assign(assigns, :paragraphs, paragraphs)

    ~H"""
    <section class="py-12 sm:py-20">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
          <div class={image_order_class(@content[:image_position])}>
            <%= if @content[:image_url] do %>
              <.optimized_image
                src={SafeUrl.safe_url(@content[:image_url])}
                alt={@content[:heading] || ""}
                class="w-full aspect-[4/3] object-cover rounded-2xl"
              />
            <% else %>
              <div class="w-full aspect-[4/3] rounded-2xl bg-gradient-to-br from-stone-200 to-stone-300 flex items-center justify-center">
                <span class="material-symbols-outlined text-stone-400" style="font-size: 80px;">
                  image
                </span>
              </div>
            <% end %>
          </div>
          <div class={text_order_class(@content[:image_position])}>
            <h2
              :if={@content[:heading]}
              class="text-3xl sm:text-4xl font-bold text-stone-900 mb-4 leading-tight"
            >
              {@content[:heading]}
            </h2>
            <div
              :if={@paragraphs != []}
              class="text-base text-stone-600 leading-relaxed mb-6 space-y-3"
            >
              <p :for={p <- @paragraphs}>{p}</p>
            </div>
            <a
              :if={@content[:cta_label]}
              href={SafeUrl.safe_url(@content[:cta_url]) || "/products"}
              class="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-stone-900 text-white text-sm font-semibold hover:bg-stone-700 transition-colors"
            >
              {@content[:cta_label]}
              <span class="material-symbols-outlined" style="font-size: 16px;">arrow_forward</span>
            </a>
          </div>
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

  defp image_order_class("right"), do: "order-1 lg:order-2"
  defp image_order_class(_), do: ""

  defp text_order_class("right"), do: "order-2 lg:order-1"
  defp text_order_class(_), do: ""
end
