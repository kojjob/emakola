defmodule EmakolaWeb.Admin.Content.PageContentLive do
  @moduledoc """
  Merchant editor for the storefront informational pages — About, Contact, FAQ
  and Policies. Tabs map to the per-store `StorePageContent` row, which is
  lazily created on mount. The edit draft lives in assigns (string-keyed) so the
  `{:array, :map}` lists (steps/values/FAQ) can be added/removed/edited live,
  then each tab saves its own slice via the store-scoped update action.
  """
  use EmakolaWeb, :live_view

  @scalar_fields ~w(about_headline about_intro about_story about_cta_heading about_cta_text
                    shipping_returns privacy_policy terms_of_service contact_note contact_hours)

  @list_fields ~w(about_steps about_values faq_items)

  @row_keys %{
    "about_steps" => ["title", "description"],
    "about_values" => ["title", "description"],
    "faq_items" => ["question", "answer"]
  }

  @about_attrs ~w(about_headline about_intro about_story about_cta_heading about_cta_text
                  about_steps about_values)
  @contact_attrs ~w(contact_note contact_hours)
  @faq_attrs ~w(faq_items)
  @policy_attrs ~w(shipping_returns privacy_policy terms_of_service)

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]

    case store && Emakola.Stores.PageContent.get_or_create(store.id, actor: actor) do
      {:ok, content} ->
        {:ok,
         socket
         |> assign(
           page_title: "Store Pages",
           active_nav: :page_content,
           active_tab: "about",
           store: store,
           content: content,
           draft: build_draft(content),
           saved: false
         )}

      _ ->
        {:ok, socket |> put_flash(:error, "Select a store first") |> redirect(to: ~p"/admin")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab, saved: false)}
  end

  @impl true
  def handle_event("update_scalar", %{"field" => field, "value" => value}, socket)
      when field in @scalar_fields do
    {:noreply, assign(socket, draft: Map.put(socket.assigns.draft, field, value), saved: false)}
  end

  def handle_event("update_scalar", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "update_item",
        %{"collection" => collection, "index" => index_str, "field" => field, "value" => value},
        socket
      )
      when collection in @list_fields do
    with {index, _} <- Integer.parse(index_str) do
      draft =
        update_in(socket.assigns.draft, [collection], fn rows ->
          List.update_at(rows, index, &Map.put(&1, field, value))
        end)

      {:noreply, assign(socket, draft: draft, saved: false)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("add_item", %{"collection" => collection}, socket)
      when collection in @list_fields do
    blank = Map.new(@row_keys[collection], &{&1, ""})
    draft = update_in(socket.assigns.draft, [collection], &(&1 ++ [blank]))
    {:noreply, assign(socket, draft: draft, saved: false)}
  end

  def handle_event("remove_item", %{"collection" => collection, "index" => index_str}, socket)
      when collection in @list_fields do
    with {index, _} <- Integer.parse(index_str) do
      draft = update_in(socket.assigns.draft, [collection], &List.delete_at(&1, index))
      {:noreply, assign(socket, draft: draft, saved: false)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("save_about", _params, socket), do: persist(socket, @about_attrs)
  def handle_event("save_contact", _params, socket), do: persist(socket, @contact_attrs)
  def handle_event("save_faq", _params, socket), do: persist(socket, @faq_attrs)
  def handle_event("save_policies", _params, socket), do: persist(socket, @policy_attrs)

  defp persist(socket, attr_keys) do
    actor = socket.assigns[:current_user] || socket.assigns[:current_merchant]
    attrs = clean_attrs(socket.assigns.draft, attr_keys)

    case Emakola.Stores.update_page_content(socket.assigns.content, attrs, actor: actor) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(content: updated, draft: build_draft(updated), saved: true)
         |> put_flash(:info, "Saved")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_page_header
        title="Store Pages"
        subtitle="Write the content shoppers see on your About, Contact, FAQ and Policies pages"
      />

      <div class="flex flex-col md:flex-row gap-6">
        <div class="md:w-56 shrink-0">
          <div class="flex md:flex-col gap-1 overflow-x-auto md:overflow-x-visible pb-2 md:pb-0">
            <.tab_button tab="about" active_tab={@active_tab} icon="hero-identification">
              About
            </.tab_button>
            <.tab_button tab="contact" active_tab={@active_tab} icon="hero-phone">
              Contact
            </.tab_button>
            <.tab_button tab="faq" active_tab={@active_tab} icon="hero-question-mark-circle">
              FAQ
            </.tab_button>
            <.tab_button tab="policies" active_tab={@active_tab} icon="hero-document-text">
              Policies
            </.tab_button>
          </div>
        </div>

        <div class="flex-1 min-w-0">
          <div :if={@active_tab == "about"}>
            <.admin_card>
              <h3 class="text-base font-bold text-slate-900 mb-5">About page</h3>
              <div class="space-y-5">
                <.text_field
                  field="about_headline"
                  label="Headline"
                  value={@draft["about_headline"]}
                  placeholder="About your store"
                />
                <.textarea_field
                  field="about_intro"
                  label="Intro"
                  value={@draft["about_intro"]}
                  rows={2}
                />
                <.textarea_field
                  field="about_story"
                  label="Your story"
                  value={@draft["about_story"]}
                  rows={5}
                />

                <div>
                  <p class="text-sm font-medium text-slate-700 mb-2">How it works (steps)</p>
                  <.row_editor
                    collection="about_steps"
                    rows={@draft["about_steps"]}
                    fields={[{"title", "Title"}, {"description", "Description"}]}
                    add_label="Add step"
                  />
                </div>

                <div>
                  <p class="text-sm font-medium text-slate-700 mb-2">Values</p>
                  <.row_editor
                    collection="about_values"
                    rows={@draft["about_values"]}
                    fields={[{"title", "Title"}, {"description", "Description"}]}
                    add_label="Add value"
                  />
                </div>

                <.text_field
                  field="about_cta_heading"
                  label="Call-to-action heading"
                  value={@draft["about_cta_heading"]}
                />
                <.textarea_field
                  field="about_cta_text"
                  label="Call-to-action text"
                  value={@draft["about_cta_text"]}
                  rows={2}
                />
              </div>
              <.save_bar target="save_about" saved={@saved} />
            </.admin_card>
          </div>

          <div :if={@active_tab == "contact"}>
            <.admin_card>
              <h3 class="text-base font-bold text-slate-900 mb-1">Contact page</h3>
              <p class="text-sm text-slate-500 mb-5">
                Email, phone, address and socials come from <.link
                  navigate={~p"/admin/settings"}
                  class="text-primary-hover hover:underline"
                >Settings</.link>. Add an extra note and your opening hours here.
              </p>
              <div class="space-y-5">
                <.textarea_field
                  field="contact_note"
                  label="Contact note"
                  value={@draft["contact_note"]}
                  rows={3}
                />
                <.text_field
                  field="contact_hours"
                  label="Opening hours"
                  value={@draft["contact_hours"]}
                  placeholder="Mon-Sat, 9am - 6pm"
                />
              </div>
              <.save_bar target="save_contact" saved={@saved} />
            </.admin_card>
          </div>

          <div :if={@active_tab == "faq"}>
            <.admin_card>
              <h3 class="text-base font-bold text-slate-900 mb-5">Frequently asked questions</h3>
              <.row_editor
                collection="faq_items"
                rows={@draft["faq_items"]}
                fields={[{"question", "Question"}, {"answer", "Answer"}]}
                add_label="Add question"
              />
              <.save_bar target="save_faq" saved={@saved} />
            </.admin_card>
          </div>

          <div :if={@active_tab == "policies"}>
            <.admin_card>
              <h3 class="text-base font-bold text-slate-900 mb-1">Policies</h3>
              <p class="text-sm text-slate-500 mb-5">
                Leave a section blank to show a sensible default shoppers can rely on.
              </p>
              <div class="space-y-5">
                <.textarea_field
                  field="shipping_returns"
                  label="Shipping & Returns"
                  value={@draft["shipping_returns"]}
                  rows={5}
                />
                <.textarea_field
                  field="privacy_policy"
                  label="Privacy Policy"
                  value={@draft["privacy_policy"]}
                  rows={5}
                />
                <.textarea_field
                  field="terms_of_service"
                  label="Terms of Service"
                  value={@draft["terms_of_service"]}
                  rows={5}
                />
              </div>
              <.save_bar target="save_policies" saved={@saved} />
            </.admin_card>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  attr :tab, :string, required: true
  attr :active_tab, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp tab_button(assigns) do
    ~H"""
    <button
      phx-click="switch_tab"
      phx-value-tab={@tab}
      class={[
        "flex items-center gap-2.5 px-4 py-2.5 rounded-control text-sm font-medium whitespace-nowrap cursor-pointer transition-all",
        if(@tab == @active_tab,
          do: "bg-primary-soft text-primary font-semibold",
          else: "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
        )
      ]}
    >
      <.icon name={@icon} class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""

  defp text_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">{@label}</label>
      <input
        type="text"
        name="value"
        value={@value}
        placeholder={@placeholder}
        phx-change="update_scalar"
        phx-value-field={@field}
        phx-debounce="300"
        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
      />
    </div>
    """
  end

  attr :field, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, default: ""
  attr :rows, :integer, default: 4

  defp textarea_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-slate-700 mb-1.5">{@label}</label>
      <textarea
        name="value"
        rows={@rows}
        phx-change="update_scalar"
        phx-value-field={@field}
        phx-debounce="300"
        class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all resize-none"
      >{@value}</textarea>
    </div>
    """
  end

  attr :collection, :string, required: true
  attr :rows, :list, required: true
  attr :fields, :list, required: true
  attr :add_label, :string, required: true

  defp row_editor(assigns) do
    ~H"""
    <div class="space-y-3">
      <div
        :for={{row, index} <- Enum.with_index(@rows)}
        class="rounded-control border border-slate-200 p-4 space-y-3"
      >
        <div :for={{key, label} <- @fields}>
          <label class="block text-xs font-medium text-slate-600 mb-1">{label}</label>
          <input
            type="text"
            name="value"
            value={row[key]}
            phx-change="update_item"
            phx-value-collection={@collection}
            phx-value-index={index}
            phx-value-field={key}
            phx-debounce="300"
            class="w-full px-3 py-2 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
          />
        </div>
        <button
          type="button"
          phx-click="remove_item"
          phx-value-collection={@collection}
          phx-value-index={index}
          class="text-xs font-medium text-red-600 hover:text-red-700"
        >
          Remove
        </button>
      </div>

      <button
        type="button"
        phx-click="add_item"
        phx-value-collection={@collection}
        class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-primary hover:bg-primary-soft rounded-control transition-colors"
      >
        <.icon name="hero-plus" class="size-4" /> {@add_label}
      </button>
    </div>
    """
  end

  attr :target, :string, required: true
  attr :saved, :boolean, default: false

  defp save_bar(assigns) do
    ~H"""
    <div class="flex items-center justify-end gap-3 pt-5 mt-5 border-t border-slate-100">
      <span :if={@saved} class="text-sm text-emerald-600 font-medium">Saved</span>
      <button
        type="button"
        phx-click={@target}
        class="inline-flex items-center gap-2 px-6 py-2.5 bg-primary hover:bg-primary-hover text-white rounded-control text-sm font-semibold transition-colors"
      >
        <.icon name="hero-check" class="size-4" /> Save Changes
      </button>
    </div>
    """
  end

  # ── Draft helpers ──

  defp build_draft(content) do
    %{
      "about_headline" => content.about_headline || "",
      "about_intro" => content.about_intro || "",
      "about_story" => content.about_story || "",
      "about_cta_heading" => content.about_cta_heading || "",
      "about_cta_text" => content.about_cta_text || "",
      "about_steps" => normalize_rows(content.about_steps, ["title", "description"]),
      "about_values" => normalize_rows(content.about_values, ["title", "description"]),
      "faq_items" => normalize_rows(content.faq_items, ["question", "answer"]),
      "shipping_returns" => content.shipping_returns || "",
      "privacy_policy" => content.privacy_policy || "",
      "terms_of_service" => content.terms_of_service || "",
      "contact_note" => content.contact_note || "",
      "contact_hours" => content.contact_hours || ""
    }
  end

  defp normalize_rows(rows, keys) do
    rows
    |> List.wrap()
    |> Enum.map(fn row ->
      Map.new(keys, fn key -> {key, to_string(Map.get(row, key, ""))} end)
    end)
  end

  # Builds the persist params for the given keys, dropping fully-blank list rows.
  defp clean_attrs(draft, keys) do
    Map.new(keys, fn key ->
      case Map.get(draft, key) do
        rows when is_list(rows) -> {key, clean_rows(rows)}
        scalar -> {key, scalar}
      end
    end)
  end

  defp clean_rows(rows) do
    Enum.reject(rows, fn row ->
      row |> Map.values() |> Enum.all?(&(String.trim(to_string(&1)) == ""))
    end)
  end
end
