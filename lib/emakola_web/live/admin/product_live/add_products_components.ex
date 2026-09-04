defmodule EmakolaWeb.Admin.ProductLive.AddProductsComponents do
  @moduledoc """
  Function components for the one-door page (`AddProducts`).

  Sizes follow the approved canvas in `design/add-products-one-door`: on a
  phone the fields are 54px tall and the button 56px, because the merchant
  may not read well and the controls carry the meaning; on a desktop each
  card gets one 46px row, name beside price. Every event bubbles to the
  parent LiveView.
  """
  use EmakolaWeb, :html

  alias EmakolaWeb.Helpers.Currency

  # ── Header ──

  attr :stage, :atom, required: true, values: [:capture, :cards]
  attr :item_count, :integer, required: true

  def add_products_header(assigns) do
    ~H"""
    <div class="flex items-center gap-3 lg:gap-4 pt-2">
      <.link
        navigate={~p"/admin/products"}
        class="lg:hidden p-2 -ml-2 rounded-lg hover:bg-slate-100 transition-colors"
        aria-label="Back to products"
      >
        <.icon name="hero-arrow-left" class="size-5 text-slate-500" />
      </.link>
      <div class="hidden lg:flex w-14 h-14 rounded-card bg-primary items-center justify-center shrink-0 shadow-sm">
        <.icon name="hero-cube" class="size-7 text-white" />
      </div>
      <div class="flex-1 min-w-0">
        <h1 class="text-2xl lg:text-3xl font-bold tracking-tight text-text">
          {header_title(@stage, @item_count)}
        </h1>
        <p class="text-sm text-text-muted mt-0.5 lg:mt-1">{header_subtitle(@stage)}</p>
      </div>
      <.spreadsheet_link layout={:header} />
    </div>
    """
  end

  defp header_title(:capture, _count), do: "Add products"
  defp header_title(:cards, 1), do: "1 item"
  defp header_title(:cards, count), do: "#{count} items"

  defp header_subtitle(:capture), do: "Photo, name, price. The rest can wait."
  defp header_subtitle(:cards), do: "Give each a name and a price."

  # The spreadsheet stays one tap away, quietly: beside the title on a
  # desktop, under the tile on a phone. It opens the CSV sheet over the
  # Products list, where the imported products then appear.
  attr :layout, :atom, required: true, values: [:header, :stack]

  def spreadsheet_link(assigns) do
    ~H"""
    <.link
      :if={@layout == :header}
      navigate={~p"/admin/products?upload=csv"}
      class="hidden lg:inline-flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-semibold rounded-control border border-border bg-surface text-text hover:bg-surface-subtle transition-colors"
    >
      <.icon name="hero-arrow-up-tray" class="size-5 text-slate-500" /> Upload a spreadsheet
    </.link>
    <p
      :if={@layout == :stack}
      class="lg:hidden text-center text-[13.5px] font-semibold text-text-muted"
    >
      Have a spreadsheet?
      <.link
        navigate={~p"/admin/products?upload=csv"}
        class="text-primary-hover underline underline-offset-[3px]"
      >
        Upload it
      </.link>
    </p>
    """
  end

  # ── The one tile ──

  attr :uploads, :map, required: true
  attr :compact, :boolean, required: true, doc: "true once cards exist: a slim strip"
  attr :max_photos, :integer, required: true

  def capture_tiles(assigns) do
    ~H"""
    <%!-- A phone photo is 3 to 8 MB; on a market data plan thirty of them
          is the slowest thing on this page. The hook shrinks each picked
          photo to 1600px on the phone and hands the small files to
          LiveView, which then uploads as it always does. --%>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ShrinkPhotos">
      const MAX_EDGE = 1600

      async function decode(file) {
        try {
          return await createImageBitmap(file, { imageOrientation: "from-image" })
        } catch (_unsupportedOption) {
          return await createImageBitmap(file)
        }
      }

      async function shrink(file) {
        if (!file.type.startsWith("image/")) return file
        try {
          const bitmap = await decode(file)
          const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height))
          if (scale === 1 && file.type === "image/jpeg") {
            bitmap.close()
            return file
          }
          const canvas = document.createElement("canvas")
          canvas.width = Math.round(bitmap.width * scale)
          canvas.height = Math.round(bitmap.height * scale)
          canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
          bitmap.close()
          const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.85))
          if (!blob) return file
          const name = file.name.replace(/\.[^.]+$/, "") + ".jpg"
          return new File([blob], name, { type: "image/jpeg", lastModified: file.lastModified })
        } catch (_cannotDecode) {
          return file
        }
      }

      export default {
        // Mounted on the label, not the input: a dot-named hook is only
        // resolved on a plain tag in this template, and the input is
        // rendered by live_file_input.
        mounted() {
          const input = this.el.querySelector('input[type="file"]')
          if (!input) return
          // `this.upload` makes LiveView re-dispatch an input event on the
          // input, synchronously; the flag lets that one through and
          // catches every other change, whatever dispatched it.
          let passthrough = false
          const intercept = (event) => {
            if (passthrough) return
            if (!input.files || input.files.length === 0) return
            event.stopImmediatePropagation()
            const files = Array.from(input.files)
            // Clear the input so LiveView tracks only the shrunk files.
            input.value = ""
            Promise.all(files.map(shrink)).then((shrunk) => {
              passthrough = true
              try {
                this.upload(input.name, shrunk)
              } finally {
                passthrough = false
              }
            })
          }
          input.addEventListener("input", intercept, true)
          input.addEventListener("change", intercept, true)
        },
      }
    </script>
    <div class={[
      "grid gap-3 lg:gap-4",
      (@compact && "grid-cols-[1fr_auto]") || "grid-cols-1 lg:grid-cols-[2fr_1fr]"
    ]}>
      <%!-- One tile, two hit areas. The body opens the camera on a phone
            (a desktop browser ignores `capture` and shows its file picker);
            the small pill opens the photo library. --%>
      <div
        id="photo-tile"
        phx-drop-target={@uploads.photos.ref}
        class={[
          "relative rounded-2xl border-2 border-dashed border-emerald-300 bg-emerald-50/60 hover:border-emerald-400 transition-colors",
          (@compact && "h-[72px] lg:h-[110px]") || "h-[230px] lg:h-[110px]"
        ]}
      >
        <label
          id="camera-tile"
          phx-hook=".ShrinkPhotos"
          class={[
            "absolute inset-0 flex items-center justify-center cursor-pointer",
            (@compact && "flex-row gap-3 pl-3.5 pr-[120px] lg:pl-4 lg:gap-4") ||
              "flex-col gap-2.5 px-4 pb-6 lg:flex-row lg:gap-4 lg:pb-0 lg:pr-[140px]"
          ]}
        >
          <span class={[
            "flex items-center justify-center rounded-full shrink-0 bg-primary text-white shadow-lg shadow-emerald-600/30",
            (@compact && "w-11 h-11 lg:w-[52px] lg:h-[52px]") ||
              "w-[68px] h-[68px] lg:w-[52px] lg:h-[52px]"
          ]}>
            <.icon name="hero-camera" class={(@compact && "size-6") || "size-8 lg:size-6"} />
          </span>
          <span class={[
            "flex flex-col gap-0.5",
            (@compact && "items-start") || "items-center lg:items-start"
          ]}>
            <span class="text-lg font-extrabold text-text">
              {if @compact, do: "Add more", else: "Add photos"}
            </span>
            <span :if={!@compact} class="text-[13.5px] text-text-muted">
              <span class="lg:hidden">Take one, or choose up to {@max_photos}</span>
              <span class="hidden lg:inline">Drop them here, or choose up to {@max_photos}</span>
            </span>
          </span>
          <.live_file_input
            upload={@uploads.camera}
            capture="environment"
            class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </label>

        <label
          id="gallery-pill"
          phx-hook=".ShrinkPhotos"
          class={[
            "absolute right-3 inline-flex items-center gap-1.5 rounded-full border-[1.5px] border-border bg-white text-text font-bold shadow-sm cursor-pointer",
            (@compact && "top-1/2 -translate-y-1/2 h-9 px-3 text-[13px]") ||
              "bottom-3 h-10 px-3.5 text-[13.5px] lg:top-1/2 lg:bottom-auto lg:-translate-y-1/2"
          ]}
        >
          <.icon name="hero-photo" class="size-[18px] text-slate-500" /> Gallery
          <.live_file_input
            upload={@uploads.photos}
            class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
          />
        </label>
      </div>

      <%!-- Typing a product is a card without a photo, on this page. --%>
      <button
        id="typed-tile"
        type="button"
        phx-click="add_typed_card"
        class={[
          "rounded-2xl border-2 border-dashed border-slate-300 bg-white hover:border-emerald-400 transition-colors cursor-pointer items-center justify-center text-text",
          (@compact && "flex h-[72px] lg:h-[110px] px-4 gap-2.5 text-base font-bold") ||
            "hidden lg:flex h-[110px] gap-4"
        ]}
      >
        <span class={[
          "flex items-center justify-center rounded-full shrink-0 bg-slate-100 text-slate-500",
          (@compact && "w-11 h-11 lg:w-[52px] lg:h-[52px]") || "w-[52px] h-[52px]"
        ]}>
          <.icon name="hero-pencil" class="size-6" />
        </span>
        <span class="flex flex-col items-start gap-0.5">
          <span class="text-base font-bold text-text">Type it in</span>
          <span :if={!@compact} class="text-[13px] font-normal text-text-muted">No photo yet</span>
        </span>
      </button>
    </div>

    <div :if={!@compact} class="lg:hidden mt-4 flex flex-col gap-3">
      <div class="flex items-center gap-3 px-1">
        <div class="flex-1 h-px bg-border"></div>
        <span class="text-[13px] font-semibold text-slate-400">or</span>
        <div class="flex-1 h-px bg-border"></div>
      </div>
      <button
        id="typed-button"
        type="button"
        phx-click="add_typed_card"
        class="h-[54px] w-full rounded-[13px] border-2 border-border bg-surface text-text text-base font-bold inline-flex items-center justify-center gap-2 hover:bg-surface-subtle transition-colors cursor-pointer"
      >
        <.icon name="hero-pencil" class="size-5 text-slate-500" /> Type it in
      </button>
      <.spreadsheet_link layout={:stack} />
    </div>
    """
  end

  attr :uploads, :map, required: true

  def upload_problems(assigns) do
    ~H"""
    <p
      :for={error <- upload_errors(@uploads.camera) ++ upload_errors(@uploads.photos)}
      class="text-sm text-red-600 mt-2"
    >
      {upload_problem(error)}
    </p>
    """
  end

  def upload_problem(:too_large), do: "One photo is too large (max 10 MB)."
  def upload_problem(:not_accepted), do: "Only image files are accepted (.jpg, .png, .webp)."
  def upload_problem(:too_many_files), do: "Up to 30 photos at a time."
  def upload_problem(_error), do: "There was a problem with a photo."

  # ── One card per product ──

  attr :item, :map, required: true
  attr :number, :integer, required: true
  attr :currency, :string, required: true
  attr :last_price, :string, default: nil, doc: "offered to a card whose price is still empty"
  attr :categories, :list, required: true
  attr :ai_enabled, :boolean, required: true

  def photo_card(assigns) do
    assigns =
      assign(assigns, :offer_price, assigns.last_price && String.trim(assigns.item.price) == "")

    ~H"""
    <div
      id={"card-#{@item.key}"}
      data-state={@item.state}
      class={[
        "bg-white rounded-2xl overflow-hidden border-[1.5px] shadow-sm",
        @item.state == :ready && "border-primary",
        @item.state == :incomplete && "border-amber-400",
        @item.state == :untouched && "border-border"
      ]}
    >
      <div :if={@item.entry} class="relative h-[200px] lg:h-[170px] bg-slate-100">
        <.live_img_preview entry={@item.entry} class="w-full h-full object-cover" />
        <.remove_button item={@item} />
        <.card_badge state={@item.state} number={@number} />
        <div
          :if={@item.entry.progress < 100}
          class="absolute bottom-0 left-0 right-0 h-1 bg-slate-200"
        >
          <div class="h-full bg-emerald-500" style={"width: #{@item.entry.progress}%"}></div>
        </div>
      </div>
      <%!-- A typed product: the same card, with the photo slot empty. A
            photo can be added on the product's edit page later. --%>
      <div
        :if={is_nil(@item.entry)}
        class="relative mx-3.5 mt-3.5 lg:mx-3 lg:mt-3 h-[120px] lg:h-[110px] rounded-xl border-2 border-dashed border-slate-300 bg-surface-subtle flex flex-col items-center justify-center gap-1.5"
      >
        <.icon name="hero-camera" class="size-[26px] text-slate-400" />
        <span class="text-[13.5px] font-bold text-text-muted">No photo yet</span>
        <.remove_button item={@item} />
        <.card_badge state={@item.state} number={@number} />
      </div>

      <div class="p-3.5 pb-4 flex flex-col gap-2.5 lg:flex-row lg:gap-2 lg:p-3">
        <div class="flex-1 min-w-0">
          <input
            type="text"
            name="card_name"
            id={"card-name-#{@item.key}"}
            value={@item.name}
            phx-blur="set_card"
            phx-value-upload={@item.upload}
            phx-value-ref={@item.ref}
            phx-value-field="name"
            placeholder="What is it? e.g. Oraimo FreePods 3 earbuds"
            data-missing={@item.missing_name? || nil}
            class={card_field_classes(@item.missing_name?)}
          />
        </div>
        <div class="relative lg:w-[150px] lg:shrink-0">
          <span class="absolute left-4 lg:left-3 inset-y-0 flex items-center text-[17px] lg:text-[14.5px] font-bold text-text-muted pointer-events-none">
            {Currency.currency_symbol(@currency)}
          </span>
          <input
            type="text"
            inputmode="decimal"
            name="card_price"
            id={"card-price-#{@item.key}"}
            value={@item.price}
            phx-blur="set_card"
            phx-value-upload={@item.upload}
            phx-value-ref={@item.ref}
            phx-value-field="price"
            placeholder="How much?"
            data-missing={@item.missing_price? || nil}
            class={[card_field_classes(@item.missing_price?), "pl-[66px] lg:pl-[52px]"]}
          />
        </div>
      </div>
      <div :if={@offer_price} class="px-3.5 pb-3.5 lg:px-3 lg:pb-3 -mt-1">
        <button
          type="button"
          phx-click="copy_price"
          phx-value-upload={@item.upload}
          phx-value-ref={@item.ref}
          phx-value-price={@last_price}
          data-last-price={@last_price}
          class="inline-flex items-center gap-1.5 h-9 px-3.5 rounded-full border border-border bg-white hover:bg-surface-subtle text-[13.5px] font-bold text-text cursor-pointer transition-colors"
        >
          <.icon name="hero-clock" class="size-4 text-slate-500" />
          Same as last: {Currency.currency_symbol(@currency)} {@last_price}
        </button>
      </div>
      <p :for={problem <- @item.problems} class="px-3.5 pb-3 text-xs text-red-600">{problem}</p>
      <.more_row item={@item} categories={@categories} ai_enabled={@ai_enabled} />
    </div>
    """
  end

  # More, inside the card: a category and a description, opening in place.
  # Two things, not nine; everything else waits for the edit page.
  attr :item, :map, required: true
  attr :categories, :list, required: true
  attr :ai_enabled, :boolean, required: true

  defp more_row(assigns) do
    ~H"""
    <button
      type="button"
      id={"more-#{@item.key}"}
      phx-click="toggle_more"
      phx-value-upload={@item.upload}
      phx-value-ref={@item.ref}
      class="w-full h-11 border-t border-slate-100 px-3.5 lg:px-3 flex items-center justify-between cursor-pointer"
    >
      <span class={[
        "flex items-center gap-2 text-[14.5px] font-bold",
        (@item.open? && "text-text") || "text-text-muted"
      ]}>
        <.icon name="hero-bars-3-bottom-left" class="size-[18px]" /> More
        <span
          :if={!@item.open? and @item.category_name}
          class="ml-0.5 px-2.5 py-0.5 rounded-full bg-primary-soft text-primary-hover text-[12.5px] font-bold"
        >
          {@item.category_name}
        </span>
      </span>
      <.icon
        name={(@item.open? && "hero-chevron-up") || "hero-chevron-down"}
        class="size-[18px] text-slate-400"
      />
    </button>
    <div :if={@item.open?} class="px-3.5 pb-4 lg:px-3 lg:pb-3.5 flex flex-col gap-3.5">
      <div :if={@categories != []} class="flex flex-col gap-2">
        <span class="text-[11.5px] font-extrabold uppercase tracking-[0.1em] text-slate-400">
          Category
        </span>
        <div class="flex flex-wrap gap-2">
          <button
            :for={category <- @categories}
            type="button"
            phx-click="set_card"
            phx-value-upload={@item.upload}
            phx-value-ref={@item.ref}
            phx-value-field="category_id"
            phx-value-value={(@item.category_id == category.id && "") || category.id}
            data-category={category.id}
            data-on={(@item.category_id == category.id && "true") || nil}
            class={[
              "h-[42px] lg:h-9 px-4 lg:px-3.5 rounded-full border-[1.5px] text-[14.5px] lg:text-[13.5px] font-bold inline-flex items-center gap-1.5 cursor-pointer transition-colors",
              (@item.category_id == category.id &&
                 "border-primary bg-primary-soft text-primary-hover") ||
                "border-border bg-white text-text hover:bg-surface-subtle"
            ]}
          >
            <.icon :if={@item.category_id == category.id} name="hero-check" class="size-4" />
            {category.name}
          </button>
        </div>
      </div>
      <div class="flex flex-col gap-2">
        <span class="text-[11.5px] font-extrabold uppercase tracking-[0.1em] text-slate-400">
          Description
        </span>
        <textarea
          name="card_description"
          id={"card-description-#{@item.key}"}
          rows="3"
          phx-blur="set_card"
          phx-value-upload={@item.upload}
          phx-value-ref={@item.ref}
          phx-value-field="description"
          placeholder={(@ai_enabled && "Leave it, Makola writes one") || "Say more about it"}
          class="w-full min-h-24 lg:min-h-[84px] rounded-[13px] lg:rounded-[11px] border-2 border-border bg-white px-4 py-3 lg:px-3 text-base lg:text-[14.5px] font-medium text-text placeholder:text-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10 resize-none"
        >{@item.description}</textarea>
      </div>
    </div>
    """
  end

  defp card_field_classes(missing?) do
    [
      "w-full h-[54px] lg:h-[46px] rounded-[13px] lg:rounded-[11px] border-2 px-4 lg:px-3",
      "text-[17px] lg:text-[15.5px] font-semibold text-text placeholder:text-slate-400 placeholder:font-medium",
      "focus:outline-none focus:border-emerald-500 focus:ring-4 focus:ring-emerald-500/10",
      (missing? && "border-amber-400 bg-amber-50") || "border-border bg-white"
    ]
  end

  attr :item, :map, required: true

  defp remove_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="remove_photo"
      phx-value-upload={@item.upload}
      phx-value-ref={@item.ref}
      aria-label="Remove"
      class="absolute top-2.5 left-2.5 w-[30px] h-[30px] rounded-full bg-black/55 text-white flex items-center justify-center cursor-pointer"
    >
      <.icon name="hero-x-mark" class="size-3.5" />
    </button>
    """
  end

  # Green tick, amber mark, or the card's number: the state without words.
  attr :state, :atom, required: true
  attr :number, :integer, required: true

  defp card_badge(assigns) do
    ~H"""
    <div class={[
      "absolute top-2.5 right-2.5 w-[30px] h-[30px] rounded-full flex items-center justify-center shadow",
      @state == :ready && "bg-primary text-white",
      @state == :incomplete && "bg-amber-400 text-white",
      @state == :untouched && "bg-slate-900/60 text-white text-[13px] font-extrabold tabular-nums"
    ]}>
      <.icon :if={@state == :ready} name="hero-check" class="size-4" />
      <.icon :if={@state == :incomplete} name="hero-exclamation-circle" class="size-5" />
      <span :if={@state == :untouched}>{@number}</span>
    </div>
    """
  end

  # ── Publish bar ──

  attr :ready, :integer, required: true
  attr :remaining, :integer, required: true
  attr :publishing, :boolean, required: true
  attr :uploading?, :boolean, required: true

  def publish_bar(assigns) do
    ~H"""
    <div class="sticky bottom-0 z-10 -mx-4 sm:-mx-6 lg:-mx-8 -mb-4 sm:-mb-6 lg:-mb-8 mt-5 px-4 sm:px-6 lg:px-8 py-3 lg:py-4 bg-white/95 backdrop-blur border-t border-border flex flex-col gap-2 lg:flex-row lg:items-center lg:justify-between">
      <p
        :if={@remaining > 0}
        class="order-2 lg:order-1 text-center lg:text-left text-[13.5px] lg:text-[15px] font-medium text-text-muted"
      >
        {remaining_hint(@remaining)}
      </p>
      <button
        id="publish-button"
        type="submit"
        disabled={@publishing or @uploading? or @ready == 0}
        class="order-1 lg:order-2 lg:ml-auto w-full lg:w-[280px] h-14 rounded-[13px] bg-primary hover:bg-primary-hover text-white text-[16.5px] font-extrabold shadow-lg shadow-emerald-600/30 disabled:opacity-50 disabled:shadow-none disabled:cursor-not-allowed flex items-center justify-center gap-2.5 cursor-pointer transition-colors"
      >
        <.icon name="hero-building-storefront" class="size-[22px]" />
        {if @publishing, do: "Publishing…", else: "Put #{@ready} in shop"}
      </button>
    </div>
    """
  end

  defp remaining_hint(1), do: "1 more needs a name or price"
  defp remaining_hint(count), do: "#{count} more need a name or price"

  # ── Done: the products as buyers see them ──

  attr :published, :list, required: true
  attr :currency, :string, required: true
  attr :shop_url, :string, required: true

  def done_screen(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto flex flex-col items-center gap-4 pt-4 lg:pt-10 text-center">
      <div class="w-20 h-20 rounded-full bg-primary-soft border-[3px] border-emerald-200 flex items-center justify-center">
        <.icon name="hero-check" class="size-10 text-primary" />
      </div>
      <div>
        <h1 class="text-[26px] font-extrabold tracking-tight text-text">
          {length(@published)} in your shop
        </h1>
        <p class="text-[15px] text-text-muted mt-1">Buyers can see them now.</p>
      </div>

      <div class="w-full grid grid-cols-2 lg:grid-cols-4 gap-3 mt-1">
        <div
          :for={product <- @published}
          class="bg-white border border-border rounded-[14px] overflow-hidden text-left"
        >
          <div class="h-32 lg:h-40 bg-slate-100 flex items-center justify-center">
            <img
              :if={product.image_url}
              src={product.image_url}
              alt=""
              class="w-full h-full object-cover"
            />
            <.icon :if={is_nil(product.image_url)} name="hero-camera" class="size-8 text-slate-300" />
          </div>
          <div class="px-3 py-2.5">
            <div class="text-[13.5px] font-bold text-text truncate">{product.title}</div>
            <div class="text-[15px] font-extrabold text-text mt-0.5 tabular-nums">
              {Currency.format_price(product.price, @currency)}
            </div>
          </div>
        </div>
      </div>

      <div class="w-full flex flex-col gap-2.5 mt-2 lg:flex-row lg:justify-center">
        <a
          href={@shop_url}
          target="_blank"
          rel="noopener"
          class="h-14 lg:w-[260px] rounded-[13px] bg-primary hover:bg-primary-hover text-white text-[16.5px] font-extrabold shadow-lg shadow-emerald-600/30 flex items-center justify-center gap-2.5 transition-colors"
        >
          <.icon name="hero-building-storefront" class="size-[22px]" /> See my shop
        </a>
        <button
          type="button"
          phx-click="add_more"
          class="h-[54px] lg:w-[220px] rounded-[13px] border-2 border-border bg-white hover:bg-surface-subtle text-text text-base font-bold flex items-center justify-center gap-2 cursor-pointer transition-colors"
        >
          <.icon name="hero-camera" class="size-5 text-slate-500" /> Add more
        </button>
      </div>
    </div>
    """
  end
end
