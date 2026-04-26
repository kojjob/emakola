defmodule Emakola.Catalog.Validations.NotBlankTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Catalog.Validations.NotBlank

  # Helper to build a changeset with a raw attribute value, bypassing
  # Ash's type coercion which converts blank strings to nil.
  defp changeset_with_raw_name(value) do
    cs = Ash.Changeset.new(Emakola.Catalog.Category)
    %{cs | attributes: Map.put(cs.attributes, :name, value)}
  end

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  describe "validate/3" do
    test "passes for a valid non-blank string" do
      changeset = changeset_with_raw_name("Electronics")
      assert :ok == NotBlank.validate(changeset, [attribute: :name], %{})
    end

    test "passes for nil value (nil is allowed, other validations catch it)" do
      changeset = changeset_with_raw_name(nil)
      assert :ok == NotBlank.validate(changeset, [attribute: :name], %{})
    end

    test "rejects empty string" do
      changeset = changeset_with_raw_name("")

      assert {:error, error} = NotBlank.validate(changeset, [attribute: :name], %{})
      assert error.field == :name
      assert error.message == "must not be blank"
    end

    test "rejects whitespace-only string" do
      changeset = changeset_with_raw_name("   ")

      assert {:error, error} = NotBlank.validate(changeset, [attribute: :name], %{})
      assert error.field == :name
      assert error.message == "must not be blank"
    end

    test "rejects tab characters only" do
      changeset = changeset_with_raw_name("\t\t")

      assert {:error, error} = NotBlank.validate(changeset, [attribute: :name], %{})
      assert error.field == :name
      assert error.message == "must not be blank"
    end

    test "rejects newline characters only" do
      changeset = changeset_with_raw_name("\n\n")

      assert {:error, error} = NotBlank.validate(changeset, [attribute: :name], %{})
      assert error.field == :name
      assert error.message == "must not be blank"
    end

    test "rejects mixed whitespace (spaces, tabs, newlines)" do
      changeset = changeset_with_raw_name(" \t \n ")

      assert {:error, error} = NotBlank.validate(changeset, [attribute: :name], %{})
      assert error.field == :name
      assert error.message == "must not be blank"
    end

    test "passes for string with leading/trailing whitespace but content" do
      changeset = changeset_with_raw_name("  Electronics  ")
      assert :ok == NotBlank.validate(changeset, [attribute: :name], %{})
    end

    test "passes for non-string values (passthrough)" do
      # The validation only checks binary values; non-binary non-nil values pass through
      cs = Ash.Changeset.new(Emakola.Catalog.Product)
      cs = %{cs | attributes: Map.put(cs.attributes, :some_number, 42)}
      assert :ok == NotBlank.validate(cs, [attribute: :some_number], %{})
    end

    test "integration: creating category with blank name fails (Ash coerces to nil)", %{
      store: store
    } do
      # Ash coerces "" and "   " to nil, then allow_nil? false catches it
      assert {:error, _} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{name: "   ", store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "integration: creating product with blank title fails", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{title: "", store_id: store.id})
               |> Ash.create(authorize?: false)
    end

    test "integration: creating category with valid name succeeds", %{store: store} do
      assert {:ok, category} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{name: "Valid Name", store_id: store.id})
               |> Ash.create(authorize?: false)

      assert category.name == "Valid Name"
    end
  end
end
