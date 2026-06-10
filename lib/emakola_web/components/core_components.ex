defmodule EmakolaWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: EmakolaWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-hook="AutoDismiss"
      role="alert"
      class="animate-slide-in-right"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 w-80 sm:w-96 p-4 rounded-xl bg-white glass-effect editorial-shadow text-slate-900",
        @kind == :info && "border-l-4 border-emerald-600",
        @kind == :error && "border-l-4 border-red-600"
      ]}>
        <span :if={@kind == :info} class="material-symbols-outlined text-emerald-600 text-xl shrink-0">
          info
        </span>
        <span :if={@kind == :error} class="material-symbols-outlined text-red-600 text-xl shrink-0">
          error
        </span>
        <div class="flex-1 min-w-0">
          <p :if={@title} class="text-sm font-semibold text-slate-900">{@title}</p>
          <p class="text-sm text-slate-500">{msg}</p>
        </div>
        <button
          type="button"
          class="shrink-0 p-1 text-slate-500 hover:text-slate-900 transition-colors rounded-lg hover:bg-slate-200 cursor-pointer"
          aria-label={gettext("close")}
          phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label for={@id}>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-red-600">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a modal dialog.

  Supports centered modals (default) and slide-over panels from the right.

  ## Examples

      <.modal id="add-category-modal" title="Add Category">
        <form>...</form>
      </.modal>

      <.modal id="edit-customer" title="Edit Customer" kind={:slide_over}>
        <form>...</form>
      </.modal>

  Trigger with:

      <button phx-click={show_modal("add-category-modal")}>Open</button>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :kind, :atom, default: :centered, values: [:centered, :slide_over]
  attr :size, :atom, default: :md, values: [:sm, :md, :lg, :xl]
  attr :on_cancel, JS, default: %JS{}
  attr :icon, :string, default: nil
  attr :icon_class, :string, default: "text-slate-500"

  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@kind == :centered && JS.hide(to: "##{@id}")}
      phx-remove={hide_modal(@id)}
      class="hidden relative z-50"
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
    >
      <%!-- Backdrop --%>
      <div
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-black/50 backdrop-blur-sm transition-opacity"
        aria-hidden="true"
      />

      <div
        class={[
          "fixed inset-0 overflow-y-auto",
          @kind == :slide_over && "flex justify-end"
        ]}
        aria-labelledby={"#{@id}-title"}
        role="dialog"
        aria-modal="true"
        phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
        phx-key="escape"
        phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
      >
        <%= if @kind == :slide_over do %>
          <%!-- Slide-over panel --%>
          <div
            id={"#{@id}-container"}
            class="w-full max-w-[480px] h-full bg-white shadow-xl flex flex-col
                   sm:max-w-[480px] max-sm:max-w-full"
          >
            <%!-- Header --%>
            <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200">
              <div class="flex items-center gap-3">
                <span :if={@icon} class={["material-symbols-outlined text-xl", @icon_class]}>
                  {@icon}
                </span>
                <h2 id={"#{@id}-title"} class="text-lg font-semibold text-slate-900">{@title}</h2>
              </div>
              <button
                phx-click={JS.exec("data-cancel", to: "##{@id}")}
                type="button"
                class="p-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors"
                aria-label={gettext("close")}
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>
            <%!-- Body --%>
            <div class="flex-1 overflow-y-auto px-6 py-5">
              {render_slot(@inner_block)}
            </div>
            <%!-- Footer --%>
            <div :if={@footer != []} class="px-6 py-4 border-t border-slate-200 bg-slate-50">
              {render_slot(@footer)}
            </div>
          </div>
        <% else %>
          <%!-- Centered modal --%>
          <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
            <div
              id={"#{@id}-container"}
              class={[
                "w-full bg-white rounded-2xl shadow-xl max-sm:max-w-full",
                modal_size_class(@size)
              ]}
            >
              <%!-- Header --%>
              <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200">
                <div class="flex items-center gap-3">
                  <span :if={@icon} class={["material-symbols-outlined text-xl", @icon_class]}>
                    {@icon}
                  </span>
                  <h2 id={"#{@id}-title"} class="text-lg font-semibold text-slate-900">{@title}</h2>
                </div>
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="p-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark" class="size-5" />
                </button>
              </div>
              <%!-- Body --%>
              <div class="px-6 py-5">
                {render_slot(@inner_block)}
              </div>
              <%!-- Footer --%>
              <div
                :if={@footer != []}
                class="px-6 py-4 border-t border-slate-200 bg-slate-50 rounded-b-2xl"
              >
                {render_slot(@footer)}
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a reusable confirmation modal for destructive or important actions.

  ## Examples

      <.confirm_modal
        id="delete-zone-123"
        title="Delete Delivery Zone"
        message="This will remove the delivery zone. This action cannot be undone."
        confirm_text="Delete"
        confirm_class="bg-red-600 hover:bg-red-700 text-white"
        on_confirm="delete_zone"
        value={zone.id}
      />

  Trigger with:

      <button phx-click={show_modal("delete-zone-123")}>Delete</button>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :confirm_text, :string, default: "Confirm"
  attr :cancel_text, :string, default: "Cancel"
  attr :confirm_class, :string, default: "bg-emerald-600 hover:bg-emerald-700 text-white"
  attr :on_confirm, :string, required: true
  attr :value, :any, default: nil
  attr :icon, :string, default: nil
  attr :icon_class, :string, default: "text-amber-500"

  def confirm_modal(assigns) do
    ~H"""
    <.modal id={@id} title={@title} size={:sm} icon={@icon} icon_class={@icon_class}>
      <p class="text-sm text-slate-600">{@message}</p>
      <:footer>
        <div class="flex items-center justify-end gap-3">
          <button
            type="button"
            phx-click={hide_modal(@id)}
            class="px-4 py-2.5 text-sm font-medium text-slate-700 bg-white border border-slate-300
                   rounded-xl hover:bg-slate-50 transition-colors"
          >
            {@cancel_text}
          </button>
          <button
            type="button"
            phx-click={JS.push(@on_confirm, value: %{id: @value}) |> hide_modal(@id)}
            class={["px-4 py-2.5 text-sm font-semibold rounded-xl transition-colors", @confirm_class]}
          >
            {@confirm_text}
          </button>
        </div>
      </:footer>
    </.modal>
    """
  end

  defp modal_size_class(:sm), do: "max-w-md"
  defp modal_size_class(:md), do: "max-w-lg"
  defp modal_size_class(:lg), do: "max-w-2xl"
  defp modal_size_class(:xl), do: "max-w-4xl"

  ## JS Commands

  @doc """
  Shows a modal by id using JS commands.
  """
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end

  @doc """
  Hides a modal by id using JS commands.
  """
  def hide_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      time: 200,
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"}, time: 200)
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(EmakolaWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(EmakolaWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  A reusable, premium footer for all public-facing pages.
  """
  def public_footer(assigns) do
    ~H"""
    <footer class="py-16 px-6 border-t border-slate-300/10 bg-slate-50">
      <div class="max-w-7xl mx-auto">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-8 mb-12">
          <%!-- Product --%>
          <div>
            <h4 class="text-sm font-semibold font-headline text-slate-900 mb-4">Product</h4>
            <ul class="space-y-2.5 text-sm text-slate-500">
              <li>
                <a href="/#features" class="hover:text-slate-900 transition-colors">Features</a>
              </li>
              <li><a href="/#pricing" class="hover:text-slate-900 transition-colors">Pricing</a></li>
              <li>
                <a href="/dashboard" class="hover:text-slate-900 transition-colors">Dashboard</a>
              </li>
              <li><a href="/agents" class="hover:text-slate-900 transition-colors">AI Agents</a></li>
            </ul>
          </div>

          <%!-- Resources --%>
          <div>
            <h4 class="text-sm font-semibold font-headline text-slate-900 mb-4">Resources</h4>
            <ul class="space-y-2.5 text-sm text-slate-500">
              <li>
                <a
                  href="/docs"
                  class="hover:text-slate-900 transition-colors"
                >
                  Documentation
                </a>
              </li>
              <li>
                <a
                  href="/docs/changelog"
                  class="hover:text-slate-900 transition-colors"
                >
                  Changelog
                </a>
              </li>
              <li>
                <a href="/docs/api" class="hover:text-slate-900 transition-colors">
                  API Reference
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/kojjob/founder-pad"
                  target="_blank"
                  class="hover:text-slate-900 transition-colors"
                >
                  GitHub
                </a>
              </li>
            </ul>
          </div>

          <%!-- Company --%>
          <div>
            <h4 class="text-sm font-semibold font-headline text-slate-900 mb-4">Company</h4>
            <ul class="space-y-2.5 text-sm text-slate-500">
              <li><a href="/" class="hover:text-slate-900 transition-colors">About</a></li>
              <li>
                <a href="/docs/changelog" class="hover:text-slate-900 transition-colors">Blog</a>
              </li>
              <li>
                <a href="mailto:careers@founderpad.io" class="hover:text-slate-900 transition-colors">
                  Careers
                </a>
              </li>
              <li>
                <a href="mailto:support@founderpad.io" class="hover:text-slate-900 transition-colors">
                  Contact
                </a>
              </li>
            </ul>
          </div>

          <%!-- Legal --%>
          <div>
            <h4 class="text-sm font-semibold font-headline text-slate-900 mb-4">Legal</h4>
            <ul class="space-y-2.5 text-sm text-slate-500">
              <li>
                <a href="/docs" class="hover:text-slate-900 transition-colors">Privacy Policy</a>
              </li>
              <li>
                <a href="/docs" class="hover:text-slate-900 transition-colors">Terms of Service</a>
              </li>
              <li>
                <a href="/docs" class="hover:text-slate-900 transition-colors">Cookie Policy</a>
              </li>
            </ul>
          </div>
        </div>

        <%!-- Bottom bar --%>
        <div class="pt-8 border-t border-slate-300/10 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div class="flex items-center gap-2.5">
            <div class="w-6 h-6 rounded-md bg-emerald-600 flex items-center justify-center">
              <span class="material-symbols-outlined text-white text-sm">architecture</span>
            </div>
            <span class="text-xs font-mono text-slate-500">
              &copy; {DateTime.utc_now().year} Emakola. All rights reserved.
            </span>
          </div>
          <div class="flex items-center gap-4">
            <a
              href="https://github.com/kojjob/founder-pad"
              target="_blank"
              class="text-slate-500 hover:text-slate-900 transition-colors"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12Z" />
              </svg>
            </a>
            <a
              href="https://twitter.com/founderpad"
              target="_blank"
              class="text-slate-500 hover:text-slate-900 transition-colors"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
              </svg>
            </a>
            <a
              href="https://discord.gg/founderpad"
              target="_blank"
              class="text-slate-500 hover:text-slate-900 transition-colors"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028 14.09 14.09 0 0 0 1.226-1.994.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03zM8.02 15.33c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.956-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.956 2.418-2.157 2.418zm7.975 0c-1.183 0-2.157-1.085-2.157-2.419 0-1.333.955-2.419 2.157-2.419 1.21 0 2.176 1.096 2.157 2.42 0 1.333-.946 2.418-2.157 2.418z" />
              </svg>
            </a>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
