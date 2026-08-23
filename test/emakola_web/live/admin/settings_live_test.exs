defmodule EmakolaWeb.Admin.SettingsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "SettingsLive (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/auth/login"}}} =
               live(conn, ~p"/admin/settings")
    end
  end

  describe "SettingsLive (authenticated)" do
    setup %{conn: conn} do
      {conn, merchant, store} = setup_authenticated_merchant(conn)
      %{conn: conn, merchant: merchant, store: store}
    end

    test "renders settings page with store info", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings")

      assert html =~ "Settings"
      assert html =~ store.name
    end

    test "renders tab navigation", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/settings")

      assert html =~ "General"
      assert html =~ "Contact"
      assert html =~ "Delivery"
      assert html =~ "Notifications"
    end

    test "can update store name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view
        |> form("#general-form", %{store: %{name: "Updated Store Name"}})
        |> render_submit()

      assert html =~ "Settings saved"
    end

    test "can update tagline and cover image URL via General tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view
        |> form("#general-form", %{
          store: %{
            tagline: "Handmade with love in Accra",
            cover_image_url: "https://cdn.example.com/cover.jpg"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved"
      assert html =~ "Handmade with love in Accra"
      assert html =~ "https://cdn.example.com/cover.jpg"
    end

    # The logo tile rendered initials and "Change Logo" was a dead button —
    # no allow_upload, no live_file_input anywhere in the page. A merchant who
    # cannot read a URL had no way to put a picture on their shop.
    test "a logo photo uploads to platform storage and lands on the store", %{
      conn: conn,
      store: store
    } do
      Mox.stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
        {:ok, "https://cdn.example.com/#{path}"}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/settings")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      photo =
        file_input(view, "#general-form", :logo, [
          %{name: "shop.png", content: <<137, 80, 78, 71>>, type: "image/png"}
        ])

      render_upload(photo, "shop.png")

      view |> form("#general-form", %{store: %{name: store.name}}) |> render_submit()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.logo_url =~ "https://cdn.example.com/stores/#{store.id}/branding/"
    end

    test "a cover photo uploads and lands on the store", %{conn: conn, store: store} do
      Mox.stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
        {:ok, "https://cdn.example.com/#{path}"}
      end)

      {:ok, view, _html} = live(conn, ~p"/admin/settings")
      Mox.allow(Emakola.StorageMock, self(), view.pid)

      photo =
        file_input(view, "#general-form", :cover, [
          %{name: "banner.jpg", content: <<255, 216, 255, 224>>, type: "image/jpeg"}
        ])

      render_upload(photo, "banner.jpg")

      view |> form("#general-form", %{store: %{name: store.name}}) |> render_submit()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.cover_image_url =~ "https://cdn.example.com/stores/#{store.id}/branding/"
    end

    # Every failure used to surface as one flash reading "Could not save
    # settings", with nothing pointing at the field that was wrong.
    test "an empty shop name is refused at the field, before saving", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html = view |> form("#general-form", %{store: %{name: ""}}) |> render_change()

      assert html =~ "Your shop needs a name"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.name == store.name
    end

    test "a tagline over the limit is refused at the field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view
        |> form("#general-form", %{store: %{name: "Shop", tagline: String.duplicate("a", 141)}})
        |> render_change()

      assert html =~ "Keep it under 140 letters"
    end

    test "saving with an invalid field shows the field error, not a flash", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html = view |> form("#general-form", %{store: %{name: ""}}) |> render_submit()

      assert html =~ "Your shop needs a name"
      refute html =~ "Settings saved"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.name == store.name
    end

    test "can enable buyer protection from the General tab", %{conn: conn, store: store} do
      {:ok, view, html} = live(conn, ~p"/admin/settings")

      # Copy is deliberately plainer than "Buyer Protection" — these
      # merchants read slowly; the control still writes the same field.
      assert html =~ "Hold money until it arrives"

      view
      |> form("#general-form", %{store: %{buyer_protection_enabled: "true"}})
      |> render_submit()

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).buyer_protection_enabled ==
               true
    end

    test "can enable digital downloads from the General tab", %{conn: conn, store: store} do
      {:ok, view, html} = live(conn, ~p"/admin/settings")

      assert html =~ "Things they download"

      assert Ash.get!(Emakola.Stores.Store, store.id, authorize?: false).enabled_product_types ==
               [:physical]

      view
      |> form("#general-form", %{
        store: %{enabled_product_types: ["physical", "digital_download"]}
      })
      |> render_submit()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert :digital_download in reloaded.enabled_product_types
      assert :physical in reloaded.enabled_product_types
    end

    # A checkbox group submits no key at all when nothing is ticked. Without a
    # fixed hidden input, a merchant unticking everything would strip :physical
    # and make their entire existing catalogue un-editable, because
    # ProductTypeAcceptedByStore runs on Product :update too.
    test "physical can never be removed from the enabled types", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      view
      |> form("#general-form", %{store: %{name: "Renamed Shop"}})
      |> render_submit()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert :physical in reloaded.enabled_product_types
    end

    # Saving an unrelated General field must not silently switch digital off —
    # this is what pins "render the checkbox checked from the store".
    test "an unrelated General save keeps digital downloads enabled", %{
      conn: conn,
      store: store
    } do
      store
      |> Ash.Changeset.for_update(:update_settings, %{
        enabled_product_types: [:physical, :digital_download]
      })
      |> Ash.update!(authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      view
      |> form("#general-form", %{store: %{name: "Still Digital"}})
      |> render_submit()

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert :digital_download in reloaded.enabled_product_types
    end

    # The checkbox values are user-submitted strings. Ash's :atom type with a
    # one_of constraint must reject an unknown value rather than interning it —
    # otherwise a crafted POST is an atom-table exhaustion DoS.
    test "a forged product type is rejected and creates no atom", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      forged = "totally_not_a_real_product_type_#{System.unique_integer([:positive])}"

      # Deliberately NOT via form/3 — that helper validates values against the
      # rendered DOM options and would refuse to send this. An attacker crafts
      # the socket message directly, so that is what must be exercised.
      render_submit(view, "save_general", %{
        "store" => %{"enabled_product_types" => ["physical", forged]}
      })

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.enabled_product_types == [:physical]

      assert_raise ArgumentError, fn -> String.to_existing_atom(forged) end
    end

    test "can update contact info", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      # Switch to contact tab
      view |> element("[phx-click=\"switch_tab\"][phx-value-tab=\"contact\"]") |> render_click()

      html =
        view
        |> form("#contact-form", %{
          store: %{
            contact_email: "test@example.com",
            contact_phone: "+233 24 123 4567"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved"
    end

    test "renders GhanaPost digital address and landmark fields in the Contact tab", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view |> element("[phx-click=\"switch_tab\"][phx-value-tab=\"contact\"]") |> render_click()

      assert html =~ "GhanaPost Digital Address"
      assert html =~ "Landmark"
    end

    test "can save GhanaPost digital address and landmark from the Contact tab", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      view |> element("[phx-click=\"switch_tab\"][phx-value-tab=\"contact\"]") |> render_click()

      html =
        view
        |> form("#contact-form", %{
          store: %{
            digital_address: "ga 183 8164",
            landmark: "behind Achimota Melcom"
          }
        })
        |> render_submit()

      assert html =~ "Settings saved"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.digital_address == "GA-183-8164"
      assert reloaded.landmark == "behind Achimota Melcom"
    end

    # The store profile isn't a delivery-collecting flow (there's no rider
    # dispatched to the merchant's own listed address), so the rider hint
    # from the shared component doesn't apply here.
    test "does not show the rider-delivery hint on the Contact tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      html =
        view |> element("[phx-click=\"switch_tab\"][phx-value-tab=\"contact\"]") |> render_click()

      refute html =~ "Helps the rider find you faster"
    end

    test "invalid digital address shows the friendly message and does not save", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/settings")

      view |> element("[phx-click=\"switch_tab\"][phx-value-tab=\"contact\"]") |> render_click()

      html =
        view
        |> form("#contact-form", %{store: %{digital_address: "not-a-code"}})
        |> render_submit()

      assert html =~ "Check the digital address — it looks like GA-183-8164"
      refute html =~ "Settings saved"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert is_nil(reloaded.digital_address)
    end
  end

  defp setup_authenticated_merchant(conn) do
    {merchant, store} = Factory.create_merchant_with_store!()
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    {conn, merchant, store}
  end
end
