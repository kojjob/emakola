defmodule Emakola.Themes.DesignTokens do
  @moduledoc """
  Maps design token names to Tailwind CSS classes.

  Merchants pick visual options (e.g., "pill" buttons, "bordered" cards)
  and this module resolves them to the correct Tailwind classes.
  Pure functions — no runtime overhead, pattern matching is compile-time optimized.
  """

  @default_tokens %{
    button_style: "rounded",
    card_style: "shadow",
    navbar_layout: "left",
    product_grid_columns: 3,
    hero_layout: "full-bleed",
    footer_style: "columns",
    product_card_style: "card",
    typography_scale: "default",
    heading_font: "sans",
    body_font: "sans"
  }

  @doc "Returns the default design tokens map."
  def defaults, do: @default_tokens

  @doc "Merges merchant overrides into defaults, ignoring unknown keys."
  def resolve(nil), do: @default_tokens

  def resolve(tokens) when is_map(tokens) do
    Enum.reduce(tokens, @default_tokens, fn {key, value}, acc ->
      atom_key =
        cond do
          is_atom(key) -> key
          is_binary(key) -> safe_to_atom(key)
          true -> nil
        end

      if atom_key && Map.has_key?(acc, atom_key) && value != "" do
        Map.put(acc, atom_key, value)
      else
        acc
      end
    end)
  end

  # -- Button Styles --

  @doc "Returns Tailwind classes for the button shape variant."
  def button_classes("pill"), do: "rounded-full"
  def button_classes("square"), do: "rounded-none"
  def button_classes("rounded"), do: "rounded-lg"
  def button_classes(_), do: "rounded-lg"

  # -- Card Styles --

  @doc "Returns Tailwind classes for the card variant."
  def card_classes("minimal"), do: "bg-white"
  def card_classes("shadow"), do: "bg-white shadow-md rounded-xl"
  def card_classes("bordered"), do: "bg-white border border-gray-200 rounded-xl"
  def card_classes(_), do: "bg-white shadow-md rounded-xl"

  # -- Navbar Layout --

  @doc "Returns Tailwind classes for navbar layout."
  def navbar_classes("centered"), do: "justify-center"
  def navbar_classes("left"), do: "justify-start"
  def navbar_classes("hamburger"), do: "justify-between"
  def navbar_classes(_), do: "justify-start"

  # -- Product Grid --

  @doc "Returns Tailwind grid classes for product columns."
  def grid_classes(2), do: "grid-cols-1 sm:grid-cols-2"
  def grid_classes(3), do: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
  def grid_classes(4), do: "grid-cols-2 sm:grid-cols-3 lg:grid-cols-4"
  def grid_classes("2"), do: grid_classes(2)
  def grid_classes("3"), do: grid_classes(3)
  def grid_classes("4"), do: grid_classes(4)
  def grid_classes(_), do: grid_classes(3)

  # -- Hero Layout --

  @doc "Returns the hero layout variant identifier."
  def hero_layout("full-bleed"), do: :full_bleed
  def hero_layout("split"), do: :split
  def hero_layout("video"), do: :video
  def hero_layout(_), do: :full_bleed

  # -- Footer Style --

  @doc "Returns the footer style variant identifier."
  def footer_style("minimal"), do: :minimal
  def footer_style("columns"), do: :columns
  def footer_style("mega"), do: :mega
  def footer_style(_), do: :columns

  # -- Product Card Style --

  @doc "Returns the product card variant identifier."
  def product_card_style("card"), do: :card
  def product_card_style("list"), do: :list
  def product_card_style("magazine"), do: :magazine
  def product_card_style(_), do: :card

  # -- Typography Scale --

  @doc "Returns font size classes for the typography scale."
  def heading_size("compact"), do: "text-xl sm:text-2xl"
  def heading_size("default"), do: "text-2xl sm:text-3xl"
  def heading_size("spacious"), do: "text-3xl sm:text-4xl lg:text-5xl"
  def heading_size(_), do: heading_size("default")

  def body_size("compact"), do: "text-sm leading-relaxed"
  def body_size("default"), do: "text-base leading-relaxed"
  def body_size("spacious"), do: "text-lg leading-loose"
  def body_size(_), do: body_size("default")

  # -- Font Families --

  @doc "Returns the CSS font-family string for headings."
  def heading_font_family("serif"), do: "'Cormorant', Georgia, serif"
  def heading_font_family("display"), do: "'Playfair Display', Georgia, serif"
  def heading_font_family("sans"), do: "inherit"
  def heading_font_family(_), do: "inherit"

  @doc "Returns the CSS font-family string for body text."
  def body_font_family("serif"), do: "'Lora', Georgia, serif"
  def body_font_family("sans"), do: "inherit"
  def body_font_family(_), do: "inherit"

  @doc "Returns Google Fonts URL for the heading font, or nil if system font."
  def heading_font_url("serif"),
    do: "https://fonts.googleapis.com/css2?family=Cormorant:wght@400;500;600;700&display=swap"

  def heading_font_url("display"),
    do:
      "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;500;600;700&display=swap"

  def heading_font_url(_), do: nil

  @doc "Returns Google Fonts URL for the body font, or nil if system font."
  def body_font_url("serif"),
    do: "https://fonts.googleapis.com/css2?family=Lora:wght@400;500;600;700&display=swap"

  def body_font_url(_), do: nil

  # -- All available options (for admin UI) --

  @doc "Returns all available options for each design token."
  def options do
    %{
      button_style: [
        %{value: "rounded", label: "Rounded", icon: "rounded_corner"},
        %{value: "square", label: "Square", icon: "crop_square"},
        %{value: "pill", label: "Pill", icon: "circle"}
      ],
      card_style: [
        %{value: "minimal", label: "Clean", icon: "crop_portrait"},
        %{value: "shadow", label: "Shadow", icon: "layers"},
        %{value: "bordered", label: "Bordered", icon: "check_box_outline_blank"}
      ],
      navbar_layout: [
        %{value: "left", label: "Left", icon: "format_align_left"},
        %{value: "centered", label: "Centered", icon: "format_align_center"},
        %{value: "hamburger", label: "Burger", icon: "menu"}
      ],
      product_grid_columns: [
        %{value: 2, label: "2 Columns", icon: "grid_view"},
        %{value: 3, label: "3 Columns", icon: "grid_on"},
        %{value: 4, label: "4 Columns", icon: "apps"}
      ],
      hero_layout: [
        %{value: "full-bleed", label: "Full Bleed", icon: "panorama"},
        %{value: "split", label: "Split", icon: "vertical_split"},
        %{value: "video", label: "Video", icon: "play_circle"}
      ],
      footer_style: [
        %{value: "minimal", label: "Minimal", icon: "minimize"},
        %{value: "columns", label: "Columns", icon: "view_column"},
        %{value: "mega", label: "Mega", icon: "dashboard"}
      ],
      product_card_style: [
        %{value: "card", label: "Card", icon: "view_module"},
        %{value: "list", label: "List", icon: "view_list"},
        %{value: "magazine", label: "Magazine", icon: "article"}
      ],
      typography_scale: [
        %{value: "compact", label: "Compact", icon: "density_small"},
        %{value: "default", label: "Default", icon: "density_medium"},
        %{value: "spacious", label: "Spacious", icon: "density_large"}
      ],
      heading_font: [
        %{value: "sans", label: "Sans Serif", icon: "title", preview: "Aa"},
        %{value: "serif", label: "Serif", icon: "format_size", preview: "Aa"},
        %{value: "display", label: "Display", icon: "text_format", preview: "Aa"}
      ],
      body_font: [
        %{value: "sans", label: "Sans Serif", icon: "notes", preview: "Aa Bb Cc"},
        %{value: "serif", label: "Serif", icon: "format_size", preview: "Aa Bb Cc"}
      ]
    }
  end

  defp safe_to_atom(key) when is_atom(key), do: key

  defp safe_to_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end
end
