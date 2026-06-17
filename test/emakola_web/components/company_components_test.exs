defmodule EmakolaWeb.CompanyComponentsTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import EmakolaWeb.CompanyComponents

  test "page_hero renders eyebrow, title, subtitle" do
    html =
      render_component(&page_hero/1, %{
        eyebrow: "Our story",
        title: "Building commerce",
        subtitle: "For West Africa"
      })

    assert html =~ "Our story"
    assert html =~ "Building commerce"
    assert html =~ "For West Africa"
  end

  test "legal_layout renders TOC links and anchored sections from slots" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <EmakolaWeb.CompanyComponents.legal_layout title="Privacy Policy" last_updated="June 15, 2026">
        <:section id="intro" title="Introduction">Hello intro</:section>
        <:section id="data" title="Data we collect">Hello data</:section>
      </EmakolaWeb.CompanyComponents.legal_layout>
      """)

    assert html =~ "Privacy Policy"
    assert html =~ "Last updated"
    assert html =~ "June 15, 2026"
    # TOC anchors
    assert html =~ ~s(href="#intro")
    assert html =~ ~s(href="#data")
    # anchored sections
    assert html =~ ~s(id="intro")
    assert html =~ ~s(id="data")
    assert html =~ "Hello intro"
    assert html =~ "Hello data"
  end
end
