defmodule Emakola.Stores.Validations.ImageUrlTest do
  @moduledoc """
  The guard on the "Or paste a picture link" field in store settings.

  That input is `type="url"`, which asks only that the text be a URL — so two
  live merchants pasted the link to their Instagram profile and their website
  into `cover_image_url`, and the marketplace rendered each one as a broken
  image on /stores. A picture field has to insist on a picture.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory

  defp save(store, attrs) do
    store
    |> Ash.Changeset.for_update(:update_settings, attrs)
    |> Ash.update(authorize?: false)
  end

  defp errors(changeset_result) do
    {:error, %Ash.Error.Invalid{errors: errors}} = changeset_result
    Enum.map(errors, & &1.field)
  end

  setup do
    %{store: Factory.create_store!()}
  end

  describe "rejects what is not a picture" do
    test "a social profile link — the real production case", %{store: store} do
      result =
        save(store, %{
          cover_image_url:
            "https://www.instagram.com/they.luvv_karen?igsi=MWt0MjJxa3BldDYzYg%3D%3D&utm_source=qr"
        })

      assert :cover_image_url in errors(result)
    end

    test "a website link — the other production case", %{store: store} do
      result = save(store, %{cover_image_url: "https://www.makolaai.com/#download"})

      assert :cover_image_url in errors(result)
    end

    test "a logo field is guarded the same way", %{store: store} do
      result = save(store, %{logo_url: "https://example.com/my-shop"})

      assert :logo_url in errors(result)
    end

    test "a placeholder service with no file extension", %{store: store} do
      result = save(store, %{logo_url: "https://placehold.co/96x96/0c1f17/d4a843?text=T"})

      assert :logo_url in errors(result)
    end

    test "something that is not a URL at all", %{store: store} do
      assert :cover_image_url in errors(save(store, %{cover_image_url: "my picture"}))
    end

    test "a non-web scheme", %{store: store} do
      assert :cover_image_url in errors(save(store, %{cover_image_url: "ftp://x.com/a.jpg"}))
    end
  end

  describe "does not punish a merchant for data that predates it" do
    test "a store with a bad cover can still edit its other settings" do
      # Kkrr and Story Saddle already hold a page link in cover_image_url. If
      # the validation fires on an unchanged field they are locked out of their
      # own settings page — they could not fix a tagline, let alone the URL, in
      # one save. The render guard is what protects shoppers from the old value;
      # this validation's job is only to stop new ones.
      store = Ash.Seed.update!(Factory.create_store!(), %{cover_image_url: "https://x.com/page"})

      assert {:ok, updated} = save(store, %{tagline: "Fresh from Mallam Atta"})
      assert updated.tagline == "Fresh from Mallam Atta"
    end

    test "but changing that field to another bad value is still refused" do
      store = Ash.Seed.update!(Factory.create_store!(), %{cover_image_url: "https://x.com/page"})

      assert :cover_image_url in errors(save(store, %{cover_image_url: "https://y.com/other"}))
    end
  end

  describe "accepts real pictures" do
    test "the uploads the app itself writes", %{store: store} do
      url =
        "https://emakola-uploads.fly.storage.tigris.dev/stores/abc/branding/cover-1.png"

      assert {:ok, updated} = save(store, %{cover_image_url: url})
      assert updated.cover_image_url == url
    end

    test "every extension a merchant might bring", %{store: store} do
      for ext <- ~w(jpg jpeg png webp gif avif JPG PNG WebP) do
        url = "https://cdn.example.com/shop.#{ext}"
        assert {:ok, _} = save(store, %{cover_image_url: url}), "rejected .#{ext}"
      end
    end

    test "the root-relative paths the app writes for local-disk uploads", %{store: store} do
      url = "/uploads/stores/8038aecb/products/53128d58.jpg"

      assert {:ok, updated} = save(store, %{cover_image_url: url})
      assert updated.cover_image_url == url
    end

    test "a protocol-relative URL is not a local path", %{store: store} do
      assert :cover_image_url in errors(save(store, %{cover_image_url: "//evil.example/x.jpg"}))
    end

    test "a picture link carrying a query string", %{store: store} do
      url = "https://cdn.example.com/shop.jpg?v=2&w=800"

      assert {:ok, updated} = save(store, %{cover_image_url: url})
      assert updated.cover_image_url == url
    end

    test "leaving the field empty is still allowed", %{store: store} do
      assert {:ok, updated} = save(store, %{cover_image_url: ""})
      assert updated.cover_image_url in [nil, ""]

      assert {:ok, updated} = save(store, %{logo_url: nil})
      assert is_nil(updated.logo_url)
    end
  end
end
