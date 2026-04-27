defmodule Emakola.PageBuilder.Blocks.FaqTest do
  use ExUnit.Case, async: true

  alias Emakola.PageBuilder.Blocks.Faq

  test "implements the Block behaviour" do
    assert Faq.type() == "faq"
    assert is_binary(Faq.name())
    assert is_binary(Faq.icon())
    assert is_map(Faq.default_content())
  end

  test "render emits <details> for each valid item" do
    assigns = %{
      __changed__: nil,
      content: %{
        heading: "FAQ",
        items: [
          %{"question" => "Do you ship to Ghana?", "answer" => "Yes, all 16 regions."},
          %{"question" => "How long does delivery take?", "answer" => "1-4 business days."}
        ]
      },
      store: %{name: "Test", slug: "test"}
    }

    rendered = Faq.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

    assert html =~ "<details"
    assert html =~ "Do you ship to Ghana?"
    assert html =~ "Yes, all 16 regions."
    assert html =~ "How long does delivery take?"
  end

  test "render filters out items with blank questions" do
    assigns = %{
      __changed__: nil,
      content: %{
        heading: "FAQ",
        items: [
          %{"question" => "Real question?", "answer" => "Real answer."},
          %{"question" => "", "answer" => "Should not appear"},
          %{"question" => "   ", "answer" => "Whitespace-only also filtered"}
        ]
      },
      store: %{name: "Test", slug: "test"}
    }

    rendered = Faq.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()

    assert html =~ "Real question?"
    refute html =~ "Should not appear"
    refute html =~ "Whitespace-only also filtered"
  end

  test "render emits nothing when no valid items" do
    assigns = %{
      __changed__: nil,
      content: %{heading: "FAQ", items: []},
      store: %{name: "Test", slug: "test"}
    }

    rendered = Faq.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
    refute html =~ "<details"
  end
end
