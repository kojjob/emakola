defmodule EmakolaWeb.AdminComponentsTest do
  @moduledoc """
  Tests for `EmakolaWeb.AdminComponents` — shared admin UI primitives.
  """

  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias EmakolaWeb.AdminComponents

  describe "admin_page_header/1" do
    test "renders title alone" do
      html =
        render_component(&AdminComponents.admin_page_header/1, %{title: "Products"})

      assert html =~ "Products"
    end

    test "renders subtitle when given" do
      html =
        render_component(&AdminComponents.admin_page_header/1, %{
          title: "Products",
          subtitle: "Manage your catalog"
        })

      assert html =~ "Products"
      assert html =~ "Manage your catalog"
    end

    test "renders action as a link when action_path is given" do
      html =
        render_component(&AdminComponents.admin_page_header/1, %{
          title: "Products",
          action_label: "+ New Product",
          action_path: "/admin/products/new"
        })

      assert html =~ "+ New Product"
      assert html =~ ~s|href="/admin/products/new"|
    end

    test "renders action as a phx-click button when action_event is given" do
      html =
        render_component(&AdminComponents.admin_page_header/1, %{
          title: "Products",
          action_label: "+ New Product",
          action_event: "open_form"
        })

      assert html =~ "+ New Product"
      assert html =~ ~s|phx-click="open_form"|
    end

    test "renders inner_block slot for arbitrary right-side content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_page_header title="Products">
          <span data-test="custom">Custom action area</span>
        </AdminComponents.admin_page_header>
        """)

      assert html =~ "Custom action area"
      assert html =~ ~s|data-test="custom"|
    end
  end

  describe "status_pill/1" do
    test "renders the status text" do
      html =
        render_component(&AdminComponents.status_pill/1, %{
          status: "pending",
          variant: :order
        })

      assert html =~ "pending"
    end

    test "applies order-variant colors based on status" do
      paid_html =
        render_component(&AdminComponents.status_pill/1, %{status: :delivered, variant: :order})

      cancelled_html =
        render_component(&AdminComponents.status_pill/1, %{status: :cancelled, variant: :order})

      assert paid_html =~ "emerald"
      assert cancelled_html =~ "red"
    end

    test "accepts atom or string status" do
      atom_html =
        render_component(&AdminComponents.status_pill/1, %{status: :pending, variant: :order})

      string_html =
        render_component(&AdminComponents.status_pill/1, %{status: "pending", variant: :order})

      # Both should produce the same colour class
      assert atom_html =~ "amber"
      assert string_html =~ "amber"
    end

    test "falls back to slate for unknown status" do
      html =
        render_component(&AdminComponents.status_pill/1, %{
          status: "wat",
          variant: :order
        })

      assert html =~ "slate"
    end

    test "supports payment variant" do
      html =
        render_component(&AdminComponents.status_pill/1, %{
          status: :success,
          variant: :payment
        })

      assert html =~ "emerald"
    end

    test "supports product variant" do
      published =
        render_component(&AdminComponents.status_pill/1, %{
          status: :active,
          variant: :product
        })

      draft =
        render_component(&AdminComponents.status_pill/1, %{
          status: :draft,
          variant: :product
        })

      assert published =~ "emerald"
      assert draft =~ "slate"
    end
  end

  describe "empty_state/1" do
    test "renders title" do
      html =
        render_component(&AdminComponents.empty_state/1, %{title: "No orders yet"})

      assert html =~ "No orders yet"
    end

    test "renders title + description" do
      html =
        render_component(&AdminComponents.empty_state/1, %{
          title: "No orders yet",
          description: "When customers place orders they will appear here"
        })

      assert html =~ "No orders yet"
      assert html =~ "When customers place orders they will appear here"
    end

    test "renders action link when action_label + action_path given" do
      html =
        render_component(&AdminComponents.empty_state/1, %{
          title: "No products",
          action_label: "Add product",
          action_path: "/admin/products/new"
        })

      assert html =~ "Add product"
      assert html =~ ~s|href="/admin/products/new"|
    end

    test "renders without action when only title given" do
      html =
        render_component(&AdminComponents.empty_state/1, %{title: "No products"})

      refute html =~ ~s|href=|
    end
  end
end
