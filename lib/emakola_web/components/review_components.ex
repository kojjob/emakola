defmodule EmakolaWeb.ReviewComponents do
  @moduledoc """
  Shared review UI components: star display, review summary, review form, and review list.

  Used across all storefront themes on product detail pages.
  """
  use Phoenix.Component

  import EmakolaWeb.CoreComponents, only: [input: 1]

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
        <span class="text-gray-400">
          ({@review_count} {if @review_count == 1, do: "review", else: "reviews"})
        </span>
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
  attr :review_form, :any, default: nil
  attr :review_form_rating, :integer, default: 0
  attr :review_form_title, :string, default: ""
  attr :review_form_body, :string, default: ""
  attr :review_submitting, :boolean, default: false
  attr :avg_rating, :float, default: nil
  attr :review_count, :integer, default: 0
  attr :uploads, :map, default: nil

  def review_section(assigns) do
    # Theme component tests can render this component in isolation. Production
    # ProductDetailLive always provides the to_form/2-backed assign.
    assigns =
      assign_new(assigns, :resolved_review_form, fn ->
        assigns.review_form ||
          to_form(%{"title" => assigns.review_form_title, "body" => assigns.review_form_body})
      end)

    ~H"""
    <%!-- No hard background: a full-width white band seams against every
          non-white theme page. The bounded card below carries the surface. --%>
    <section class="py-10 lg:py-16" id="reviews">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 rounded-2xl border border-gray-200 bg-white p-6 sm:p-8">
        <%!-- Section Header --%>
        <div class="mb-6">
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
          <.form
            for={@resolved_review_form}
            id="product-review-form"
            phx-submit="submit_review"
            phx-change="validate_review"
            class="space-y-4"
          >
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
                  aria-label={"Rate #{Emakola.Plural.count(i, "star")}"}
                >
                  <svg
                    class={[
                      "w-8 h-8 transition-colors",
                      if(i <= @review_form_rating,
                        do: "text-amber-400",
                        else: "text-gray-300 hover:text-amber-200"
                      )
                    ]}
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
              <.input
                field={@resolved_review_form[:title]}
                type="text"
                label="Title (optional)"
                maxlength="100"
                placeholder="Summarize your experience"
                class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-amber-500 focus:ring-1 focus:ring-amber-500"
              />
            </div>

            <%!-- Body (required) --%>
            <div>
              <.input
                field={@resolved_review_form[:body]}
                type="textarea"
                label="Your Review"
                rows="4"
                required
                maxlength="2000"
                placeholder="Tell others what you think about this product..."
                class="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-amber-500 focus:ring-1 focus:ring-amber-500"
              />
            </div>

            <%!-- Photo Upload (up to 4) --%>
            <div :if={@uploads}>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Add photos (optional, up to 4)
              </label>
              <.live_file_input
                upload={@uploads.review_photos}
                class="block w-full text-sm text-gray-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-amber-50 file:text-amber-700 hover:file:bg-amber-100"
              />
              <%!-- Per-entry preview + cancel + error --%>
              <div :if={@uploads.review_photos.entries != []} class="mt-3 grid grid-cols-4 gap-2">
                <div
                  :for={entry <- @uploads.review_photos.entries}
                  class="relative aspect-square overflow-hidden rounded border border-gray-200 bg-gray-50"
                >
                  <.live_img_preview
                    entry={entry}
                    class="absolute inset-0 w-full h-full object-cover"
                  />
                  <button
                    type="button"
                    phx-click="cancel_review_photo"
                    phx-value-ref={entry.ref}
                    class="absolute top-1 right-1 inline-flex items-center justify-center w-5 h-5 rounded-full bg-black/60 text-white text-xs hover:bg-black/80"
                    aria-label="Remove photo"
                  >
                    ×
                  </button>
                </div>
              </div>
              <p
                :for={err <- upload_errors(@uploads.review_photos)}
                class="mt-1 text-xs text-red-600"
              >
                {humanize_upload_error(err)}
              </p>
            </div>

            <%!-- Submit --%>
            <button
              type="submit"
              disabled={@review_form_rating == 0 || @review_submitting}
              class={[
                "inline-flex items-center rounded-md px-4 py-2 text-sm font-semibold text-white transition-colors",
                if(@review_form_rating == 0 || @review_submitting,
                  do: "bg-gray-300 cursor-not-allowed",
                  else:
                    "bg-amber-600 hover:bg-amber-700 focus:ring-2 focus:ring-amber-500 focus:ring-offset-2"
                )
              ]}
            >
              {if @review_submitting, do: "Submitting...", else: "Submit Review"}
            </button>
          </.form>
        </div>

        <%!-- Already Reviewed Message --%>
        <div :if={@already_reviewed} class="mb-10 rounded-lg border border-green-200 bg-green-50 p-4">
          <p class="text-sm text-green-700">
            You have already reviewed this product. Thank you for your feedback!
          </p>
        </div>

        <%!-- Purchase to Review Message (only alongside existing reviews —
              the no-reviews case folds it into the empty state below, so a
              reviewless product shows one compact block, not three stacked
              boxes with a dead gap between them) --%>
        <div
          :if={!@can_review && !@already_reviewed && @reviews != []}
          class="mb-10 rounded-lg border border-gray-200 bg-gray-50 p-4"
        >
          <p class="text-sm text-gray-500">
            Purchase this product to leave a review.
          </p>
        </div>

        <%!-- Reviews List --%>
        <div :if={@reviews != []} class="space-y-6">
          <.review_card :for={review <- @reviews} review={review} />
        </div>

        <%!-- Empty State --%>
        <div :if={@reviews == []} id="reviews-empty-state" class="text-center py-6">
          <p class="text-gray-600 font-medium">
            No reviews yet. Be the first to review this product!
          </p>
          <p :if={!@can_review && !@already_reviewed} class="mt-1 text-sm text-gray-500">
            Purchase this product to leave a review.
          </p>
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

      <%!-- Photo gallery (up to 4-up grid). Renders only when images present. --%>
      <div :if={review_images(@review) != []} class="mt-3 grid grid-cols-4 gap-2 max-w-md">
        <a
          :for={img <- review_images(@review)}
          href={image_url(img)}
          target="_blank"
          rel="noopener"
          class="block aspect-square overflow-hidden rounded border border-gray-200 bg-gray-50"
        >
          <img
            src={image_thumbnail_url(img)}
            alt={image_alt(img) || "Customer review photo"}
            loading="lazy"
            class="w-full h-full object-cover"
          />
        </a>
      </div>

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

  defp format_rating(rating) when is_float(rating),
    do: :erlang.float_to_binary(rating, decimals: 1)

  defp format_rating(rating) when is_integer(rating), do: "#{rating}.0"

  defp format_rating(%Decimal{} = rating) do
    rating |> Decimal.round(1) |> Decimal.to_string()
  end

  defp format_rating(rating), do: "#{rating}"

  @doc false
  # One convention for naming a buyer, shared with the storefront themes, so a
  # review reads the same on the product page and in a shop's testimonials.
  defdelegate reviewer_name(review), to: Emakola.Themes.Testimonial, as: :name

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

  defp format_time_diff(diff) when diff < 86_400,
    do: "#{Emakola.Plural.count(div(diff, 3600), "hour")} ago"

  defp format_time_diff(diff) when diff < 604_800,
    do: "#{Emakola.Plural.count(div(diff, 86_400), "day")} ago"

  defp format_time_diff(diff) when diff < 2_592_000,
    do: "#{Emakola.Plural.count(div(diff, 604_800), "week")} ago"

  defp format_time_diff(_diff), do: "over a month ago"

  # ── Image helpers ──────────────────────────────────────────────────
  #
  # Review images are stored as a list of maps with string keys (the
  # storefront upload path emits `%{"url" => ..., "thumbnail_url" => ...,
  # "alt" => ...}`). Tolerant accessors below so manually-seeded data
  # with atom keys also works.

  defp review_images(%{images: images}) when is_list(images), do: images
  defp review_images(_), do: []

  defp image_url(img), do: img["url"] || img[:url]

  defp image_thumbnail_url(img),
    do: img["thumbnail_url"] || img[:thumbnail_url] || image_url(img)

  defp image_alt(img), do: img["alt"] || img[:alt]

  # ── Upload error humaniser ─────────────────────────────────────────

  defp humanize_upload_error(:too_large), do: "File too large (max 5 MB)"
  defp humanize_upload_error(:not_accepted), do: "Unsupported file type"
  defp humanize_upload_error(:too_many_files), do: "Too many files (max 4)"
  defp humanize_upload_error(other), do: "Upload error: #{inspect(other)}"
end
