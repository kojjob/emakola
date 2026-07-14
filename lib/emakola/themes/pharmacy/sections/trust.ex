defmodule Emakola.Themes.Pharmacy.Sections.Trust do
  @moduledoc """
  Pharmacy home trust strip — the merchant's own credentials, or no strip.

  This section used to assert, on every store that installed the Pharmacy theme:
  "Licensed & Trusted / Verified pharmacy. Genuine medicines. Discreet delivery",
  over three tiles reading *Licensed pharmacy*, *Genuine medicines — sourced from
  trusted brands*, *Discreet delivery*. A merchant installed a colour scheme and
  the platform certified them as a licensed pharmacy selling genuine medicine.

  That is not marketing copy. It is a regulatory claim about who the merchant is,
  and a safety claim about what is in the box — the two things a person buying
  medicine online most needs to be able to trust, asserted by software on behalf
  of someone who never said it and could not take it back.

  So there is no default. A pharmacy that IS licensed states it themselves, in
  their own words, and it is their claim to stand behind. A store that has stated
  nothing gets no strip.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias Emakola.Themes.Item
  alias Emakola.Themes.Pharmacy.Shared

  @impl true
  def key, do: "pharmacy/trust"

  @impl true
  def label, do: "Trust"

  @impl true
  def settings_schema do
    [
      %{key: "title", type: :string, label: "Heading", default: ""},
      %{
        key: "subtitle",
        type: :text,
        label: "Your own credentials — licence number, registration, what you stock",
        default: ""
      }
    ]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:title, setting(assigns, "title") || get_in(assigns.theme, [:trust, :title]))
      |> assign(
        :subtitle,
        setting(assigns, "subtitle") || get_in(assigns.theme, [:trust, :subtitle])
      )
      |> assign(:items, trust_items(assigns.theme))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :trust) && stated?(@title, @subtitle, @items)}
      class="bg-white py-14 sm:py-20"
      aria-labelledby="pharmacy-trust"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class="text-center mb-10">
          <h2
            id="pharmacy-trust"
            class="pharmacy-heading text-3xl sm:text-4xl font-medium text-[#14543E]"
          >
            {@title || "Why shop with us"}
          </h2>
          <p :if={@subtitle} class="text-sm text-[#4B5563] mt-3 max-w-xl mx-auto">
            {@subtitle}
          </p>
        </div>
        <div :if={@items != []} class="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div :for={item <- @items} class="flex flex-col items-center text-center px-6 py-8">
            <div class="w-16 h-16 rounded-full bg-[#A7E5C5] flex items-center justify-center mb-5">
              <span class="material-symbols-outlined text-[#14543E]" style="font-size: 30px;">
                {Item.field(item, :icon, "check_circle")}
              </span>
            </div>
            <p class="text-base font-semibold text-[#14543E] mb-1">{Item.field(item, :label)}</p>
            <p :if={Item.field(item, :subtitle)} class="text-sm text-[#4B5563]">
              {Item.field(item, :subtitle)}
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # The strip exists once the merchant has put ANYTHING in it — a heading of
  # their own is already a claim they chose to make ("Regulated and registered").
  # A store that has written none of the three gets no strip.
  defp stated?(title, subtitle, items) do
    title not in [nil, ""] or subtitle not in [nil, ""] or items != []
  end

  defp setting(assigns, key) do
    case get_in(assigns, [Access.key(:settings, %{}), key]) do
      value when value in [nil, ""] -> nil
      value -> value
    end
  end

  defp trust_items(theme) do
    case get_in(theme, [:trust, :items]) do
      items when is_list(items) -> Enum.filter(items, &Item.has?(&1, :label))
      _ -> []
    end
  end
end
