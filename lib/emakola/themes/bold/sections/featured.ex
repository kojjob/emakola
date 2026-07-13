defmodule Emakola.Themes.Bold.Sections.Featured do
  @moduledoc """
  Bold home featured block — asymmetric bento grid, one large hero card and
  two stacked cards — extracted verbatim from bold/home.ex.

  The three products were precomputed in `Home.render/1` before the retrofit
  (`Enum.take(@products, 3)`); the section derives its own slice now.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  import EmakolaWeb.Storefront.Path
  import EmakolaWeb.StorefrontComponents, only: [optimized_image: 1]

  alias Emakola.Themes.Bold.Shared
  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "bold/featured"
  @impl true
  def label, do: "Featured"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: ""}]
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:featured_products, Enum.take(assigns[:products] || [], 3))
      |> assign(:heading, heading(assigns[:settings] || %{}))

    ~H"""
    <section
      :if={Shared.section_enabled?(@theme, :featured) and @featured_products != []}
      class="py-12 sm:py-16 bg-[#F8FAFC]"
    >
      <div class="max-w-[1280px] mx-auto px-4 sm:px-6 lg:px-8">
        <h2
          class="text-xs font-bold tracking-[0.2em] uppercase text-[#64748B] mb-8"
          style="font-family: 'Outfit', sans-serif;"
        >
          {@heading}
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6">
          <%!-- Large hero card --%>
          <%= if Enum.at(@featured_products, 0) do %>
            <% product = Enum.at(@featured_products, 0) %>
            <a
              href={store_path(@store.slug, "/products/#{product.slug}")}
              class="group block md:row-span-2"
            >
              <div class="relative overflow-hidden bg-[#F1F5F9] h-full min-h-[400px] md:min-h-0">
                <.optimized_image
                  :if={Shared.first_image(product)}
                  src={Shared.first_image(product)}
                  alt={product.title}
                  priority={:high}
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-700"
                />
                <div
                  :if={!Shared.first_image(product)}
                  class="w-full h-full flex items-center justify-center min-h-[400px]"
                >
                  <svg
                    class="w-16 h-16 text-[#94A3B8]"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="1"
                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                    />
                  </svg>
                </div>
                <div class="absolute bottom-0 left-0 right-0 p-6 sm:p-8 bg-gradient-to-t from-[#0F172A]/80 via-[#0F172A]/40 to-transparent">
                  <h3
                    class="text-xl sm:text-2xl font-bold text-white mb-1"
                    style="font-family: 'Outfit', sans-serif;"
                  >
                    {product.title}
                  </h3>
                  <p class="text-sm text-white/70" style="font-family: 'Inter', sans-serif;">
                    {Currency.format_price_range(
                      product.min_price,
                      product.max_price,
                      @store.currency
                    )}
                  </p>
                </div>
              </div>
            </a>
          <% end %>
          <%!-- Two smaller cards stacked --%>
          <%= for product <- Enum.slice(@featured_products, 1, 2) do %>
            <a
              href={store_path(@store.slug, "/products/#{product.slug}")}
              class="group block"
            >
              <div class="relative overflow-hidden bg-[#F1F5F9]">
                <.optimized_image
                  :if={Shared.first_image(product)}
                  src={Shared.first_image(product)}
                  alt={product.title}
                  class="w-full aspect-[4/3] object-cover group-hover:scale-105 transition-transform duration-700"
                />
                <div
                  :if={!Shared.first_image(product)}
                  class="w-full aspect-[4/3] flex items-center justify-center"
                >
                  <svg
                    class="w-12 h-12 text-[#94A3B8]"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="1"
                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                    />
                  </svg>
                </div>
                <div class="absolute bottom-0 left-0 right-0 p-5 bg-gradient-to-t from-[#0F172A]/70 to-transparent">
                  <h3
                    class="text-lg font-bold text-white mb-0.5"
                    style="font-family: 'Outfit', sans-serif;"
                  >
                    {product.title}
                  </h3>
                  <p class="text-sm text-white/70" style="font-family: 'Inter', sans-serif;">
                    {Currency.format_price_range(
                      product.min_price,
                      product.max_price,
                      @store.currency
                    )}
                  </p>
                </div>
              </div>
            </a>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  defp heading(%{"heading" => heading}) when heading not in [nil, ""], do: heading
  defp heading(_settings), do: "Featured"
end
