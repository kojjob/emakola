defmodule Emakola.Themes.NoDeadFormsTest do
  @moduledoc """
  A control that looks like it works must work.

  Six themes shipped a newsletter form that captured nothing: no
  `phx-submit`, no `name` on the input. A shopper typed their email, pressed
  Subscribe, watched the page do something, and was never subscribed to
  anything. The merchant grew a mailing list of nobody.

  This walks EVERY sectionized theme rather than the six that were broken,
  because the next theme is the one that will get it wrong.
  """
  use Emakola.DataCase, async: false

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias Emakola.Themes.Sections

  @store %{
    id: "00000000-0000-0000-0000-000000000000",
    slug: "shop",
    name: "Shop",
    currency: "GHS",
    description: nil,
    whatsapp_number: nil,
    theme_config: %{}
  }

  defp newsletter_sections do
    for theme <- Sections.sectionized_themes(),
        section <- theme.sections(),
        String.ends_with?(section.key(), "/newsletter"),
        do: {theme, section}
  end

  defp render(theme, section) do
    settings =
      for setting <- section.settings_schema(), into: %{}, do: {setting.key, setting.default}

    %{
      store: @store,
      theme: theme.defaults(),
      settings: settings,
      products: [],
      categories: [],
      testimonials: [],
      cart_count: 0,
      __changed__: nil
    }
    |> section.render()
    |> rendered_to_string()
  end

  test "every theme's newsletter form actually subscribes someone" do
    sections = newsletter_sections()

    # If this ever finds nothing, the walk broke — not the themes.
    assert length(sections) >= 10

    dead =
      for {theme, section} <- sections,
          html = render(theme, section),
          # A form that is rendered at all must be wired to the real handler.
          String.contains?(html, "<form"),
          not (String.contains?(html, ~s(phx-submit="subscribe_newsletter")) and
                 String.contains?(html, ~s(name="email"))),
          do: section.key()

    assert dead == [],
           """
           These newsletter forms capture nothing — a shopper can type an email,
           press Subscribe, and never be subscribed:

               #{Enum.join(dead, "\n    ")}

           A form must carry phx-submit="subscribe_newsletter" (the global hook
           in EmakolaWeb.Hooks.NewsletterSubscription) and an input named
           "email", which is what that handler reads.
           """
  end
end
