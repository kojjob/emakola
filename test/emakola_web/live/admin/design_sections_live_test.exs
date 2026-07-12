defmodule EmakolaWeb.Admin.DesignSectionsLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defp set_starter_theme!(store) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "starter"}})
    |> Ash.update!(authorize?: false)
  end

  defp set_atelier_theme!(store) do
    store
    |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "atelier"}})
    |> Ash.update!(authorize?: false)
  end

  # The "Add section" picker always lists every theme section (Hero,
  # Category Pills, Featured Products, Trust, Newsletter, in that fixed
  # canonical order) further down the same page, regardless of the draft's
  # actual order — see @theme_module.sections() in the template. Matching
  # against the full rendered html would let that static list satisfy an
  # order assertion by coincidence even if the draggable rows above it were
  # untouched, so reorder tests cut the page at the "Theme sections"
  # heading and assert only against the rows portion.
  defp rows_only(html), do: html |> String.split("Theme sections") |> List.first()

  # Isolates the live-preview subtree — the marker is the preview wrapper's
  # own (unique) class — from the draggable rail rows, which since Task 5
  # also carry `data-section-id`.
  defp preview_only(html), do: html |> String.split("section-preview-content") |> List.last()

  describe "without a store" do
    test "redirects to onboarding", %{conn: conn} do
      merchant = create_merchant!()
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/onboarding"}}} = live(conn, "/admin/design/sections")
    end
  end

  describe "with a non-sectionized theme store" do
    setup %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()

      # Market is the platform default theme and — like every theme except
      # Starter/Atelier — implements no sections/0.
      store =
        store
        |> Ash.Changeset.for_update(:update, %{theme_config: %{"theme" => "market"}})
        |> Ash.update!(authorize?: false)

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "redirects to the design studio with a flash instead of crashing", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/admin/design", flash: flash}}} =
               live(conn, "/admin/design/sections")

      assert flash["error"] =~ "section editing"
    end
  end

  # System.unique_integer/1 is unique only within one VM run: a draft
  # persisted before a deploy/restart can already contain an id the fresh
  # VM's counter mints again, and reorder_draft/swap_adjacent/update_entry
  # all rely on within-draft id uniqueness (a duplicate collapses both
  # sections). The generator is injected because a real collision can't be
  # forced deterministically inside a single VM run.
  describe "mint_section_id/3" do
    test "regenerates when the minted id already exists in the draft" do
      draft = [%{"id" => "block/text_section-5"}]
      counter = :counters.new(1, [])
      :counters.put(counter, 1, 4)

      gen = fn ->
        :counters.add(counter, 1, 1)
        :counters.get(counter, 1)
      end

      assert EmakolaWeb.Admin.DesignSectionsLive.mint_section_id(
               "block/text_section",
               draft,
               gen
             ) == "block/text_section-6"
    end
  end

  describe "with a starter-theme store" do
    setup %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      store = set_starter_theme!(store)
      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    test "lists the active theme's sections in order", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")
      rows_html = rows_only(html)

      assert rows_html =~ "Hero"

      assert String.match?(
               rows_html,
               ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s
             )
    end

    test "toggle + publish persists a disabled section", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"]))
      |> render_click()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      assert %{"enabled" => false} = Enum.find(saved, &(&1["id"] == "starter/newsletter"))
    end

    test "move down then publish persists the order", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(
        ~s([phx-click="move_section"][phx-value-id="starter/hero"][phx-value-dir="down"])
      )
      |> render_click()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      assert ["starter/category_pills", "starter/hero" | _] = Enum.map(saved, & &1["id"])
    end

    test "an unrecognized move direction leaves the order unchanged", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_click(view, "move_section", %{"id" => "starter/hero", "dir" => "sideways"})

      assert String.match?(
               rows_only(html),
               ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s
             )
    end

    test "reorder event applies a full id order", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      order = [
        "starter/newsletter",
        "starter/trust",
        "starter/featured_products",
        "starter/category_pills",
        "starter/hero"
      ]

      html = render_hook(view, "reorder", %{"order" => order})

      assert String.match?(
               html,
               ~r/Newsletter.*Trust.*Featured Products.*Category Pills.*Hero/s
             )
    end

    test "reorder ignores an unknown id in the payload", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      order = [
        "starter/newsletter",
        "starter/does-not-exist",
        "starter/hero",
        "starter/category_pills",
        "starter/featured_products",
        "starter/trust"
      ]

      html = render_hook(view, "reorder", %{"order" => order})
      rows_html = rows_only(html)

      refute rows_html =~ "does-not-exist"

      assert String.match?(
               rows_html,
               ~r/Newsletter.*Hero.*Category Pills.*Featured Products.*Trust/s
             )
    end

    test "reorder keeps an id missing from the payload in its original relative order, appended at the end",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_hook(view, "reorder", %{"order" => ["starter/newsletter"]})
      rows_html = rows_only(html)

      assert String.match?(
               rows_html,
               ~r/Newsletter.*Hero.*Category Pills.*Featured Products.*Trust/s
             )
    end

    test "a reorder payload whose order isn't a list is a no-op and doesn't crash the view", %{
      conn: conn
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_hook(view, "reorder", %{"order" => "not-a-list"})
      rows_html = rows_only(html)

      assert Process.alive?(view.pid)

      assert String.match?(
               rows_html,
               ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s
             )
    end

    test "a reorder payload with non-binary elements drops them without crashing the view", %{
      conn: conn
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_hook(view, "reorder", %{"order" => [1, 2, 3]})
      rows_html = rows_only(html)

      assert Process.alive?(view.pid)

      assert String.match?(
               rows_html,
               ~r/Hero.*Category Pills.*Featured Products.*Trust.*Newsletter/s
             )
    end

    test "the unsaved-changes guard is mounted and its dirty flag tracks the draft", %{conn: conn} do
      {:ok, view, html} = live(conn, "/admin/design/sections")

      assert html =~ ~s(phx-hook="UnsavedChanges")
      assert html =~ ~s(data-dirty="false")

      dirty_html =
        view
        |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"]))
        |> render_click()

      assert dirty_html =~ ~s(data-dirty="true")
    end

    test "the first section's move-up control is disabled", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      assert view
             |> element(
               ~s(button[phx-click="move_section"][phx-value-id="starter/hero"][phx-value-dir="up"][disabled])
             )
             |> has_element?()
    end

    test "reset clears the saved layout", %{conn: conn, merchant: merchant, store: store} do
      {:ok, _} = HomeSections.put_layout(merchant, store, "starter", [])
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view |> element(~s(button[phx-click="reset_layout"])) |> render_click()

      assert HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter") == nil
    end

    test "preview reflects the draft immediately (no publish)", %{conn: conn} do
      {:ok, view, html} = live(conn, "/admin/design/sections")
      # The draggable rail row also carries `data-section-id` now (Task 5),
      # so this scopes to the preview subtree specifically — the marker is
      # the preview wrapper's own class, which is unique to that div.
      assert preview_only(html) =~ ~s(data-section-id="starter/newsletter")

      view
      |> element(~s([phx-click="toggle_section"][phx-value-id="starter/newsletter"]))
      |> render_click()

      refute preview_only(render(view)) =~ ~s(data-section-id="starter/newsletter")
    end

    test "an unresolvable saved section type renders as a disabled missing-section row instead of crashing",
         %{conn: conn, store: store} do
      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{
          "theme" => "starter",
          "home_sections" => %{
            "v" => 1,
            "starter" => [
              %{
                "id" => "starter/ghost",
                "type" => "starter/ghost",
                "enabled" => true,
                "settings" => %{},
                "style" => %{}
              }
            ]
          }
        }
      })
      |> Ash.update!(authorize?: false)

      {:ok, _view, html} = live(conn, "/admin/design/sections")

      assert html =~ "Missing section"
      refute html =~ "phx-click=\"toggle_section\" phx-value-id=\"starter/ghost\""
    end

    test "editing a setting persists through publish", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s(form[phx-change="update_settings"][phx-value-id="starter/hero"]))
      |> render_change(%{
        "settings" => %{"heading" => "Big Sale", "subheading" => "", "cta_label" => ""}
      })

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")

      assert %{"settings" => %{"heading" => "Big Sale"}} =
               Enum.find(saved, &(&1["id"] == "starter/hero"))
    end

    test "editing style controls persists through publish", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s(form[phx-change="update_style"][phx-value-id="starter/hero"]))
      |> render_change(%{"style" => %{"bg" => "#112233", "text" => "#ffffff", "padding" => "lg"}})

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")

      assert %{"style" => %{"bg" => "#112233", "text" => "#ffffff", "padding" => "lg"}} =
               Enum.find(saved, &(&1["id"] == "starter/hero"))
    end

    test "add a bridged block section and publish", %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      view
      |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
      |> render_click()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      assert Enum.any?(saved, &(&1["type"] == "block/text_section"))
    end

    test "adding a block section appears immediately in the draft rail and the live preview",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
        |> render_click()

      assert html =~ "Builder block"
      assert html =~ ~s(data-section-id="block/text_section-)
    end

    test "default theme sections have no remove control", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")
      refute html =~ ~s(phx-click="remove_section" phx-value-id="starter/hero")
    end

    test "a custom block instance has a remove control that deletes it from the draft and publish",
         %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/text_section-\d+)"/, add_html)

      assert view
             |> element(~s([phx-click="remove_section"][phx-value-id="#{id}"]))
             |> has_element?()

      view |> element(~s([phx-click="remove_section"][phx-value-id="#{id}"])) |> render_click()

      refute view
             |> element(~s([phx-click="remove_section"][phx-value-id="#{id}"]))
             |> has_element?()

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      refute Enum.any?(saved, &(&1["id"] == id))
    end

    test "attempting to remove a default section via a crafted event is a no-op", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html = render_click(view, "remove_section", %{"id" => "starter/hero"})

      # Scoped via rows_only/1 — the add-section picker below the rows always
      # renders a "Hero" button, so matching the full page would pass even if
      # the handler HAD deleted the hero row. The row's own toggle control
      # proves the row itself survived.
      assert rows_only(html) =~ ~s(phx-click="toggle_section" phx-value-id="starter/hero")
    end

    # The style form renders the draft's style values raw
    # (value={@row.style["bg"] || "#ffffff"} — a map is TRUTHY, so `||` does
    # not save it), and Phoenix.HTML.Safe has no Map impl: storing a crafted
    # non-binary style value crashes the view's own re-render and destroys
    # the unpublished draft. Same class as the settings sink above.
    test "a map value in a style field is dropped instead of crashing the view", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      html =
        render_change(view, "update_style", %{
          "id" => "starter/hero",
          "style" => %{"bg" => %{"a" => "1"}, "text" => "#112233"}
        })

      assert Process.alive?(view.pid)
      # The binary value in the same payload is kept — the handler filters
      # values, it doesn't drop the whole event.
      assert html =~ ~s(value="#112233")
    end

    # Sections.resolve/1's heads only accept binaries — the storefront's
    # SectionRenderer guards this exact call (`with true <- is_binary(type)`)
    # but the editor passed the client payload straight through.
    test "add_section with a non-binary type falls through to the logged catch-all instead of crashing",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          render_click(view, "add_section", %{"type" => 5})
        end)

      assert Process.alive?(view.pid)
      assert log =~ "unhandled event"
      assert rows_only(render(view)) =~ "Hero"
    end

    # A layout written raw (migration, direct Ash update) rather than through
    # put_layout can lack the "enabled" key — Map.update! raises KeyError on
    # it. The storefront renderer tolerates such entries; the editor must too.
    test "toggling an entry saved without an enabled key enables it instead of crashing",
         %{conn: conn, store: store} do
      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{
          "theme" => "starter",
          "home_sections" => %{
            "v" => 1,
            "starter" => [%{"id" => "starter/hero", "type" => "starter/hero"}]
          }
        }
      })
      |> Ash.update!(authorize?: false)

      {:ok, view, html} = live(conn, "/admin/design/sections")

      # Without the key the row renders as hidden...
      assert rows_only(html) =~ "Hidden"

      html =
        view
        |> element(~s([phx-click="toggle_section"][phx-value-id="starter/hero"]))
        |> render_click()

      assert Process.alive?(view.pid)
      # ...and toggling enables it instead of raising KeyError.
      refute rows_only(html) =~ "Hidden"
    end

    # Same raw-write source: a non-map entry (e.g. a bare string) in the
    # layout array. The storefront's SectionRenderer skips non-map entries —
    # the editor's rows/1 and draft-walking handlers must match.
    test "a non-map entry in a raw-written layout is skipped instead of crashing the editor",
         %{conn: conn, store: store} do
      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{
          "theme" => "starter",
          "home_sections" => %{
            "v" => 1,
            "starter" => [
              "junk",
              %{
                "id" => "starter/hero",
                "type" => "starter/hero",
                "enabled" => true,
                "settings" => %{},
                "style" => %{}
              }
            ]
          }
        }
      })
      |> Ash.update!(authorize?: false)

      {:ok, view, html} = live(conn, "/admin/design/sections")

      assert rows_only(html) =~ "Hero"

      # Draft-walking handlers must survive too — toggle walks every entry.
      view
      |> element(~s([phx-click="toggle_section"][phx-value-id="starter/hero"]))
      |> render_click()

      assert Process.alive?(view.pid)
    end

    # The remaining shape from the same raw-write source: an entry that IS a
    # map but whose "type" is missing or non-binary. Sections.resolve/1 only
    # has binary heads, so an unguarded call raises FunctionClauseError — a
    # hard mount crash that locks the merchant out of the editor entirely.
    for {label, entry} <- [
          {"a missing \"type\"", %{"id" => "ghost", "enabled" => true}},
          {"a non-binary \"type\"", %{"id" => "ghost", "type" => 7, "enabled" => true}}
        ] do
      test "an entry with #{label} renders as missing instead of crashing the editor",
           %{conn: conn, store: store} do
        store
        |> Ash.Changeset.for_update(:update, %{
          theme_config: %{
            "theme" => "starter",
            "home_sections" => %{
              "v" => 1,
              "starter" => [
                unquote(Macro.escape(entry)),
                %{
                  "id" => "starter/hero",
                  "type" => "starter/hero",
                  "enabled" => true,
                  "settings" => %{},
                  "style" => %{}
                }
              ]
            }
          }
        })
        |> Ash.update!(authorize?: false)

        {:ok, view, html} = live(conn, "/admin/design/sections")

        assert Process.alive?(view.pid)
        # The good entry still renders, and the junk one degrades to the
        # existing "Missing section" row rather than taking the page down.
        assert rows_only(html) =~ "Hero"
        assert rows_only(html) =~ "Missing section"
      end
    end

    test "the add-section picker groups theme sections and content blocks", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")

      assert html =~ "Theme sections"
      assert html =~ "Content blocks"
      assert html =~ ~s(phx-click="add_section" phx-value-type="starter/hero")
      assert html =~ ~s(phx-click="add_section" phx-value-type="block/text_section")
    end

    test "add a product_grid block, edit its integer setting, and publish", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/product_grid"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/product_grid-\d+)"/, add_html)

      view
      |> element(~s(form[phx-change="update_settings"][phx-value-id="#{id}"]))
      |> render_change(%{"settings" => %{"count" => "3"}})

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      entry = Enum.find(saved, &(&1["id"] == id))
      assert entry["settings"]["count"] == 3
    end

    test "clearing a block's integer setting falls back to its default rather than crashing the preview",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/product_grid"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/product_grid-\d+)"/, add_html)

      html =
        view
        |> element(~s(form[phx-change="update_settings"][phx-value-id="#{id}"]))
        |> render_change(%{"settings" => %{"count" => ""}})

      assert Process.alive?(view.pid)
      assert html =~ "Builder block"
    end

    # A settings field can arrive as a map through ordinary bracket-notation
    # form-field tampering (settings[count][a]=1) — the same nested
    # serialization this module relies on for style[bg]. `to_string/1` has no
    # String.Chars impl for a map, so an unguarded coercion raises
    # Protocol.UndefinedError inside handle_event, crashing the LiveView and
    # silently destroying the merchant's unpublished draft.
    test "a map value in an integer-typed setting falls back to the default instead of crashing the view",
         %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/product_grid"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/product_grid-\d+)"/, add_html)

      render_change(view, "update_settings", %{
        "id" => id,
        "settings" => %{"count" => %{"a" => "1"}}
      })

      assert Process.alive?(view.pid)

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      entry = Enum.find(saved, &(&1["id"] == id))

      # ProductGrid's default_content puts count: 8 — the crafted map must
      # neither crash nor survive into the layout.
      assert entry["settings"]["count"] == 8
    end

    # Write-side sanitize_settings filters by value TYPE, not key membership,
    # so an undeclared scalar key would otherwise survive all the way to the
    # persisted layout. Junk-in-own-store rather than a tenancy leak, but the
    # editor must only ever write keys the section's schema declares.
    test "an undeclared settings key is rejected and never reaches the persisted layout", %{
      conn: conn,
      store: store
    } do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      render_change(view, "update_settings", %{
        "id" => "starter/hero",
        "settings" => %{"heading" => "Real heading", "not_in_schema" => "junk"}
      })

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      entry = Enum.find(saved, &(&1["id"] == "starter/hero"))

      assert entry["settings"]["heading"] == "Real heading"
      refute Map.has_key?(entry["settings"], "not_in_schema")
    end

    # Same class and reachability as the integer crash above, but a DIFFERENT
    # sink: a declared :string field passes the schema filter, so a crafted
    # map reaches the draft verbatim and is then rendered by the editor's OWN
    # settings form (rows/1 -> setting_field/1 -> value={@current}).
    # Phoenix.HTML.Safe has no Map impl, so the form re-render raises —
    # upstream of sanitize_entry/2, which only guards the section-render
    # (preview/storefront) path.
    test "a map value in a string-typed setting falls back to the default instead of crashing the view",
         %{conn: conn, store: store} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      render_change(view, "update_settings", %{
        "id" => "starter/hero",
        "settings" => %{"heading" => %{"a" => "1"}}
      })

      assert Process.alive?(view.pid)

      view |> element(~s(button[phx-click="publish"])) |> render_click()

      saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
      entry = Enum.find(saved, &(&1["id"] == "starter/hero"))

      # Starter hero's schema declares heading's default as "".
      assert entry["settings"]["heading"] == ""
    end

    test "a map value in a text-typed setting falls back to the default instead of crashing the view",
         %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      add_html =
        view
        |> element(~s([phx-click="add_section"][phx-value-type="block/text_section"]))
        |> render_click()

      [_, id] = Regex.run(~r/phx-value-id="(block\/text_section-\d+)"/, add_html)

      # TextSection's default_content gives `body` a :text-typed field, which
      # renders @current into the textarea body.
      render_change(view, "update_settings", %{
        "id" => id,
        "settings" => %{"body" => %{"a" => "1"}}
      })

      assert Process.alive?(view.pid)
      assert render(view) =~ "Builder block"
    end

    test "an unrecognized event is logged and does not crash the view", %{conn: conn} do
      {:ok, view, _} = live(conn, "/admin/design/sections")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          render_click(view, "some_theme_hook_event", %{"foo" => "bar"})
        end)

      assert log =~ "unhandled event"
      assert Process.alive?(view.pid)
      assert render(view) =~ "Hero"
    end
  end

  describe "preview interactivity guard (Atelier)" do
    setup %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      store = set_atelier_theme!(store)

      # Atelier's featured_products puts the FIRST product in a
      # hero_product_card and only the rest through product_card/1 — the
      # component that carries phx-click="add_to_cart". Several products
      # are needed for the dangerous markup to appear at all.
      for _ <- 1..3, do: create_product!(store, %{status: :active})

      token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      %{conn: conn, merchant: merchant, store: store}
    end

    # The preview renders REAL theme markup, which carries live bindings the
    # editor has no handlers for — Atelier's product_card/1 ships
    # phx-click="add_to_cart" and is rendered by the default-enabled
    # featured_products section. Without a guard, a merchant clicking a
    # preview product raises FunctionClauseError in handle_event/3, the
    # LiveView crashes, and the draft (socket assigns only, by design) is
    # silently destroyed. The guard is pointer-events on the content wrapper
    # — theme-agnostic, so it covers the upcoming themes too.
    test "the preview content wrapper is non-interactive, and it is the guard — not missing markup — that protects the draft",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/admin/design/sections")

      # The dangerous markup really is rendered...
      assert html =~ ~s(phx-click="add_to_cart")
      assert html =~ "atelier-product-card"

      # ...and the wrapper around the rendered sections neutralises it —
      # pointer-events for the mouse, inert for the keyboard (a merchant
      # could otherwise Tab to the button and press Enter).
      assert html =~ "section-preview-content"
      assert html =~ "pointer-events-none"
      assert html =~ "inert"
    end

    test "the panel's own chrome stays interactive", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/admin/design/sections")

      # The guard must sit on the preview CONTENT, not the whole panel —
      # the editor's own controls must keep working.
      assert view
             |> element(~s([phx-click="toggle_section"][phx-value-id="atelier/newsletter"]))
             |> has_element?()
    end
  end
