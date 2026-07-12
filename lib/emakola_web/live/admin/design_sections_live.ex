defmodule EmakolaWeb.Admin.DesignSectionsLive do
  @moduledoc """
  Section editor — reorder, show/hide, and publish the active theme's
  home-page sections (spec: docs/superpowers/specs/2026-07-11-section-editor-design.md).

  All mutations happen on a draft assign; nothing persists to the store
  until Publish.

  Settings/style edits, and add/remove of custom section instances, land
  here (Task 4). Default theme sections can be hidden but never removed
  — see `custom_entry?/1`.

  The right-hand preview renders the DRAFT layout in-process through
  `Emakola.Themes.SectionRenderer.home/1` — see `render_preview/1`.
  """
  use EmakolaWeb, :live_view

  require Logger

  alias Emakola.PageBuilder
  alias Emakola.Themes.HomeSections
  alias Emakola.Themes.Sections
  alias Emakola.Themes.ThemeResolver

  @preview_product_limit 6

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns[:current_store] do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Sections", active_nav: :design)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        resolved = ThemeResolver.resolve(store.theme_config || %{}, store)
        theme_module = ThemeResolver.theme_module(resolved.theme_id)

        if Sections.sectionized?(theme_module) do
          mount_editor(socket, store, resolved, theme_module)
        else
          # Only sectionized themes implement sections/0 — for every other
          # theme (including the platform default) proceeding would crash
          # at effective_layout and in the add-section picker.
          {:ok,
           socket
           |> assign(page_title: "Sections", active_nav: :design)
           |> put_flash(
             :error,
             "The #{resolved.theme_name} theme doesn't support section editing yet."
           )
           |> redirect(to: "/admin/design")}
        end
    end
  end

  defp mount_editor(socket, store, resolved, theme_module) do
    # Preview storefront data (products/categories/delivery zones) is
    # only fetched on the connected mount — never the disconnected one
    # — so this admin-only page never doubles up on DB reads the way
    # the public storefront's SEO-driven mount intentionally does.
    {products, categories, delivery_zones} =
      if connected?(socket) do
        {load_preview_products(store), load_preview_categories(store),
         load_preview_delivery_zones(store)}
      else
        {[], [], []}
      end

    # Layouts written raw (migration, direct Ash update) can hold non-map
    # junk; the storefront's SectionRenderer skips those entries, and the
    # editor must too — rows/1 and every draft-walking handler assume maps.
    draft =
      store
      |> HomeSections.effective_layout(theme_module)
      |> Enum.filter(&is_map/1)

    {:ok,
     assign(socket,
       page_title: "Sections",
       active_nav: :design,
       store: store,
       theme_module: theme_module,
       theme: resolved,
       draft: draft,
       dirty: false,
       products: products,
       categories: categories,
       delivery_zones: delivery_zones
     )}
  end

  @impl true
  def handle_event("toggle_section", %{"id" => id}, socket) do
    # Map.put rather than Map.update! — a layout written raw (migration,
    # direct Ash update) can lack the "enabled" key, and update! would
    # raise KeyError, crashing the view and destroying the draft.
    draft =
      Enum.map(socket.assigns.draft, fn entry ->
        if entry["id"] == id,
          do: Map.put(entry, "enabled", entry["enabled"] != true),
          else: entry
      end)

    {:noreply, assign(socket, draft: draft, dirty: true)}
  end

  @impl true
  def handle_event("move_section", %{"id" => id, "dir" => dir}, socket)
      when dir in ["up", "down"] do
    {:noreply, assign(socket, draft: swap_adjacent(socket.assigns.draft, id, dir), dirty: true)}
  end

  # An unrecognized direction (only reachable by tampering with the payload)
  # leaves the draft untouched rather than crashing the editor.
  def handle_event("move_section", _params, socket), do: {:noreply, socket}

  # Drag-and-drop reordering (SectionSortable hook, assets/js/hooks/section_sortable.js)
  # pushes the full post-drop id order in one event. `order` is
  # client-controlled, so it's reconciled against the draft rather than
  # trusted verbatim — see reorder_draft/2.
  @impl true
  def handle_event("reorder", %{"order" => order}, socket) when is_list(order) do
    {:noreply, assign(socket, draft: reorder_draft(socket.assigns.draft, order), dirty: true)}
  end

  # A malformed payload (missing/non-list "order", or reachable only by
  # tampering) leaves the draft untouched rather than crashing the editor —
  # mirrors move_section's unrecognized-direction fallback above.
  def handle_event("reorder", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("publish", _params, socket) do
    %{store: store, theme_module: theme_module, draft: draft} = socket.assigns
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case HomeSections.put_layout(actor, store, theme_module.id(), draft) do
      {:ok, updated_store} ->
        # Sanitization is server-side and happens inside put_layout — reload
        # the draft from what was actually persisted so the merchant sees
        # what sanitization kept (e.g. a rejected `javascript:` URL comes
        # back cleared) rather than the values they submitted.
        persisted = HomeSections.saved_layout(updated_store, theme_module.id()) || []

        {:noreply,
         socket
         |> assign(store: updated_store, draft: persisted, dirty: false)
         |> put_flash(:info, publish_flash_message(persisted, draft))}

      {:error, :forbidden} ->
        {:noreply,
         put_flash(socket, :error, "You don't have permission to update this store's sections.")}

      {:error, :unknown_theme} ->
        {:noreply, put_flash(socket, :error, "Unknown theme — couldn't publish sections.")}

      {:error, _other} ->
        {:noreply, put_flash(socket, :error, "Couldn't publish your sections. Please try again.")}
    end
  end

  @impl true
  def handle_event("reset_layout", _params, socket) do
    %{store: store, theme_module: theme_module} = socket.assigns
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case HomeSections.clear_layout(actor, store, theme_module.id()) do
      {:ok, updated_store} ->
        {:noreply,
         socket
         |> assign(
           store: updated_store,
           draft: HomeSections.default_layout(theme_module),
           dirty: false
         )
         |> put_flash(:info, "Sections reset to the theme's defaults.")}

      {:error, :forbidden} ->
        {:noreply,
         put_flash(socket, :error, "You don't have permission to update this store's sections.")}

      {:error, :unknown_theme} ->
        {:noreply, put_flash(socket, :error, "Unknown theme — couldn't reset sections.")}

      {:error, _other} ->
        {:noreply, put_flash(socket, :error, "Couldn't reset your sections. Please try again.")}
    end
  end

  # Settings/style edits go into the draft VERBATIM — no client-side URL or
  # color filtering. That allowlisting stays server-side in
  # HomeSections.put_layout/4 at publish time (see publish/2 above), which
  # is the only path that ever writes to the store. Numeric coercion here
  # is not a security boundary — it's crash prevention for the in-process
  # preview: BlockSection-bridged content (e.g. ProductGrid's `count`) feeds
  # straight into functions like Enum.take/2 that require an integer.
  @impl true
  def handle_event("update_settings", %{"id" => id, "settings" => settings}, socket)
      when is_map(settings) do
    draft =
      update_entry(socket.assigns.draft, id, fn entry ->
        Map.put(entry, "settings", coerce_settings(entry["type"], settings))
      end)

    {:noreply, assign(socket, draft: draft, dirty: true)}
  end

  @impl true
  def handle_event("update_style", %{"id" => id, "style" => style}, socket)
      when is_map(style) do
    # Only the style form's own keys, and only binary values — the form
    # re-renders the draft raw (value={@row.style["bg"] || "#ffffff"}; a
    # map is truthy, so `||` doesn't save it) and Phoenix.HTML.Safe has no
    # Map impl. Same close-by-exclusion as coerce_settings/coerce_value.
    style =
      style
      |> Map.take(~w(bg text padding))
      |> Map.filter(fn {_key, value} -> is_binary(value) end)

    draft = update_entry(socket.assigns.draft, id, &Map.put(&1, "style", style))
    {:noreply, assign(socket, draft: draft, dirty: true)}
  end

  # Only a resolvable type is appended — an unresolvable one would just
  # render as a "Missing section" row (rows/1 already handles that
  # gracefully), so rejecting it here avoids adding dead weight to the
  # draft from a tampered payload. The is_binary guard mirrors the
  # storefront renderer's: Sections.resolve/1 only accepts binaries, so a
  # tampered non-binary type falls through to the logged catch-all below
  # instead of crashing the view.
  @impl true
  def handle_event("add_section", %{"type" => type}, socket) when is_binary(type) do
    case Sections.resolve(type) do
      {:ok, _} ->
        entry = %{
          "id" => mint_section_id(type, socket.assigns.draft),
          "type" => type,
          "enabled" => true,
          "settings" => %{},
          "style" => %{}
        }

        {:noreply, assign(socket, draft: socket.assigns.draft ++ [entry], dirty: true)}

      :error ->
        {:noreply, socket}
    end
  end

  # The remove control only RENDERS for custom instances (see
  # custom_entry?/1), but that's a UI affordance, not the enforcement — this
  # guard is what actually keeps a default theme section un-deletable, even
  # against a crafted event bypassing the missing button.
  @impl true
  def handle_event("remove_section", %{"id" => id}, socket) do
    draft = socket.assigns.draft

    case Enum.find(draft, &(&1["id"] == id)) do
      %{} = entry ->
        if custom_entry?(entry) do
          {:noreply, assign(socket, draft: Enum.reject(draft, &(&1["id"] == id)), dirty: true)}
        else
          {:noreply, socket}
        end

      nil ->
        {:noreply, socket}
    end
  end

  # Catch-all — MUST stay the last handle_event/3 clause. The preview's DOM
  # guards (pointer-events-none/inert, see render_preview/1) can't stop a JS
  # hook that pushEvents; an unrecognized event name here would otherwise
  # raise FunctionClauseError and crash the LiveView, silently destroying
  # the merchant's unpublished draft. Logging (not silently no-op'ing) means
  # a typo'd event name in this module's own markup still surfaces.
  @impl true
  def handle_event(event, _params, socket) do
    Logger.warning("[design_sections] unhandled event #{inspect(event)}")
    {:noreply, socket}
  end

  defp publish_flash_message(persisted, submitted) do
    if persisted == submitted do
      "Sections published to your live storefront."
    else
      "Sections published — some values were dropped by safety checks " <>
        "(an unsafe link or color, most likely). Review the affected section below."
    end
  end

  # System.unique_integer/1 is unique only within one VM run: a draft
  # persisted before a deploy/restart can already contain an id the fresh
  # VM's counter mints again, and reorder_draft/swap_adjacent/update_entry
  # all rely on within-draft id uniqueness (a duplicate collapses both
  # sections). Regenerate while the candidate collides so the invariant
  # holds by construction.
  @doc false
  # Public with an injectable generator so the collision-skip loop is
  # deterministically testable — a real collision can't be forced inside
  # one VM run. Mirrors HomeSections.sanitize_entry/2's
  # public-for-testability pattern.
  def mint_section_id(type, draft, gen \\ fn -> System.unique_integer([:positive]) end) do
    id = "#{type}-#{gen.()}"

    if Enum.any?(draft, &(&1["id"] == id)) do
      mint_section_id(type, draft, gen)
    else
      id
    end
  end

  defp update_entry(draft, id, fun) do
    Enum.map(draft, fn entry -> if entry["id"] == id, do: fun.(entry), else: entry end)
  end

  # A saved entry counts as "custom" — removable, unlike a default theme
  # section which can only be hidden — when its id was generated (add_section
  # always mints "#{type}-#{unique_integer}", so id != type) or it's a
  # bridged content block, which has no "default" instance at all.
  defp custom_entry?(entry) do
    type = entry["type"] || ""
    entry["id"] != type or String.starts_with?(type, "block/")
  end

  # Driven by the SCHEMA, not by the submitted params: only keys the section
  # actually declares are kept. Iterating the params instead would let a
  # crafted payload inject arbitrary extra keys — write-side
  # sanitize_settings filters by value TYPE, not key membership, so junk
  # scalars would otherwise survive all the way to the persisted layout.
  defp coerce_settings(type, params) do
    for %{key: key} = field <- schema_for_type(type),
        Map.has_key?(params, key),
        into: %{} do
      {key, coerce_value(field, Map.get(params, key))}
    end
  end

  defp coerce_value(%{type: :boolean}, value), do: value == "true"

  defp coerce_value(%{type: :integer, default: default}, value),
    do: coerce_integer(value, default)

  defp coerce_value(_field, value) when is_binary(value), do: value

  # Every remaining field type (:string, :text, :image_url, :link, and any
  # unknown) renders `@current` straight into a HEEx attribute or element
  # body in setting_field/1. Phoenix.HTML.Safe has no Map/List impl, so a
  # crafted non-scalar raises inside the editor's OWN settings-form
  # re-render — which is upstream of HomeSections.sanitize_entry/2. That
  # sanitizer only guards the SECTION-render path (preview + storefront);
  # the form re-renders the raw draft and never passes through it.
  defp coerce_value(%{default: default}, _value), do: default

  # A field can arrive as a map (or list) through ordinary bracket-notation
  # form tampering — settings[count][a]=1 — the same nested serialization
  # this module relies on for style[bg]. `to_string/1` has no String.Chars
  # impl for those, so an unguarded coercion raises Protocol.UndefinedError
  # inside handle_event, crashing the LiveView and silently destroying the
  # merchant's unpublished draft. Mirrors CssColor.safe_css_color/2's
  # explicit non-binary fallback, which is what keeps update_style safe.
  defp coerce_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> integer_default(default)
    end
  end

  defp coerce_integer(_value, default), do: integer_default(default)

  defp integer_default(default) when is_integer(default), do: default
  defp integer_default(_default), do: 0

  defp schema_for_type(type) do
    case Sections.resolve(type) do
      {:ok, {module, meta}} -> schema_for(module, meta)
      :error -> []
    end
  end

  # ── Preview data loading ────────────────────────────────────────
  # Mirrors EmakolaWeb.Storefront.StoreLive's home mount (store_live.ex)
  # context calls, with a small limit — the preview doesn't need the full
  # catalog, just enough for every theme section to have real data to
  # render (grids, category pills/circles, delivery-zone copy).

  defp load_preview_products(store) do
    Emakola.Catalog.Product
    |> Ash.Query.for_read(:list_by_store_and_status, %{store_id: store.id, status: :active})
    |> Ash.Query.limit(@preview_product_limit)
    |> Ash.read!(authorize?: false)
  end

  defp load_preview_categories(store) do
    Emakola.Catalog.list_root_categories!(store.id)
  end

  defp load_preview_delivery_zones(store) do
    Emakola.Shipping.list_delivery_zones!(store.id)
    |> Enum.filter(& &1.active)
  rescue
    exception ->
      Logger.error(
        "[design_sections_live] loading delivery zones raised: #{Exception.message(exception)}"
      )

      []
  end

  # Reorder is a pure adjacent swap on the draft list; out-of-range moves
  # (first row "up", last row "down") are a no-op rather than an error.
  defp swap_adjacent(entries, id, dir) do
    index = Enum.find_index(entries, &(&1["id"] == id))
    target = if dir == "up", do: index && index - 1, else: index && index + 1

    if index && target && target >= 0 && target < length(entries) do
      entries
      |> List.replace_at(index, Enum.at(entries, target))
      |> List.replace_at(target, Enum.at(entries, index))
    else
      entries
    end
  end

  # Reconciles a client-submitted id order against the draft: non-binary
  # elements and unknown ids (not present in the draft — including
  # duplicates) are dropped, and any draft ids the payload omits keep their
  # original relative order, appended after the ids the payload did place.
  defp reorder_draft(draft, order) do
    known_ids = Enum.map(draft, & &1["id"])

    placed_ids =
      order
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()
      |> Enum.filter(&(&1 in known_ids))

    placed = Enum.map(placed_ids, fn id -> Enum.find(draft, &(&1["id"] == id)) end)
    remaining = Enum.reject(draft, &(&1["id"] in placed_ids))

    placed ++ remaining
  end

  # Resolves each draft entry's display label AND settings schema from the
  # section registry ONCE per render (Sections.resolve/1 rebuilds the
  # registry index on every call, so the template must not call it
  # per-attribute). Saved types that no longer resolve (a theme's section
  # list changed since the layout was saved) are marked `missing?` and
  # render as an inert row instead of crashing the editor.
  defp rows(draft) do
    last_index = length(draft) - 1

    for {entry, index} <- Enum.with_index(draft) do
      base = %{
        id: entry["id"],
        first?: index == 0,
        last?: index == last_index
      }

      case Sections.resolve(entry["type"]) do
        {:ok, {module, meta}} ->
          Map.merge(base, %{
            label: module.label(),
            missing?: false,
            enabled?: entry["enabled"] == true,
            custom?: custom_entry?(entry),
            schema: schema_for(module, meta),
            settings: entry["settings"] || %{},
            style: entry["style"] || %{}
          })

        :error ->
          Map.merge(base, %{
            label: entry["type"] || entry["id"],
            missing?: true,
            enabled?: false,
            custom?: false,
            schema: [],
            settings: %{},
            style: %{}
          })
      end
    end
  end

  # Block-bridged entries (Sections.BlockSection) declare no schema of
  # their own — their editable settings come from the block's
  # default_content/0, scalar keys only. List/map-valued content (FAQ
  # items, testimonial lists) is dropped by layout sanitization on write,
  # so offering a form field for it would be a lie — see BlockSection's
  # moduledoc.
  defp schema_for(Sections.BlockSection, %{block_module: block_module}) do
    block_module.default_content()
    |> Enum.filter(fn {_key, value} -> scalar_setting?(value) end)
    |> Enum.map(fn {key, value} ->
      key_str = Atom.to_string(key)

      %{
        key: key_str,
        type: block_setting_type(key_str, value),
        label: humanize(key_str),
        default: value
      }
    end)
  end

  defp schema_for(module, _meta), do: module.settings_schema()

  defp scalar_setting?(value),
    do: is_binary(value) or is_boolean(value) or is_integer(value) or is_nil(value)

  defp block_setting_type(_key, value) when is_boolean(value), do: :boolean
  defp block_setting_type(_key, value) when is_integer(value), do: :integer
  defp block_setting_type("image_url", _value), do: :image_url

  defp block_setting_type(key, _value) do
    cond do
      String.ends_with?(key, "_url") -> :link
      String.ends_with?(key, "body") -> :text
      true -> :string
    end
  end

  defp humanize(key), do: key |> String.replace("_", " ") |> String.capitalize()

  # ── Live preview ────────────────────────────────────────────────
  # The preview is a PICTURE of the storefront, not a working one. It
  # renders real theme markup, which carries live bindings this LiveView
  # has no handlers for (Atelier's product_card/1 ships
  # phx-click="add_to_cart"; every theme's newsletter section ships
  # phx-submit="subscribe_newsletter"). Clicking one would raise
  # FunctionClauseError in handle_event/3, crash the LiveView, and
  # silently destroy the draft — which lives in socket assigns by design.
  #
  # So the content wrapper is made non-interactive rather than the editor
  # growing a stub handler per binding: `pointer-events-none` kills mouse
  # activation (and, for free, the hover affordances that would imply the
  # preview is clickable), and `inert` additionally removes descendants
  # from the tab order and the accessibility tree — without it a merchant
  # could still Tab into a preview button and press Enter. Both are
  # theme-agnostic, so the upcoming themes are covered by construction.
  # The guard sits on the CONTENT only; the panel's own chrome stays live.
  #
  # Renders the DRAFT layout — not the saved one — by swapping a
  # struct-copied store's theme_config into a preview store, mirroring
  # HomeSections.put_layout/4's own map construction: `home_sections` is
  # seeded with the envelope key when absent (put_in on a missing key
  # path would raise), then the active theme's entry is replaced with the
  # in-memory draft. This copy is never persisted — it exists only for
  # the duration of this render — so publishing remains the only way to
  # write the draft to the database.
  attr :store, :map, required: true
  attr :theme_module, :atom, required: true
  attr :theme, :map, required: true
  attr :draft, :list, required: true
  attr :products, :list, required: true
  attr :categories, :list, required: true
  attr :delivery_zones, :list, required: true

  defp render_preview(assigns) do
    section_assigns = %{
      __changed__: nil,
      preview: true,
      store: preview_store(assigns.store, assigns.theme_module, assigns.draft),
      theme_module: assigns.theme_module,
      theme: assigns.theme,
      products: assigns.products,
      categories: assigns.categories,
      delivery_zones: assigns.delivery_zones
    }

    assigns =
      assigns
      |> assign(:section_assigns, section_assigns)
      |> assign(:frame_style, theme_style_vars(assigns.theme))

    ~H"""
    <div
      class="section-preview-content pointer-events-none mx-auto max-w-[1280px] bg-white"
      style={@frame_style}
      inert
    >
      {Emakola.Themes.SectionRenderer.home(@section_assigns)}
    </div>
    """
  end

  defp preview_store(store, theme_module, draft) do
    existing = store.theme_config || %{}
    section_map = Map.get(existing, "home_sections", %{"v" => 1})
    config = Map.put(existing, "home_sections", Map.put(section_map, theme_module.id(), draft))
    %{store | theme_config: config}
  end

  # Only the three CSS custom properties section templates actually
  # consume (`var(--theme-primary, …)` etc.) — no section or shared
  # component under lib/emakola/themes references the design-token
  # font/button-radius variables the storefront layout also defines, so
  # reproducing those here would be dead weight. Colors are merchant
  # input flowing into a style attribute, so they go through the same
  # hex-only allowlist the storefront layout uses.
  defp theme_style_vars(theme) do
    colors = Map.get(theme, :colors) || %{}

    primary = EmakolaWeb.Helpers.CssColor.safe_css_color(colors[:primary], "#6366F1")
    accent = EmakolaWeb.Helpers.CssColor.safe_css_color(colors[:accent], "#1E293B")
    background = EmakolaWeb.Helpers.CssColor.safe_css_color(colors[:background], "#FFFFFF")

    "--theme-primary: #{primary}; --theme-accent: #{accent}; --theme-bg: #{background};"
  end

  # ── Settings + style forms ──────────────────────────────────────
  # Both forms push the ENTIRE form's current field values on every change
  # (standard phx-change behavior), so the "id" comes from phx-value-id on
  # the <form> itself, matching the update_settings/update_style event
  # contract exactly: %{"id" => id, "settings"/"style" => params}.

  attr :row, :map, required: true
  attr :categories, :list, required: true

  defp section_settings_form(assigns) do
    ~H"""
    <form
      phx-change="update_settings"
      phx-value-id={@row.id}
      class="grid grid-cols-1 gap-4 sm:grid-cols-2"
    >
      <p :if={@row.schema == []} class="col-span-full text-sm text-text-muted">
        This section has no editable settings.
      </p>
      <.setting_field
        :for={field <- @row.schema}
        field={field}
        value={Map.get(@row.settings, field.key)}
        categories={@categories}
      />
    </form>
    """
  end

  attr :field, :map, required: true
  attr :value, :any, default: nil
  attr :categories, :list, default: []

  defp setting_field(assigns) do
    assigns = assign(assigns, :current, assigns.value || assigns.field.default)

    ~H"""
    <label class={["block", @field.type == :text && "sm:col-span-2"]}>
      <span class="mb-1 block text-xs font-medium text-text-muted">{@field.label}</span>
      <%= case @field.type do %>
        <% :text -> %>
          <textarea
            name={"settings[#{@field.key}]"}
            rows="3"
            phx-debounce="300"
            class={setting_input_classes()}
          >{@current}</textarea>
        <% :boolean -> %>
          <span class="flex items-center pt-1.5">
            <input type="hidden" name={"settings[#{@field.key}]"} value="false" />
            <input
              type="checkbox"
              name={"settings[#{@field.key}]"}
              value="true"
              checked={@current == true}
              class="size-4 rounded border-border text-primary focus:ring-2 focus:ring-primary/30"
            />
          </span>
        <% :integer -> %>
          <input
            type="number"
            name={"settings[#{@field.key}]"}
            value={@current}
            phx-debounce="300"
            class={setting_input_classes()}
          />
        <% type when type in [:image_url, :link] -> %>
          <input
            type="url"
            name={"settings[#{@field.key}]"}
            value={@current}
            placeholder="https://"
            phx-debounce="300"
            class={setting_input_classes()}
          />
        <% :category -> %>
          <select name={"settings[#{@field.key}]"} class={setting_input_classes()}>
            <option value="">Select a category</option>
            <option
              :for={category <- @categories}
              value={category.id}
              selected={@current == category.id}
            >
              {category.name}
            </option>
          </select>
        <% _string_or_unknown -> %>
          <input
            type="text"
            name={"settings[#{@field.key}]"}
            value={@current}
            phx-debounce="300"
            class={setting_input_classes()}
          />
      <% end %>
    </label>
    """
  end

  attr :row, :map, required: true

  defp section_style_form(assigns) do
    ~H"""
    <form
      phx-change="update_style"
      phx-value-id={@row.id}
      class="grid grid-cols-1 gap-4 sm:grid-cols-3"
    >
      <label class="block">
        <span class="mb-1 block text-xs font-medium text-text-muted">Background color</span>
        <input
          type="color"
          name="style[bg]"
          value={@row.style["bg"] || "#ffffff"}
          class="h-10 w-full cursor-pointer rounded-control border border-border p-1"
        />
      </label>
      <label class="block">
        <span class="mb-1 block text-xs font-medium text-text-muted">Text color</span>
        <input
          type="color"
          name="style[text]"
          value={@row.style["text"] || "#0f172a"}
          class="h-10 w-full cursor-pointer rounded-control border border-border p-1"
        />
      </label>
      <label class="block">
        <span class="mb-1 block text-xs font-medium text-text-muted">Padding</span>
        <select name="style[padding]" class={setting_input_classes()}>
          <option
            :for={{padding, text} <- padding_options()}
            value={padding}
            selected={@row.style["padding"] == padding}
          >
            {text}
          </option>
        </select>
      </label>
    </form>
    """
  end

  defp setting_input_classes,
    do:
      "w-full rounded-control border border-border bg-surface px-3 py-2 text-sm text-text " <>
        "focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary"

  # Mirrors HomeSections' padding allowlist (~w(none sm md lg)) exactly —
  # these are the only values put_layout/4 will keep at publish.
  defp padding_options,
    do: [{"none", "None"}, {"sm", "Small"}, {"md", "Medium"}, {"lg", "Large"}]

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :rows, rows(assigns.draft))

    ~H"""
    <div
      id="unsaved-guard"
      phx-hook="UnsavedChanges"
      data-dirty={to_string(@dirty)}
      class="max-w-[1600px] mx-auto px-4 sm:px-6 pb-16"
    >
      <.admin_page_header
        title="Sections"
        subtitle="Reorder, show, or hide sections on your store's home page"
      >
        <.admin_button
          variant={:secondary}
          phx-click="reset_layout"
          data-confirm="Reset to the theme's default sections? Any unpublished changes will be lost."
        >
          Reset to defaults
        </.admin_button>
        <.admin_button phx-click="publish" disabled={!@dirty}>
          Publish
        </.admin_button>
      </.admin_page_header>

      <div
        :if={@dirty}
        class="mb-5 flex items-center gap-2 rounded-control border border-warning/30 bg-warning-soft px-4 py-3 text-sm font-medium text-warning"
      >
        <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
        You have unpublished changes — click Publish to make them live.
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-12 gap-5">
        <section class="lg:col-span-6">
          <.admin_card
            id="section-rows"
            phx-hook="SectionSortable"
            padding={:none}
            class="divide-y divide-border"
          >
            <div :for={row <- @rows}>
              <div
                class={["flex items-center gap-3 px-4 py-3.5", row.missing? && "opacity-60"]}
                draggable={to_string(!row.missing?)}
                data-section-id={row.id}
              >
                <.icon name="hero-bars-2" class="size-4 shrink-0 text-text-muted" />

                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-semibold text-text">{row.label}</p>
                </div>

                <span
                  :if={row.missing?}
                  class="inline-flex items-center whitespace-nowrap rounded-full bg-danger-soft px-2.5 py-0.5 text-xs font-semibold text-danger"
                >
                  Missing section
                </span>
                <span
                  :if={!row.missing? && !row.enabled?}
                  class="inline-flex items-center whitespace-nowrap rounded-full bg-surface-subtle px-2.5 py-0.5 text-xs font-semibold text-text-muted"
                >
                  Hidden
                </span>

                <%!-- Missing sections render inert placeholders — no phx-click
              wiring at all, so a stale/removed section type can never
              trigger a handler. --%>
                <div :if={row.missing?} class="flex items-center gap-0.5 opacity-30">
                  <span class="p-1.5">
                    <.icon name="hero-chevron-up" class="size-4 text-text-muted" />
                  </span>
                  <span class="p-1.5">
                    <.icon name="hero-chevron-down" class="size-4 text-text-muted" />
                  </span>
                </div>
                <div :if={!row.missing?} class="flex items-center gap-0.5">
                  <button
                    type="button"
                    phx-click="move_section"
                    phx-value-id={row.id}
                    phx-value-dir="up"
                    disabled={row.first?}
                    class="rounded-control p-1.5 text-text-muted transition-colors hover:bg-surface-subtle hover:text-text disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent"
                    aria-label={"Move #{row.label} up"}
                  >
                    <.icon name="hero-chevron-up" class="size-4" />
                  </button>
                  <button
                    type="button"
                    phx-click="move_section"
                    phx-value-id={row.id}
                    phx-value-dir="down"
                    disabled={row.last?}
                    class="rounded-control p-1.5 text-text-muted transition-colors hover:bg-surface-subtle hover:text-text disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:bg-transparent"
                    aria-label={"Move #{row.label} down"}
                  >
                    <.icon name="hero-chevron-down" class="size-4" />
                  </button>
                </div>

                <span
                  :if={row.missing?}
                  aria-hidden="true"
                  class="relative inline-flex h-6 w-11 shrink-0 items-center rounded-full border border-border bg-surface-subtle opacity-40"
                >
                  <span class="inline-block size-4 translate-x-1 transform rounded-full bg-white shadow" />
                </span>
                <button
                  :if={!row.missing?}
                  type="button"
                  phx-click="toggle_section"
                  phx-value-id={row.id}
                  role="switch"
                  aria-checked={to_string(row.enabled?)}
                  aria-label={"Toggle #{row.label}"}
                  class={[
                    "relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors",
                    if(row.enabled?,
                      do: "bg-primary",
                      else: "bg-surface-subtle border border-border"
                    )
                  ]}
                >
                  <span class={[
                    "inline-block size-4 transform rounded-full bg-white shadow transition-transform",
                    if(row.enabled?, do: "translate-x-6", else: "translate-x-1")
                  ]} />
                </button>

                <%!-- Missing sections stay fully inert — no settings panel,
              no phx-click wiring — same rule as the reorder/toggle
              controls above. --%>
                <button
                  :if={row.missing?}
                  type="button"
                  disabled
                  class="p-1.5 text-text-muted opacity-30"
                  aria-label="Section settings unavailable"
                >
                  <.icon name="hero-chevron-right" class="size-4" />
                </button>
                <button
                  :if={!row.missing?}
                  type="button"
                  phx-click={JS.toggle(to: "#section-panel-#{row.id}")}
                  class="rounded-control p-1.5 text-text-muted transition-colors hover:bg-surface-subtle hover:text-text"
                  aria-label={"Edit #{row.label} settings"}
                  aria-expanded="false"
                  aria-controls={"section-panel-#{row.id}"}
                >
                  <.icon name="hero-chevron-right" class="size-4" />
                </button>
              </div>

              <div
                :if={!row.missing?}
                id={"section-panel-#{row.id}"}
                class="hidden border-t border-border bg-surface-subtle/60 px-4 py-4"
              >
                <p class="mb-3 text-xs font-semibold uppercase tracking-wide text-text-muted">
                  Settings
                </p>
                <.section_settings_form row={row} categories={@categories} />

                <p class="mb-3 mt-5 text-xs font-semibold uppercase tracking-wide text-text-muted">
                  Style
                </p>
                <.section_style_form row={row} />

                <div :if={row.custom?} class="mt-5 flex justify-end border-t border-border pt-4">
                  <.admin_button
                    variant={:danger}
                    size={:sm}
                    phx-click="remove_section"
                    phx-value-id={row.id}
                    data-confirm="Remove this section? This can't be undone."
                  >
                    <.icon name="hero-trash" class="size-3.5" /> Remove section
                  </.admin_button>
                </div>
              </div>
            </div>
          </.admin_card>

          <div class="relative mt-4">
            <button
              type="button"
              phx-click={JS.toggle(to: "#add-section-picker")}
              class="flex w-full items-center justify-center gap-2 rounded-control border-2 border-dashed border-border px-4 py-3 text-sm font-semibold text-text-muted transition-colors hover:border-primary hover:text-primary"
              aria-expanded="false"
              aria-controls="add-section-picker"
            >
              <.icon name="hero-plus" class="size-4" /> Add section
            </button>

            <div
              id="add-section-picker"
              class="hidden absolute inset-x-0 top-full z-10 mt-2 max-h-96 overflow-y-auto rounded-card border border-border bg-surface p-3 shadow-lg"
            >
              <p class="mb-2 px-1 text-xs font-semibold uppercase tracking-wide text-text-muted">
                Theme sections
              </p>
              <div class="mb-4 grid grid-cols-2 gap-2">
                <button
                  :for={section <- @theme_module.sections()}
                  type="button"
                  phx-click="add_section"
                  phx-value-type={section.key()}
                  class="rounded-control border border-border px-3 py-2 text-left text-sm text-text transition-colors hover:border-primary hover:bg-primary-soft/40"
                >
                  {section.label()}
                </button>
              </div>

              <p class="mb-2 px-1 text-xs font-semibold uppercase tracking-wide text-text-muted">
                Content blocks
              </p>
              <div class="grid grid-cols-2 gap-2">
                <button
                  :for={block <- PageBuilder.blocks()}
                  type="button"
                  phx-click="add_section"
                  phx-value-type={"block/#{block.type()}"}
                  class="rounded-control border border-border px-3 py-2 text-left text-sm text-text transition-colors hover:border-primary hover:bg-primary-soft/40"
                >
                  {block.name()}
                </button>
              </div>
            </div>
          </div>
        </section>

        <aside class="lg:col-span-6 lg:sticky lg:top-4 lg:self-start">
          <.admin_card padding={:none} class="overflow-hidden">
            <div class="flex items-center gap-3 border-b border-border bg-surface-subtle px-4 py-2.5">
              <div class="flex items-center gap-1.5" aria-hidden="true">
                <span class="size-2.5 rounded-full bg-slate-300"></span>
                <span class="size-2.5 rounded-full bg-slate-300"></span>
                <span class="size-2.5 rounded-full bg-slate-300"></span>
              </div>
              <div class="flex-1 truncate rounded-control border border-border bg-surface px-3 py-1 text-center text-xs text-text-muted">
                {@store.slug}.makola.io
              </div>
              <span class="inline-flex shrink-0 items-center gap-1.5 text-xs font-medium text-text-muted">
                <span class="size-1.5 rounded-full bg-success"></span> Live preview
              </span>
            </div>
            <div class="max-h-[calc(100vh-14rem)] overflow-y-auto">
              <.render_preview
                store={@store}
                theme_module={@theme_module}
                theme={@theme}
                draft={@draft}
                products={@products}
                categories={@categories}
                delivery_zones={@delivery_zones}
              />
            </div>
          </.admin_card>
        </aside>
      </div>
    </div>
    """
  end
end
