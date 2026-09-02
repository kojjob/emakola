defmodule EmakolaWeb.Admin.ProductLive.AddProductsComponents do
  @moduledoc """
  Function components for the photo-cards page (`AddProducts`).

  Sizes follow the approved canvas in `design/add-products`: on a phone the
  fields are 54px tall and the button 56px, because the merchant may not read
  well and the controls carry the meaning; on a desktop each card gets one
  46px row, name beside price. Every event bubbles to the parent LiveView.
  """
  use EmakolaWeb, :html

  alias EmakolaWeb.Helpers.Currency

  # ── Header ──

  attr :stage, :atom, required: true, values: [:capture, :cards]
  attr :photo_count, :integer, required: true

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
          {header_title(@stage, @photo_count)}
        </h1>
        <p class="text-sm text-text-muted mt-0.5 lg:mt-1">{header_subtitle(@stage)}</p>
      </div>
      <.entry_links layout={:header} />
    </div>
    """
  end

  defp header_title(:capture, _count), do: "Add products"
  defp header_title(:cards, 1), do: "1 photo"
  defp header_title(:cards, count), do: "#{count} photos"

  defp header_subtitle(:capture), do: "Photo first. Name and price after."
  defp header_subtitle(:cards), do: "Give each a name and a price."

  # The typed form and the CSV upload stay one tap away, quietly: beside the
  # title on a desktop, under the camera on a phone.
  attr :layout, :atom, required: true, values: [:header, :stack]

  def entry_links(assigns) do
    ~H"""
    <div :if={@layout == :header} class="hidden lg:flex items-center gap-3">
      <.entry_link navigate={~p"/admin/products/new/form"} icon="hero-pencil" size={:sm}>
        Type it in
      </.entry_link>
      <.entry_link navigate={~p"/admin/products?upload=csv"} icon="hero-arrow-up-tray" size={:sm}>
        Upload a file
      </.entry_link>
    </div>
    <div :if={@layout == :stack} class="lg:hidden mt-4">
      <div class="flex items-center gap-3 px-1 mb-3">
        <div class="flex-1 h-px bg-border"></div>
        <span class="text-[13px] font-semibold text-slate-400">or</span>
        <div class="flex-1 h-px bg-border"></div>
      </div>
      <div class="grid grid-cols-2 gap-2.5">
        <.entry_link navigate={~p"/admin/products/new/form"} icon="hero-pencil" size={:lg}>
          Type it in
        </.entry_link>
        <.entry_link navigate={~p"/admin/products?upload=csv"} icon="hero-arrow-up-tray" size={:lg}>
          Upload a file
        </.entry_link>
      </div>
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :size, :atom, required: true, values: [:sm, :lg]
  slot :inner_block, required: true

  defp entry_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "inline-flex items-center justify-center gap-2 border-border bg-surface text-text",
        "hover:bg-surface-subtle transition-colors",
        @size == :sm && "px-4 py-2.5 text-sm font-semibold rounded-control border",
        @size == :lg && "h-[54px] text-base font-bold rounded-[13px] border-2"
      ]}
    >
      <.icon name={@icon} class="size-5 text-slate-500" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  # ── Capture tiles ──

  attr :uploads, :map, required: true
  attr :compact, :boolean, required: true, doc: "true once cards exist: a slim strip"
  attr :max_photos, :integer, required: true

  def capture_tiles(assigns) do
    ~H"""
    <div class={["grid gap-3 lg:gap-4", (@compact && "grid-cols-2") || "grid-cols-1 lg:grid-cols-2"]}>
      <label class={tile_classes(:primary, @compact)} phx-drop-target={@uploads.camera.ref}>
        <span class={disc_classes(:primary, @compact)}>
          <.icon name="hero-camera" class={(@compact && "size-6") || "size-8 lg:size-6"} />
        </span>
        <span class={tile_text_classes(@compact)}>
          <span class={["font-extrabold text-text", (@compact && "text-base lg:text-lg") || "text-lg"]}>
            Take a photo
          </span>
          <span :if={!@compact} class="text-[13.5px] text-text-muted">One item, one photo</span>
        </span>
        <.live_file_input
          upload={@uploads.camera}
          capture="environment"
          class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
        />
      </label>

      <label class={tile_classes(:quiet, @compact)} phx-drop-target={@uploads.photos.ref}>
        <span class={disc_classes(:quiet, @compact)}>
          <.icon name="hero-photo" class="size-6" />
        </span>
        <span class={tile_text_classes(@compact)}>
          <span class="text-base font-bold text-text">Choose photos</span>
          <span :if={!@compact} class="text-[13px] text-text-muted">Up to {@max_photos} at once</span>
        </span>
        <.live_file_input
          upload={@uploads.photos}
          class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
        />
      </label>
    </div>
    """
  end

  defp tile_classes(tone, compact) do
    [
      "relative flex items-center justify-center rounded-2xl border-2 border-dashed cursor-pointer transition-colors px-4",
      tone == :primary && "border-emerald-300 bg-emerald-50/60 hover:border-emerald-400",
      tone == :quiet && "border-slate-300 bg-white hover:border-emerald-400",
      compact && "flex-row gap-3 h-[72px] lg:h-[110px] lg:gap-4",
      !compact && tone == :primary &&
        "flex-col gap-2.5 h-[230px] lg:flex-row lg:gap-4 lg:h-[110px]",
      !compact && tone == :quiet && "flex-col gap-2 h-[140px] lg:flex-row lg:gap-4 lg:h-[110px]"
    ]
  end

  defp disc_classes(tone, compact) do
    [
      "flex items-center justify-center rounded-full shrink-0",
      tone == :primary && "bg-primary text-white shadow-lg shadow-emerald-600/30",
      tone == :quiet && "bg-slate-100 text-slate-500",
      compact && "w-11 h-11 lg:w-[52px] lg:h-[52px]",
      !compact && tone == :primary && "w-[68px] h-[68px] lg:w-[52px] lg:h-[52px]",
      !compact && tone == :quiet && "w-14 h-14 lg:w-[52px] lg:h-[52px]"
    ]
  end

  defp tile_text_classes(compact) do
    ["flex flex-col gap-0.5", (compact && "items-start") || "items-center lg:items-start"]
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

  # ── One card per photo ──

  attr :item, :map, required: true
  attr :number, :integer, required: true
  attr :currency, :string, required: true

  def photo_card(assigns) do
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
      <div class="relative h-[200px] lg:h-[170px] bg-slate-100">
        <.live_img_preview entry={@item.entry} class="w-full h-full object-cover" />
        <button
          type="button"
          phx-click="remove_photo"
          phx-value-upload={@item.upload}
          phx-value-ref={@item.ref}
          aria-label="Remove photo"
          class="absolute top-2.5 left-2.5 w-[30px] h-[30px] rounded-full bg-black/55 text-white flex items-center justify-center cursor-pointer"
        >
          <.icon name="hero-x-mark" class="size-3.5" />
        </button>
        <.card_badge state={@item.state} number={@number} />
        <div
          :if={@item.entry.progress < 100}
          class="absolute bottom-0 left-0 right-0 h-1 bg-slate-200"
        >
          <div class="h-full bg-emerald-500" style={"width: #{@item.entry.progress}%"}></div>
        </div>
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
            placeholder="What is it?"
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
      <p :for={problem <- @item.problems} class="px-3.5 pb-3 text-xs text-red-600">{problem}</p>
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
          <div class="h-32 lg:h-40 bg-slate-100">
            <img
              :if={product.image_url}
              src={product.image_url}
              alt=""
              class="w-full h-full object-cover"
            />
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
