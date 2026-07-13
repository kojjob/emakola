defmodule Emakola.Themes.Testimonial do
  @moduledoc """
  What a theme is allowed to say about a customer.

  Themes used to ship invented testimonials in their defaults and a hardcoded
  five-star row above them. This module exists so there is exactly one way for
  a theme to render praise, and it is fed only by real reviews:

  - `list/1` reads the `:testimonials` assign (the store's own published
    reviews, loaded by the storefront) and nothing else. No fallback, no
    defaults — a store with no reviews gets an empty list, and the section
    renders nothing at all.
  - `stars/1` draws exactly the rating the reviewer gave. There is no way to
    ask it for five.
  """
  use Phoenix.Component

  @doc """
  The store's real published reviews, from the storefront assigns.

  Returns `[]` when the assign is absent — the section editor's preview and any
  theme rendered without a storefront still work, they simply show nothing
  rather than something untrue.
  """
  @spec list(map()) :: list()
  def list(assigns) do
    case Map.get(assigns, :testimonials) do
      reviews when is_list(reviews) -> reviews
      _ -> []
    end
  end

  @doc """
  What we may call a reviewer: their first name, or "Customer".

  The product page has always named reviewers this way; this is that convention,
  moved somewhere a theme can reach without the web layer (which would be a
  compile cycle). `EmakolaWeb.Components.ReviewComponents.reviewer_name/1`
  delegates here, so the shop and the product page never disagree.

  An unnamed buyer stays unnamed. We do not invent one.
  """
  @spec name(map()) :: String.t()
  def name(%{customer: %{name: name}}) when is_binary(name) and name != "" do
    name |> String.split() |> List.first()
  end

  def name(_review), do: "Customer"

  @doc """
  A star row for one review's own rating.

  Full stars up to the rating, hollow ones after. The rating is clamped to 1..5
  because that is what the resource already guarantees; nothing here can invent
  a score.
  """
  attr :rating, :integer, required: true
  attr :class, :string, default: ""

  def stars(assigns) do
    assigns = assign(assigns, :rating, clamp(assigns.rating))

    ~H"""
    <div class={["flex items-center gap-0.5", @class]} aria-label={"Rated #{@rating} out of 5"}>
      <span :for={n <- 1..5} aria-hidden="true" style="font-size: 14px;">
        {if n <= @rating, do: "★", else: "☆"}
      </span>
    </div>
    """
  end

  defp clamp(rating) when is_integer(rating), do: rating |> max(1) |> min(5)
  defp clamp(_rating), do: 1
end
