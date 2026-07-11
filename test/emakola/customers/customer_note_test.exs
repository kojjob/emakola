defmodule Emakola.Customers.CustomerNoteTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    customer = create_customer!(store, email: "notes@example.com", name: "Notes Test")
    {:ok, store: store, customer: customer}
  end

  # -- Creation -------------------------------------------------------

  describe "create" do
    test "creates a note with author", %{store: store, customer: customer} do
      merchant = create_merchant!()

      note =
        create_customer_note!(customer, store, content: "VIP customer", author_id: merchant.id)

      assert note.id
      assert note.customer_id == customer.id
      assert note.store_id == store.id
      assert note.content == "VIP customer"
      assert note.author_id == merchant.id
    end

    test "creates a note without author (system-generated)", %{store: store, customer: customer} do
      note = create_customer_note!(customer, store, content: "Auto-generated note")

      assert note.id
      assert is_nil(note.author_id)
      assert note.content == "Auto-generated note"
    end

    test "requires content", %{store: store, customer: customer} do
      assert {:error, _} =
               Emakola.Customers.CustomerNote
               |> Ash.Changeset.for_create(:create, %{
                 customer_id: customer.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end
  end

  # -- Destroy --------------------------------------------------------

  describe "destroy" do
    test "deletes a note", %{store: store, customer: customer} do
      note = create_customer_note!(customer, store, content: "Delete me")

      assert :ok = note |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy(authorize?: false)
    end
  end

  # -- list_by_customer -----------------------------------------------

  describe "list_by_customer" do
    test "returns notes sorted by newest first", %{store: store, customer: customer} do
      n1 = create_customer_note!(customer, store, content: "First note")
      n2 = create_customer_note!(customer, store, content: "Second note")

      results =
        Emakola.Customers.CustomerNote
        |> Ash.ActionInput.for_action(:list_by_customer, %{
          customer_id: customer.id,
          store_id: store.id
        })
        |> Ash.run_action!()

      ids = Enum.map(results, & &1.id)
      assert length(ids) == 2
      # Newest first
      assert hd(ids) == n2.id
      assert List.last(ids) == n1.id
    end

    test "does not return notes from other customers", %{store: store, customer: customer} do
      create_customer_note!(customer, store, content: "My note")

      other = create_customer!(store, email: "other-notes@example.com")
      create_customer_note!(other, store, content: "Other's note")

      results =
        Emakola.Customers.CustomerNote
        |> Ash.ActionInput.for_action(:list_by_customer, %{
          customer_id: customer.id,
          store_id: store.id
        })
        |> Ash.run_action!()

      assert length(results) == 1
      assert hd(results).content == "My note"
    end
  end
end
