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

    test "renders modal with different sizes" do
      for {size, expected_class} <- [
            {:sm, "max-w-md"},
            {:md, "max-w-lg"},
            {:lg, "max-w-2xl"},
            {:xl, "max-w-4xl"}
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
