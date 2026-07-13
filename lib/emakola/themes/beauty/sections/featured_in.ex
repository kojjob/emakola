defmodule Emakola.Themes.Beauty.Sections.FeaturedIn do
  @moduledoc """
  Beauty "as featured in" press strip — the publications the merchant names.

  It used to repeat the literal words *As featured in* five times, in italics,
  spaced out like a row of press logos. It named no publication and read no
  store data: it was the SHAPE of press coverage with nothing inside it, and a
  shopper skimming the page read it as five magazines. The theme shipped it
  switched off, which made it a trap rather than a feature — a merchant who
  opened the section editor, saw "Featured in" in the list and enabled it got
  fabricated press coverage in one click, with no way to fill it with anything
  true.

  There is no press-mention data model to derive from, and there shouldn't be
  one: a press mention is the merchant's own claim, like the copy on their About
  page. So the strip lists what they type and nothing else. Name no publication
  and there is no strip — an empty press strip is not a design problem to solve
  with placeholders, it is a shop that has not been in the press yet.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  @impl true
  def key, do: "beauty/featured_in"

  @impl true
  def label, do: "Featured in"

  @impl true
  def settings_schema do
    [
      %{
        key: "publications",
        type: :text,
        label: "Publications that featured this shop (one per line, or comma-separated)",
        default: ""
      }
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :publications, publications(assigns[:settings]))

    ~H"""
    <section
      :if={@publications != [] && section_enabled?(@theme, :featured_in)}
      class="bg-[#C9925E]/10 py-8"
      aria-labelledby="beauty-featured-in"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <p
          id="beauty-featured-in"
          class="text-center text-[11px] uppercase tracking-[0.25em] text-[#6B4423]/70 mb-4"
        >
          As featured in
        </p>
        <ul class="flex flex-wrap items-center justify-center gap-x-10 gap-y-4 sm:gap-x-16">
          <li
            :for={publication <- @publications}
            class="beauty-heading text-base sm:text-lg italic text-[#6B4423]"
          >
            {publication}
          </li>
        </ul>
      </div>
    </section>
    """
  end

  # The merchant may separate them by newline or by comma; blanks between the
  # separators are dropped rather than rendered as empty logos.
  defp publications(settings) do
    settings
    |> Kernel.||(%{})
    |> Map.get("publications", "")
    |> to_string()
    |> String.split([",", "\n"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp section_enabled?(theme, name) do
    case get_in(theme, [:sections, name]) do
      false -> false
      _ -> true
    end
  end
end
