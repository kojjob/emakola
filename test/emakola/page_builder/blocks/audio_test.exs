defmodule Emakola.PageBuilder.Blocks.AudioTest do
  use ExUnit.Case, async: true

  alias Emakola.PageBuilder.Blocks.Audio

  test "implements the Block behaviour" do
    assert Audio.type() == "audio"
    assert is_binary(Audio.name())
    assert is_binary(Audio.icon())
    assert is_map(Audio.default_content())
  end

  test "default_content has audio_url, title, subtitle keys" do
    defaults = Audio.default_content()
    assert Map.has_key?(defaults, :audio_url)
    assert Map.has_key?(defaults, :title)
    assert Map.has_key?(defaults, :subtitle)
  end

  test "render returns a HEEx Rendered" do
    assigns = %{
      __changed__: nil,
      content: %{
        audio_url: "/uploads/audio/welcome.mp3",
        title: "Welcome to our store",
        subtitle: "Episode 1 of our podcast"
      },
      store: %{name: "Test", slug: "test"},
      products: [],
      categories: []
    }

    rendered = Audio.render(assigns)

    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
    assert html =~ "<audio"
    assert html =~ "src=\"/uploads/audio/welcome.mp3\""
    assert html =~ "Welcome to our store"
    assert html =~ "Episode 1 of our podcast"
  end

  test "render does NOT emit <audio> when audio_url is missing" do
    assigns = %{
      __changed__: nil,
      content: %{audio_url: nil, title: nil, subtitle: nil},
      store: %{name: "Test", slug: "test"},
      products: [],
      categories: []
    }

    rendered = Audio.render(assigns)
    html = Phoenix.HTML.Safe.to_iodata(rendered) |> IO.iodata_to_binary()
    refute html =~ "<audio"
  end
end
