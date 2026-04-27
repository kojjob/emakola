defmodule Emakola.PageBuilder.Blocks.TestimonialsTest do
  use ExUnit.Case, async: true

  alias Emakola.PageBuilder.Blocks.Testimonials

  test "implements the Block behaviour" do
    assert Testimonials.type() == "testimonials"
    assert is_binary(Testimonials.name())
    assert is_binary(Testimonials.icon())
    assert is_map(Testimonials.default_content())
  end

  test "render emits each valid testimonial with name + quote" do
    assigns = %{
      __changed__: nil,
      content: %{
        heading: "Loved by our community",
        items: [
          %{"name" => "Akua M.", "location" => "Accra", "quote" => "Best store in Ghana"},
          %{"name" => "Nana A.", "location" => "Kumasi", "quote" => "Five stars"}
        ]
      },
      store: %{name: "Test", slug: "test"}
    }

    rendered = Testimonials.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

    assert html =~ "Loved by our community"
    assert html =~ "Akua M."
    assert html =~ "Accra"
    assert html =~ "Best store in Ghana"
    assert html =~ "Nana A."
  end

  test "render filters out testimonials missing name OR quote" do
    assigns = %{
      __changed__: nil,
      content: %{
        heading: "Reviews",
        items: [
          %{"name" => "Real", "location" => "Tema", "quote" => "Real review"},
          %{"name" => "", "location" => "Accra", "quote" => "No name"},
          %{"name" => "No quote", "location" => "Accra", "quote" => ""}
        ]
      },
      store: %{name: "Test", slug: "test"}
    }

    rendered = Testimonials.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

    assert html =~ "Real review"
    refute html =~ "No name"
    refute html =~ "No quote"
  end
end