end

defmodule EmakolaWeb.Admin.DesignSectionsLiveSanitizationTest do
  # Mutates the `:emakola, :extra_sectionized_themes` application env (a
  # test-only seam shared with Sections.resolve/1 — see
  # Emakola.Themes.SectionRendererTest) to exercise a section whose schema
  # actually declares an :image_url setting. None of Starter/Atelier's real
  # sections do yet, so the round-trip-honesty behavior (a rejected
  # `javascript:` URL comes back cleared after publish) can't be proven
  # against them. Must not run async — a separate module (not a describe
  # block) so the rest of the file keeps running async: true.
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias Emakola.Themes.HomeSections

  defmodule PhotoSection do
    @behaviour Emakola.Themes.Section
    use Phoenix.Component

    def key, do: "extra/photo"
    def label, do: "Photo"

    def settings_schema,
      do: [%{key: "photo_url", type: :image_url, label: "Photo URL", default: ""}]

    def render(assigns) do
      ~H"""
      <section data-sec="photo">{@settings["photo_url"]}</section>
      """
    end
  end

  defmodule FakeExtensionTheme do
    def id, do: "extra"
    def sections, do: [PhotoSection]
  end

  setup %{conn: conn} do
    Application.put_env(:emakola, :extra_sectionized_themes, [FakeExtensionTheme])
    on_exit(fn -> Application.delete_env(:emakola, :extra_sectionized_themes) end)

    {merchant, store} = create_merchant_with_store!()

    store =
      store
      |> Ash.Changeset.for_update(:update, %{
        theme_config: %{
          "theme" => "starter",
          "home_sections" => %{
            "v" => 1,
            "starter" => [
              %{
                "id" => "extra/photo",
                "type" => "extra/photo",
                "enabled" => true,
                "settings" => %{},
                "style" => %{}
              }
            ]
          }
        }
      })
      |> Ash.update!(authorize?: false)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  test "a javascript: URL in an :image_url setting is dropped at publish, the reloaded draft shows it cleared, and the flash notes the drop",
       %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, "/admin/design/sections")

    view
    |> element(~s(form[phx-change="update_settings"][phx-value-id="extra/photo"]))
    |> render_change(%{"settings" => %{"photo_url" => "javascript:alert(1)"}})

    html = view |> element(~s(button[phx-click="publish"])) |> render_click()

    saved = HomeSections.saved_layout(Ash.reload!(store, authorize?: false), "starter")
    entry = Enum.find(saved, &(&1["id"] == "extra/photo"))
    refute Map.has_key?(entry["settings"], "photo_url")

    assert html =~ "dropped"
  end
end
