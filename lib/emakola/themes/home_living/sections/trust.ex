defmodule Emakola.Themes.HomeLiving.Sections.Trust do
  @moduledoc """
  Home Living trust strip.

  The shipped items used to promise "Ships in 5 days — Across Ghana" and
  "30-day returns — No questions asked" on every Home Living storefront. The
  merchant wrote neither and could not remove either.

  The delivery item is now built from the store's OWN zones (see
  `Emakola.Themes.Delivery`) and, when the store has configured none, says
  nothing but points at the merchant's policies page. The returns item is back,
  but only for a merchant who has stated a window (see `Emakola.Themes.Terms`)
  — and it states theirs, not "30 days, no questions asked". Merchants who set
  their own `@theme.trust.items` still get theirs, unchanged.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path

  alias Emakola.Themes.Delivery
  alias Emakola.Themes.HomeLiving.Shared
  alias Emakola.Themes.Terms

  @impl true
  def key, do: "home_living/trust"
  @impl true
  def label, do: "Trust strip"

  @impl true
  def settings_schema, do: []

  @impl true
  def render(assigns) do
    items = trust_items(assigns)

    assigns =
      assigns
      |> assign(:items, items)
      # A store that has stated its returns terms earns a fourth tile; one that
      # has not keeps the three-up strip rather than a gap where a promise went.
      |> assign(
        :grid_class,
        if(length(items) > 3, do: "sm:grid-cols-2 lg:grid-cols-4", else: "sm:grid-cols-3")
      )

    ~H"""
    <section :if={Shared.section_enabled?(@theme, :trust)} class="bg-white py-12 sm:py-16">
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <div class={"grid grid-cols-1 gap-6 #{@grid_class}"}>
          <div :for={item <- @items} class="flex items-center gap-4">
            <div class="w-14 h-14 rounded-2xl bg-[#84CC16]/15 flex items-center justify-center flex-shrink-0">
              <span class="material-symbols-outlined text-[#1F2937]" style="font-size: 26px;">
                {item.icon}
              </span>
            </div>
            <div>
              <p class="text-base font-semibold text-[#1F2937] mb-0.5">{item.label}</p>
              <%!-- href is only ever a server-generated relative path (see
                   delivery_item/1); anything else renders as plain text, so a
                   merchant's own theme config can't turn this into a link. --%>
              <.maybe_link href={Map.get(item, :href)} label={item.subtitle} />
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :href, :any, default: nil
  attr :label, :string, default: nil

  defp maybe_link(assigns) do
    ~H"""
    <a
      :if={is_binary(@href) and String.starts_with?(@href, "/")}
      href={@href}
      class="text-xs text-[#4B5563] underline decoration-[#9CA3AF] underline-offset-2 hover:text-[#1F2937] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#84CC16] rounded"
    >
      {@label}
    </a>
    <p :if={not (is_binary(@href) and String.starts_with?(@href, "/"))} class="text-xs text-[#4B5563]">
      {@label}
    </p>
    """
  end

  defp trust_items(assigns) do
    case get_in(assigns.theme, [:trust, :items]) do
      items when is_list(items) and items != [] -> items
      _ -> default_trust(assigns)
    end
  end

  defp default_trust(assigns) do
    [
      %{icon: "category", label: "Quality materials", subtitle: "Solid wood, natural fibres"},
      delivery_item(assigns),
      terms_item(assigns),
      %{icon: "verified_user", label: "Secure payment", subtitle: "Mobile money & card"}
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Whatever the merchant has actually promised — "30-day returns", "1-year
  # warranty", or both — linked to the policies page that carries the detail.
  # `nil` when they have promised nothing, and then there is no tile at all.
  defp terms_item(assigns) do
    case Terms.badges(assigns) do
      [] ->
        nil

      badges ->
        %{
          icon: "assignment_return",
          label: Enum.join(badges, " · "),
          subtitle: "See this store's policies",
          href: store_path(assigns.store.slug, "/policies")
        }
    end
  end

  defp delivery_item(assigns) do
    zones = Delivery.zones(assigns)

    cond do
      line = Delivery.free_delivery_detail(zones, assigns.store.currency) ->
        %{icon: "local_shipping", label: "Free delivery", subtitle: line}

      estimate = Delivery.estimate(zones) ->
        %{icon: "local_shipping", label: estimate, subtitle: Delivery.zone_names(zones)}

      true ->
        %{
          icon: "local_shipping",
          label: "Delivery & returns",
          subtitle: "See this store's policies",
          href: store_path(assigns.store.slug, "/policies#shipping")
        }
    end
  end
end
