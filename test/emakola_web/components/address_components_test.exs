defmodule EmakolaWeb.AddressComponentsTest do
  @moduledoc """
  Render tests for the shared `gh_address_fields` fieldset (GhanaPost digital
  address + landmark). Covers both the flat-form idiom (`field_prefix ""`,
  used by the checkout renderer) and the nested-map idiom (`field_prefix
  "buyer"`, used by the pay-link flow), plus the hint toggle and the
  landmark placeholder. The component fires no events of its own — it just
  renders inputs that ride the parent form's existing submit.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EmakolaWeb.AddressComponents

  describe "gh_address_fields/1 — flat prefix (checkout renderer)" do
    test "renders bare field names" do
      html =
        render_component(&AddressComponents.gh_address_fields/1,
          digital_address: "",
          landmark: "",
          field_prefix: ""
        )

      assert html =~ ~s(name="digital_address")
      assert html =~ ~s(name="landmark")
      refute html =~ ~s(name="[digital_address]")
    end

    test "renders the current values" do
      html =
        render_component(&AddressComponents.gh_address_fields/1,
          digital_address: "GA-183-8164",
          landmark: "behind Achimota Melcom",
          field_prefix: ""
        )

      assert html =~ "GA-183-8164"
      assert html =~ "behind Achimota Melcom"
    end
  end

  describe "gh_address_fields/1 — nested prefix (buyer map)" do
    test "renders prefixed field names" do
      html =
        render_component(&AddressComponents.gh_address_fields/1,
          digital_address: "",
          landmark: "",
          field_prefix: "buyer"
        )

      assert html =~ ~s(name="buyer[digital_address]")
      assert html =~ ~s(name="buyer[landmark]")
    end
  end

  describe "gh_address_fields/1 — landmark placeholder" do
    test "always shows the landmark placeholder" do
      html =
        render_component(&AddressComponents.gh_address_fields/1,
          field_prefix: ""
        )

      assert html =~ "e.g. behind Achimota Melcom, blue gate"
    end
  end

  describe "gh_address_fields/1 — show_hint" do
    test "shows the rider hint by default" do
      html =
        render_component(&AddressComponents.gh_address_fields/1,
          field_prefix: ""
        )

      assert html =~ "Helps the rider find you faster"
    end

    test "hides the hint when show_hint is false" do
      html =
        render_component(&AddressComponents.gh_address_fields/1,
          field_prefix: "",
          show_hint: false
        )

      refute html =~ "Helps the rider find you faster"
    end
  end
end
