defmodule Emakola.PageBuilder.Blocks.SplitTest do
  use ExUnit.Case, async: true

  alias Emakola.PageBuilder.Blocks.Split

  test "implements the Block behaviour" do
    assert Split.type() == "split"
    assert is_binary(Split.name())
    assert is_binary(Split.icon())
    assert is_map(Split.default_content())
  end

  test "default_content has all expected keys" do
    defaults = Split.default_content()

    for key <- [:image_url, :image_position, :heading, :body, :cta_label, :cta_url] do
      assert Map.has_key?(defaults, key)
    end
  end

  test "render shows heading + paragraphs + CTA" do
    assigns = %{
      __changed__: nil,
      content: %{
        image_url: "/uploads/img.jpg",
        image_position: "left",
        heading: "Our Story",
        body: "Paragraph one.\n\nParagraph two.",
        cta_label: "Read more",
        cta_url: "/about"
      },
      store: %{name: "Test", slug: "test"},
      products: [],
      categories: []
    }

    rendered = Split.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

    assert html =~ "Our Story"
    assert html =~ "Paragraph one."
    assert html =~ "Paragraph two."
    assert html =~ "Read more"
    assert html =~ "/about"
  end

  test "render falls back to gradient when no image_url" do
    assigns = %{
      __changed__: nil,
      content: %{
        image_url: nil,
        image_position: "left",
        heading: "No image",
        body: nil,
        cta_label: nil,
        cta_url: nil
      },
      store: %{name: "Test", slug: "test"},
      products: [],
      categories: []
    }

    rendered = Split.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

    refute html =~ "<img"
    assert html =~ "bg-gradient-to-br"
  end
end
