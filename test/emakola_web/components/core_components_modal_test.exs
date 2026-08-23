defmodule EmakolaWeb.CoreComponentsModalTest do
  @moduledoc """
  Tests for the modal and confirm_modal components in CoreComponents.
  Verifies that modal markup, attributes, and JS commands render correctly.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias EmakolaWeb.CoreComponents

  describe "modal/1" do
    test "renders centered modal with required attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="test-modal" title="Test Title">
          <p>Modal content</p>
        </CoreComponents.modal>
        """)

      assert html =~ "test-modal"
      assert html =~ "Test Title"
      assert html =~ "Modal content"
      assert html =~ "role=\"dialog\""
      assert html =~ "aria-modal=\"true\""
    end

    # Sizes come from the approved modal canvas. Every step is bigger than
    # it was: a dialog that asks a merchant to destroy an order should not
    # be a 448px slip of paper.
    test "the header icon sits in a tinted tile, not a bare glyph" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="iconed" title="Cancel this order?" icon="hero-exclamation-triangle">
          <p>Content</p>
        </CoreComponents.modal>
        """)

      assert html =~ "hero-exclamation-triangle"
      # The tile, not a loose 20px symbol beside the title.
      assert html =~ "rounded-control"
      refute html =~ "material-symbols-outlined"
    end

    test "renders modal with different sizes" do
      for {size, expected_class} <- [
            {:sm, "max-w-lg"},
            {:md, "max-w-2xl"},
            {:lg, "max-w-[860px]"},
            {:xl, "max-w-[1240px]"}
          ] do
        assigns = %{size: size}

        html =
          rendered_to_string(~H"""
          <CoreComponents.modal id={"modal-#{@size}"} title="Sized Modal" size={@size}>
            <p>Content</p>
          </CoreComponents.modal>
          """)

        assert html =~ expected_class, "Expected #{expected_class} for size #{size}"
      end
    end

    test "renders slide-over modal" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="slide-modal" title="Slide Over" kind={:slide_over}>
          <p>Slide content</p>
        </CoreComponents.modal>
        """)

      assert html =~ "slide-modal"
      assert html =~ "Slide Over"
      assert html =~ "Slide content"
      assert html =~ "max-w-[480px]"
      assert html =~ "flex justify-end"
    end

    test "renders close button with accessibility label" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="close-test" title="Close Test">
          <p>Content</p>
        </CoreComponents.modal>
        """)

      assert html =~ "aria-label"
      assert html =~ "hero-x-mark"
    end

    test "renders footer slot when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="footer-test" title="Footer Test">
          <p>Body</p>
          <:footer>
            <button>Save</button>
          </:footer>
        </CoreComponents.modal>
        """)

      assert html =~ "Save"
    end

    test "renders icon when provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="icon-test" title="Icon Test" icon="warning" icon_class="text-red-500">
          <p>Content</p>
        </CoreComponents.modal>
        """)

      assert html =~ "warning"
      assert html =~ "text-red-500"
    end
  end

  describe "modal/1 regressions" do
    # JS.show sets inline display:block on the -container element, which
    # overrides Tailwind's flex/flex-col classes. The flex column layout must
    # therefore live on an inner wrapper, not on the container itself —
    # otherwise the body stops scrolling and form content (SEO section,
    # footer buttons) overflows the white panel onto the backdrop.
    test "slide-over flex layout lives inside the container, not on it" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="slide-modal" title="Slide Over" kind={:slide_over}>
          <p>Slide content</p>
        </CoreComponents.modal>
        """)

      [container_tag] = Regex.run(~r/<div[^>]*id="slide-modal-container"[^>]*>/, html)
      refute container_tag =~ "flex"
      assert html =~ "flex h-full flex-col"
    end

    # phx-click-away on the full-screen wrapper never fires (backdrop clicks
    # are inside it). It must sit on the panel container so clicking the
    # backdrop closes the modal.
    test "slide-over container handles click-away" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="slide-modal" title="Slide Over" kind={:slide_over}>
          <p>Slide content</p>
        </CoreComponents.modal>
        """)

      [container_tag] = Regex.run(~r/<div[^>]*id="slide-modal-container"[^>]*>/, html)
      assert container_tag =~ "phx-click-away"
    end

    # Server-driven modals render with :if={...} and need to reveal
    # themselves on mount — the show attr wires show_modal into phx-mounted.
    test "show attr mounts the modal visible" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="auto-show" title="Auto" kind={:slide_over} show>
          <p>Content</p>
        </CoreComponents.modal>
        """)

      [root_tag] = Regex.run(~r/<div[^>]*id="auto-show"[^>]*>/, html)
      assert root_tag =~ "phx-mounted"
    end

    test "centered container handles click-away" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.modal id="center-modal" title="Centered">
          <p>Content</p>
        </CoreComponents.modal>
        """)

      [container_tag] = Regex.run(~r/<div[^>]*id="center-modal-container"[^>]*>/, html)
      assert container_tag =~ "phx-click-away"
    end
  end

  describe "confirm_modal/1" do
    test "renders confirmation modal with required attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.confirm_modal
          id="confirm-test"
          title="Delete Item"
          message="Are you sure you want to delete this item?"
          on_confirm="delete_item"
          value="123"
        />
        """)

      assert html =~ "confirm-test"
      assert html =~ "Delete Item"
      assert html =~ "Are you sure you want to delete this item?"
      assert html =~ "Confirm"
      assert html =~ "Cancel"
    end

    test "renders custom confirm/cancel text" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.confirm_modal
          id="custom-text"
          title="Remove"
          message="Remove this?"
          confirm_text="Yes, Remove"
          cancel_text="No, Keep"
          on_confirm="remove_item"
        />
        """)

      assert html =~ "Yes, Remove"
      assert html =~ "No, Keep"
    end

    test "renders destructive styling" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.confirm_modal
          id="destructive-test"
          title="Delete"
          message="Delete forever?"
          confirm_text="Delete"
          confirm_class="bg-red-600 hover:bg-red-700 text-white"
          on_confirm="delete"
        />
        """)

      assert html =~ "bg-red-600"
    end

    test "renders icon with custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.confirm_modal
          id="icon-confirm"
          title="Warning"
          message="Careful!"
          on_confirm="proceed"
          icon="warning"
          icon_class="text-red-500"
        />
        """)

      assert html =~ "warning"
      assert html =~ "text-red-500"
    end
  end

  describe "show_modal/2 and hide_modal/2" do
    test "show_modal returns JS struct" do
      result = CoreComponents.show_modal("test-id")
      assert %Phoenix.LiveView.JS{} = result
    end

    test "hide_modal returns JS struct" do
      result = CoreComponents.hide_modal("test-id")
      assert %Phoenix.LiveView.JS{} = result
    end

    test "show_modal can be chained from existing JS" do
      result =
        %Phoenix.LiveView.JS{}
        |> Phoenix.LiveView.JS.push("some-event")
        |> CoreComponents.show_modal("test-id")

      assert %Phoenix.LiveView.JS{} = result
    end
  end
end
