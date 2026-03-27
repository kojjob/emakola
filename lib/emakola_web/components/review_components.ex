defmodule EmakolaWeb.ReviewComponents do
  @moduledoc """
  Shared review UI components: star display, review summary, review form, and review list.

  Used across all storefront themes on product detail pages.
  """
  use Phoenix.Component

  @star_path "M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"

  # ── Star Display ───────────────────────────────────────────────────

  @doc """
  Renders a static star display for a given rating (0-5).
  Supports partial fills: stars are filled amber up to the rating, gray after.
  """
  attr :rating, :float, default: 0.0
  attr :size, :string, default: "sm", values: ["sm", "md"]

  def star_display(assigns) do
    size_class = if assigns.size == "md", do: "w-5 h-5", else: "w-4 h-4"
    rating = assigns.rating || 0.0

    stars =
      for i <- 1..5 do
        cond do
          i <= floor(rating) -> :filled
          i - 1 < rating and rating < i -> :partial
          true -> :empty
        end
      end

    assigns = assign(assigns, stars: stars, size_class: size_class, star_svg_path: @star_path)

    ~H"""
    <div class="flex items-center gap-0.5" aria-label={"#{@rating} out of 5 stars"}>
      <svg
        :for={star <- @stars}
        class={[@size_class, star_color(star)]}
        viewBox="0 0 20 20"
        fill="currentColor"
        aria-hidden="true"
      >
        <path d={@star_svg_path} />
      </svg>
    </div>
    """
  end

  defp star_color(:filled), do: "text-amber-400"
  defp star_color(:partial), do: "text-amber-300"
  defp star_color(:empty), do: "text-gray-300"

  defp star_path, do: @star_path

  # ── Review Summary ─────────────────────────────────────────────────

  @doc """
  Compact display of average rating + review count. Shown near the price.
  Only renders when review_count > 0.
  """
  attr :avg_rating, :float, default: nil
  attr :review_count, :integer, default: 0

  def review_summary(assigns) do
    ~H"""
    <div :if={@review_count > 0} class="flex items-center gap-2">
      <.star_display rating={@avg_rating || 0.0} size="sm" />
      <span class="text-sm text-gray-600">
        {format_rating(@avg_rating)} out of 5
        <span class="text-gray-400">({@review_count} {if @review_count == 1, do: "review", else: "reviews"})</span>
      </span>
    </div>
    """
  end

  # ── Review Section ─────────────────────────────────────────────────

  @doc """
  Full reviews section for the bottom of the product detail page.
  Includes header with avg rating, review form (for eligible customers),
  and the list of existing reviews.
  """
  attr :store, :map, required: true
  attr :product, :map, required: true
  attr :reviews, :list, default: []
  attr :can_review, :boolean, default: false
  attr :already_reviewed, :boolean, default: false
  attr :review_form_rating, :integer, default: 0
  attr :review_form_title, :string, default: ""
  attr :review_form_body, :string, default: ""
  attr :review_submitting, :boolean, default: false
  attr :avg_rating, :float, default: nil
  attr :review_count, :integer, default: 0

  def review_section(assigns) do
    ~H"""
    <section class="py-10 lg:py-16 bg-white" id="reviews">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <%!-- Section Header --%>
        <div class="mb-8">
          <h2 class="text-xl font-bold text-gray-900 sm:text-2xl">Customer Reviews</h2>
          <div :if={@review_count > 0} class="mt-2 flex items-center gap-3">
            <.star_display rating={@avg_rating || 0.0} size="md" />
            <span class="text-base font-medium text-gray-700">
              {format_rating(@avg_rating)} out of 5
            </span>
            <span class="text-sm text-gray-500">
              Based on {@review_count} {if @review_count == 1, do: "review", else: "reviews"}
            </span>
          </div>
        </div>

        <%!-- Review Form (eligible customers only) --%>
        <div :if={@can_review} class="mb-10 rounded-lg border border-gray-200 bg-gray-50 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Write a Review</h3>
          <form phx-submit="submit_review" class="space-y-4">
            <%!-- Star Selector --%>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Rating</label>
              <div class="flex items-center gap-1">
                <button
                  :for={i <- 1..5}
                  type="button"
                  phx-click="set_review_rating"
                  phx-value-rating={i}
                  class="focus:outline-none"
                  aria-label={"Rate #{i} star#{if i > 1, do: "s", else: ""}"}
                >
                  <svg
                    class={["w-8 h-8 transition-colors", if(i <= @review_form_rating, do: "text-amber-400", else: "text-gray-300 hover:text-amber-200")]}
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path d={star_path()} />
                  </svg>
                </button>
              </div>
              <p :if={@review_form_rating == 0} class="mt-1 text-xs text-gray-500">
                Select a rating
              </p>
            </div>

            <%!-- Title (optional) --%>
            <div>
              <label for="review-title" class="block text-sm font-medium text-gray-700 mb-1">
                Title (optional)
              </label>
              <input
                type="text"
                id="review-title"
                name="title"
                value={@review_form_title}
                maxlength="100"
                placeholder="Summarize your experience"
                class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-amber-500 focus:ring-1 focus:ring-amber-500"
              />
            </div>

            <%!-- Body (required) --%>
            <div>
              <label for="review-body" class="block text-sm font-medium text-gray-700 mb-1">
                Your Review
              </label>
              <textarea
                id="review-body"
                name="body"
                rows="4"
                required
                maxlength="2000"
                placeholder="Tell others what you think about this product..."
                class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-amber-500 focus:ring-1 focus:ring-amber-500"
              >{@review_form_body}</textarea>
            </div>

            <%!-- Submit --%>
            <button
              type="submit"
              disabled={@review_form_rating == 0 || @review_submitting}
              class={[
                "inline-flex items-center rounded-md px-4 py-2 text-sm font-semibold text-white transition-colors",
                if(@review_form_rating == 0 || @review_submitting,
                  do: "bg-gray-300 cursor-not-allowed",
                  else: "bg-amber-600 hover:bg-amber-700 focus:ring-2 focus:ring-amber-500 focus:ring-offset-2"
                )
              ]}
            >
              {if @review_submitting, do: "Submitting...", else: "Submit Review"}
            </button>
          </form>
        </div>

        <%!-- Already Reviewed Message --%>
        <div :if={@already_reviewed} class="mb-10 rounded-lg border border-green-200 bg-green-50 p-4">
          <p class="text-sm text-green-700">
            You have already reviewed this product. Thank you for your feedback!
          </p>
        </div>

        <%!-- Purchase to Review Message --%>
        <div :if={!@can_review && !@already_reviewed} class="mb-10 rounded-lg border border-gray-200 bg-gray-50 p-4">
          <p class="text-sm text-gray-500">
            Purchase this product to leave a review.
          </p>
        </div>

        <%!-- Reviews List --%>
        <div :if={@reviews != []} class="space-y-6">
          <.review_card :for={review <- @reviews} review={review} />
        </div>

        <%!-- Empty State --%>
        <div :if={@reviews == []} class="text-center py-8">
          <p class="text-gray-500">No reviews yet. Be the first to review this product!</p>
        </div>
      </div>
    </section>
    """
  end

  # ── Review Card ────────────────────────────────────────────────────

  attr :review, :map, required: true

  defp review_card(assigns) do
    ~H"""
    <div class="border-b border-gray-100 pb-6 last:border-b-0">
      <div class="flex items-start justify-between">
        <div>
          <.star_display rating={@review.rating * 1.0} size="sm" />
          <p :if={@review.title} class="mt-1 font-semibold text-gray-900 text-sm">
            {@review.title}
          </p>
        </div>
        <span
          :if={@review.verified_purchase}
          class="inline-flex items-center rounded-full bg-green-50 px-2 py-0.5 text-xs font-medium text-green-700 border border-green-200"
        >
          Verified Purchase
        </span>
      </div>

      <p class="mt-2 text-sm text-gray-700 leading-relaxed">{@review.body}</p>

      <div class="mt-3 flex items-center gap-2 text-xs text-gray-400">
        <span>{reviewer_name(@review)}</span>
        <span>&middot;</span>
        <span>{relative_time(@review.inserted_at)}</span>
      </div>
    </div>
    """
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp format_rating(nil), do: "0.0"
  defp format_rating(rating) when is_float(rating), do: :erlang.float_to_binary(rating, decimals: 1)
  defp format_rating(rating) when is_integer(rating), do: "#{rating}.0"

  defp format_rating(%Decimal{} = rating) do
    rating |> Decimal.round(1) |> Decimal.to_string()
  end

  defp format_rating(rating), do: "#{rating}"

  @doc false
  def reviewer_name(review) do
    case review do
      %{customer: %{name: name}} when is_binary(name) and name != "" ->
        name |> String.split() |> List.first()

      _ ->
        "Customer"
    end
  end

  @doc false
  def relative_time(nil), do: ""

  def relative_time(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)
    format_time_diff(diff)
  end

  def relative_time(%NaiveDateTime{} = ndt) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), ndt, :second)
    format_time_diff(diff)
  end

  def relative_time(_), do: ""

  defp format_time_diff(diff) when diff < 60, do: "just now"
  defp format_time_diff(diff) when diff < 3600, do: "#{div(diff, 60)} min ago"
  defp format_time_diff(diff) when diff < 86_400, do: "#{div(diff, 3600)} hours ago"
  defp format_time_diff(diff) when diff < 604_800, do: "#{div(diff, 86_400)} days ago"
  defp format_time_diff(diff) when diff < 2_592_000, do: "#{div(diff, 604_800)} weeks ago"
  defp format_time_diff(_diff), do: "over a month ago"
end
