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

  describe "status_badge/1" do
    test "renders the status text" do
      html =
        render_component(&AdminComponents.status_badge/1, %{
          status: "pending",
          variant: :order
        })

      assert html =~ "pending"
    end

    test "applies order-variant colors based on status" do
      paid_html =
        render_component(&AdminComponents.status_badge/1, %{status: :delivered, variant: :order})

      cancelled_html =
        render_component(&AdminComponents.status_badge/1, %{status: :cancelled, variant: :order})

      assert paid_html =~ "success-soft"
      assert cancelled_html =~ "danger"
    end

    test "accepts atom or string status" do
      atom_html =
        render_component(&AdminComponents.status_badge/1, %{status: :pending, variant: :order})

      string_html =
        render_component(&AdminComponents.status_badge/1, %{status: "pending", variant: :order})

      # Both should produce the same colour class
      assert atom_html =~ "warning"
      assert string_html =~ "warning"
    end

    test "falls back to slate for unknown status" do
      html =
        render_component(&AdminComponents.status_badge/1, %{
          status: "wat",
          variant: :order
        })

      assert html =~ "slate"
    end

    test "supports payment variant" do
      html =
        render_component(&AdminComponents.status_badge/1, %{
          status: :success,
          variant: :payment
        })

      assert html =~ "success-soft"
    end

    test "supports product variant" do
      published =
        render_component(&AdminComponents.status_badge/1, %{
          status: :active,
          variant: :product
        })

      draft =
        render_component(&AdminComponents.status_badge/1, %{
          status: :draft,
          variant: :product
        })

      assert published =~ "success-soft"
      assert draft =~ "slate"
    end
  end

  describe "admin_button/1" do
    test "primary md renders token classes and content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_button>Save changes</AdminComponents.admin_button>
        """)

      assert html =~ "bg-primary"
      assert html =~ "hover:bg-primary-hover"
      assert html =~ "rounded-control"
      assert html =~ "px-4 py-2.5"
      assert html =~ "Save changes"
      assert html =~ ~s(type="button")
    end

    test "secondary variant renders bordered surface button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_button variant={:secondary}>Cancel</AdminComponents.admin_button>
        """)

      assert html =~ "bg-surface"
      assert html =~ "border-border"
      refute html =~ "bg-primary"
    end

    test "danger variant renders danger tokens" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_button variant={:danger}>Delete</AdminComponents.admin_button>
        """)

      assert html =~ "bg-danger"
    end

    test "sm size renders compact padding" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_button size={:sm}>Edit</AdminComponents.admin_button>
        """)

      assert html =~ "px-3 py-1.5"
    end

    test "passes through global attrs (phx-click, disabled, type)" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_button type="submit" phx-click="save" disabled={true}>
          Go
        </AdminComponents.admin_button>
        """)

      assert html =~ ~s(type="submit")
      assert html =~ ~s(phx-click="save")
      assert html =~ "disabled"
    end
  end

  describe "admin_card/1" do
    test "renders the canonical container with content" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_card>Card body</AdminComponents.admin_card>
        """)

      assert html =~ "bg-surface"
      assert html =~ "rounded-card"
      assert html =~ "border-border"
      assert html =~ "shadow-sm"
      assert html =~ "p-6"
      assert html =~ "Card body"
    end

    test "padding: :none drops the default padding" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.admin_card padding={:none}>Table here</AdminComponents.admin_card>
        """)

      refute html =~ "p-6"
    end
  end

  describe "stat_card/1" do
    test "renders label and value on the canonical card" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.stat_card label="Revenue" value="GHS 1,200.00" />
        """)

      assert html =~ "Revenue"
      assert html =~ "GHS 1,200.00"
      assert html =~ "rounded-card"
      assert html =~ "tabular-nums"
    end

    test "renders icon slot inside a coloured chip" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.stat_card label="Low Stock" value="3" icon_bg="bg-amber-50">
          <:icon><span data-test="icon">!</span></:icon>
        </AdminComponents.stat_card>
        """)

      assert html =~ ~s|data-test="icon"|
      assert html =~ "bg-amber-50"
    end

    test "omits the icon chip when no icon slot is given" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.stat_card label="Orders" value="12" />
        """)

      refute html =~ "bg-primary-soft"
    end

    test "renders delta slot under the value" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <AdminComponents.stat_card label="Orders" value="12">
          <:delta><span data-test="delta">+4%</span></:delta>
        </AdminComponents.stat_card>
        """)

      assert html =~ ~s|data-test="delta"|
      assert html =~ "+4%"
    end
  end

  describe "table_toolbar/1" do
    test "renders debounced search form with default event" do
      assigns = %{form: to_form(%{"search" => "ada"})}

      html =
        rendered_to_string(~H"""
        <AdminComponents.table_toolbar
          id="test-product-search-form"
          form={@form}
          search_query="ada"
          placeholder="Search products..."
        />
        """)

      assert html =~ ~s|id="test-product-search-form"|
      assert html =~ ~s|phx-change="search"|
      assert html =~ ~s|phx-debounce="300"|
      assert html =~ ~s|name="search"|
      assert html =~ ~s|value="ada"|
      assert html =~ ~s|placeholder="Search products..."|
    end

    test "accepts a custom search event" do
      assigns = %{form: to_form(%{"search" => ""})}

      html =
        rendered_to_string(~H"""
        <AdminComponents.table_toolbar
          id="test-inventory-search-form"
          form={@form}
          search_query=""
          search_event="search_inventory"
        />
        """)

      assert html =~ ~s|phx-change="search_inventory"|
    end

    test "renders filters and actions slots" do
      assigns = %{form: to_form(%{"search" => ""})}

      html =
        rendered_to_string(~H"""
        <AdminComponents.table_toolbar id="test-toolbar-form" form={@form} search_query="">
          <:filters><span data-test="filters">tabs</span></:filters>
          <:actions><span data-test="actions">export</span></:actions>
        </AdminComponents.table_toolbar>
        """)

      assert html =~ ~s|data-test="filters"|
      assert html =~ ~s|data-test="actions"|
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

  describe "filter_tabs/1" do
    defp tabs_fixture do
      [
        %{key: :all, label: "All", count: 8},
        %{key: :active, label: "Active", count: 5},
        %{key: :draft, label: "Draft", count: nil}
      ]
    end

    test "renders a button per tab with label, count, and filter event" do
      html =
        render_component(&AdminComponents.filter_tabs/1, %{
          tabs: tabs_fixture(),
          current: :all
        })

      assert html =~ "All"
      assert html =~ "Active"
      assert html =~ ~s|phx-click="filter_status"|
      assert html =~ ~s|phx-value-status="active"|
      assert html =~ ~r|>\s*8\s*<|
      assert html =~ ~r|>\s*5\s*<|
    end

    test "marks only the current tab as active" do
      html =
        render_component(&AdminComponents.filter_tabs/1, %{
          tabs: tabs_fixture(),
          current: :active
        })

      [_, all_button, active_button | _] = String.split(html, "<button")
      refute all_button =~ "bg-white"
      assert active_button =~ "bg-white"
    end

    test "omits the count chip when count is nil" do
      html =
        render_component(&AdminComponents.filter_tabs/1, %{
          tabs: [%{key: :draft, label: "Draft", count: nil}],
          current: :all
        })

      assert html =~ "Draft"
      refute html =~ "tab-count"
    end

    test "accepts a custom event name" do
      html =
        render_component(&AdminComponents.filter_tabs/1, %{
          tabs: tabs_fixture(),
          current: :all,
          event: "filter_stock"
        })

      assert html =~ ~s|phx-click="filter_stock"|
    end
  end

  describe "status_badge/1 icons" do
    test "order statuses carry a status icon in the pill" do
      pending = render_component(&AdminComponents.status_badge/1, %{status: :pending})
      shipped = render_component(&AdminComponents.status_badge/1, %{status: :shipped})
      cancelled = render_component(&AdminComponents.status_badge/1, %{status: :cancelled})

      assert pending =~ "hero-clock"
      assert shipped =~ "hero-truck"
      assert cancelled =~ "hero-x-mark"
    end

    test "product statuses carry a status icon in the pill" do
      active =
        render_component(&AdminComponents.status_badge/1, %{status: :active, variant: :product})

      draft =
        render_component(&AdminComponents.status_badge/1, %{status: :draft, variant: :product})

      assert active =~ "hero-check"
      assert draft =~ "hero-pencil"
    end

    test "unknown statuses render without an icon" do
      html = render_component(&AdminComponents.status_badge/1, %{status: :mystery})

      refute html =~ "hero-"
    end
  end

  describe "stock_meter/1" do
    test "renders Out in danger colors at zero stock" do
      html = render_component(&AdminComponents.stock_meter/1, %{quantity: 0})

      assert html =~ "Out"
      assert html =~ "bg-red-500"
    end

    test "renders amber when stock is low" do
      html = render_component(&AdminComponents.stock_meter/1, %{quantity: 4})

      assert html =~ ~r|>\s*4\s*<|
      assert html =~ "bg-amber-500"
    end

    test "renders emerald when stock is healthy" do
      html = render_component(&AdminComponents.stock_meter/1, %{quantity: 15})

      assert html =~ ~r|>\s*15\s*<|
      assert html =~ "bg-emerald-500"
    end
  end

  describe "product_thumb/1" do
    test "renders the image when a url is given" do
      html =
        render_component(&AdminComponents.product_thumb/1, %{
          url: "https://cdn.example.com/kente.jpg",
          alt: "Kente Scarf"
        })

      assert html =~ ~s|src="https://cdn.example.com/kente.jpg"|
      assert html =~ ~s|alt="Kente Scarf"|
    end

    test "falls back to a photo icon without a url" do
      html = render_component(&AdminComponents.product_thumb/1, %{url: nil, alt: "Kente"})

      refute html =~ "<img"
      assert html =~ "hero-photo"
    end
  end
end
