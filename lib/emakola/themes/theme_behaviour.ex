defmodule Emakola.Themes.ThemeBehaviour do
  @moduledoc """
  Behaviour that all storefront themes must implement.

  Each theme provides its identity, default styling configuration,
  font declarations, and render callbacks for the three core pages.
  """

  @doc "Unique theme identifier string (e.g. \"market\", \"atelier\")"
  @callback id() :: String.t()

  @doc "Human-readable theme name"
  @callback name() :: String.t()

  @doc """
  Default theme configuration map with atom keys:
    %{
      colors: %{primary: "#hex", secondary: "#hex", accent: "#hex", background: "#hex", text: "#hex"},
      hero: %{title: string, subtitle: string},
      sections: %{show_featured: boolean, show_categories: boolean, show_about: boolean}
    }
  """
  @callback defaults() :: map()

  @doc """
  Font declarations for the theme. Returns a map:
    %{heading: "Font Name", body: "Font Name", url: "Google Fonts URL"}
  """
  @callback fonts() :: map()

  @doc "Renders the store home page. Receives assigns map."
  @callback render_home(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Renders the product listing page. Receives assigns map."
  @callback render_product_list(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc "Renders the product detail page. Receives assigns map."
  @callback render_product_detail(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
end
