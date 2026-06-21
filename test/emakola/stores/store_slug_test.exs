defmodule Emakola.Stores.StoreSlugTest do
  @moduledoc """
  The Store `:create` action must guarantee a globally-unique slug so onboarding
  never dead-ends when a chosen name slugifies to one that already exists. Two
  shops may share a display name; their slugs (and therefore subdomains) must
  differ.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Stores

  defp create(slug) do
    Stores.create_store(
      %{name: "Ama's Fashion", slug: slug, currency: "GHS"},
      authorize?: false
    )
  end

  describe "create :create — slug uniqueness" do
    test "a free slug is used unchanged" do
      assert {:ok, store} = create("amas-fashion")
      assert store.slug == "amas-fashion"
    end

    test "a colliding slug is disambiguated with a -2 suffix, not rejected" do
      assert {:ok, _first} = create("amas-fashion")
      assert {:ok, second} = create("amas-fashion")
      assert second.slug == "amas-fashion-2"
    end

    test "successive collisions keep incrementing the suffix" do
      assert {:ok, _} = create("glow")
      assert {:ok, _} = create("glow")
      assert {:ok, third} = create("glow")
      assert third.slug == "glow-3"
    end

    test "a colliding near-max-length slug stays within the 255-char column limit" do
      long = String.duplicate("a", 255)
      assert {:ok, first} = create(long)
      assert String.length(first.slug) == 255

      assert {:ok, second} = create(long)
      assert String.length(second.slug) <= 255
      assert String.ends_with?(second.slug, "-2")
    end
  end
end
