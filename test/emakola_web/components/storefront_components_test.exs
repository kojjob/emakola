defmodule EmakolaWeb.StorefrontComponents.OptimizedImageTest do
  @moduledoc """
  Tests for the <.optimized_image> function component.

  Pins the contract for mobile-first image performance:

    * `:auto` priority (default) → lazy + async decode
    * `:high` priority (hero / LCP) → eager + high fetch priority + async decode
    * `:low` priority → lazy + low fetch priority + async decode
    * `width`, `height`, `sizes`, `srcset`, `class` all pass through when set

  Every image must have non-empty `alt` text (enforced by Phoenix at render
  time via the `required: true` attr declaration).
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  import EmakolaWeb.StorefrontComponents

  describe "optimized_image/1 — default (auto priority)" do
    test "lazy loads and async decodes by default" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image src="/img/product.jpg" alt="A beautiful product" />
        """)

      assert html =~ ~s(src="/img/product.jpg")
      assert html =~ ~s(alt="A beautiful product")
      assert html =~ ~s(loading="lazy")
      assert html =~ ~s(decoding="async")
      refute html =~ "fetchpriority"
    end
  end

  describe "optimized_image/1 — priority=:high (LCP)" do
    test "eager loads with high fetch priority" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image src="/img/hero.jpg" alt="Hero image" priority={:high} />
        """)

      assert html =~ ~s(loading="eager")
      assert html =~ ~s(fetchpriority="high")
      assert html =~ ~s(decoding="async")
      refute html =~ ~s(loading="lazy")
    end
  end

  describe "optimized_image/1 — priority=:low (decorative)" do
    test "lazy loads with low fetch priority" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image src="/img/decor.png" alt="Decoration" priority={:low} />
        """)

      assert html =~ ~s(loading="lazy")
      assert html =~ ~s(fetchpriority="low")
      assert html =~ ~s(decoding="async")
    end
  end

  describe "optimized_image/1 — dimensions" do
    test "renders width and height when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image src="/img/logo.svg" alt="Logo" width={120} height={40} />
        """)

      assert html =~ ~s(width="120")
      assert html =~ ~s(height="40")
    end

    test "omits dimensions when not provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image src="/img/x.jpg" alt="X" />
        """)

      refute html =~ ~s(width=")
      refute html =~ ~s(height=")
    end
  end

  describe "optimized_image/1 — responsive srcset" do
    test "renders srcset and sizes when provided" do
      srcset = "/img/x-320.jpg 320w, /img/x-640.jpg 640w, /img/x-1280.jpg 1280w"
      sizes = "(max-width: 640px) 100vw, 50vw"
      assigns = %{srcset: srcset, sizes: sizes}

      html =
        rendered_to_string(~H"""
        <.optimized_image
          src="/img/x-640.jpg"
          alt="Responsive"
          srcset={@srcset}
          sizes={@sizes}
        />
        """)

      assert html =~ ~s(srcset="#{srcset}")
      assert html =~ ~s(sizes="#{sizes}")
    end

    test "omits srcset and sizes when not provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image src="/img/x.jpg" alt="X" />
        """)

      refute html =~ ~s(srcset=")
      refute html =~ ~s(sizes=")
    end
  end

  describe "optimized_image/1 — class pass-through" do
    test "merges custom classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image
          src="/img/x.jpg"
          alt="X"
          class="w-full h-full object-cover rounded-lg"
        />
        """)

      assert html =~ ~s(class="w-full h-full object-cover rounded-lg")
    end
  end

  describe "optimized_image/1 — arbitrary attrs pass through" do
    test "passes id, data-*, and phx-* via :global attr" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.optimized_image
          src="/img/x.jpg"
          alt="X"
          id="hero-1"
          data-test="hero"
          phx-hook="ImageFade"
        />
        """)

      assert html =~ ~s(id="hero-1")
      assert html =~ ~s(data-test="hero")
      assert html =~ ~s(phx-hook="ImageFade")
    end
  end
end
