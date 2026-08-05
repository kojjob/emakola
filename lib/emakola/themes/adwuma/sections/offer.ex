defmodule Emakola.Themes.Adwuma.Sections.Offer do
  @moduledoc """
  The reference's countdown band — bound to a **real** deadline or absent.

  `Marketing.Coupon` carries a merchant-authored `expires_at`, its
  `:list_active_public` read already filters expired ones, and `StoreLive`
  assigns the result as `:public_coupons`. `CheckoutService` enforces the same
  expiry at redemption, so the storefront clock and the till agree.

  With no public coupon carrying an expiry, this section renders **nothing** —
  no placeholder, no default 24-hour timer, no "ending soon". There is
  deliberately no merchant-settable deadline: a countdown that nothing enforces
  is fabricated urgency, which is exactly what this repo has already had to
  purge once.
  """
  @behaviour Emakola.Themes.Section

  use Phoenix.Component

  alias EmakolaWeb.Helpers.Currency

  @impl true
  def key, do: "adwuma/offer"
  @impl true
  def label, do: "Limited offer"

  @impl true
  def settings_schema do
    [%{key: "heading", type: :string, label: "Heading", default: "Ends soon"}]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :coupon, expiring_coupon(assigns))

    ~H"""
    <section
      :if={@coupon}
      class="bg-white px-4 py-16 [font-family:var(--adw-body)] sm:px-6 sm:py-20"
    >
      <div class="mx-auto max-w-3xl rounded-2xl border border-[color:var(--adw-rule)] p-8 text-center">
        <h2 class="text-2xl font-semibold text-[color:var(--adw-ink)] [font-family:var(--adw-display)]">
          {@settings["heading"] || "Ends soon"}
        </h2>

        <p class="mt-3 text-base text-[color:var(--adw-muted)]">
          Use code
          <span class="font-semibold tracking-wide text-[color:var(--adw-ink)]">
            {@coupon.code}
          </span>
          for {discount_label(@coupon, @store)}.
        </p>

        <p class="mt-4 text-sm font-medium text-[color:var(--adw-ink)]">
          Ends {format_deadline(@coupon.expires_at)}
        </p>
      </div>
    </section>
    """
  end

  defp expiring_coupon(assigns) do
    (Map.get(assigns, :public_coupons) || [])
    |> Enum.find(&(not is_nil(Map.get(&1, :expires_at))))
  end

  defp discount_label(%{discount_type: :percentage, discount_value: value}, _store),
    do: "#{value}% off"

  defp discount_label(%{discount_type: :fixed_amount, discount_value: value}, store),
    do: "#{Currency.format_price(value, store.currency)} off"

  defp discount_label(%{discount_type: :free_shipping}, _store), do: "free delivery"
  defp discount_label(_coupon, _store), do: "a discount"

  defp format_deadline(%DateTime{} = at), do: Calendar.strftime(at, "%-d %b, %-I:%M %p")
  defp format_deadline(_), do: ""
end
