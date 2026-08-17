defmodule EmakolaWeb.ReviewComponentsTest do
  @moduledoc """
  Tests for the shared review UI components: star display, review summary,
  review section (form, list, empty state).
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias EmakolaWeb.ReviewComponents

  describe "star_display/1" do
    test "renders 5 stars" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.star_display rating={4.0} size="sm" />
        """)

      # Should contain 5 SVG star icons
      assert length(Regex.scan(~r/<svg/, html)) == 5
      assert html =~ "4.0 out of 5 stars"
    end

    test "renders amber stars for filled and gray for empty" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.star_display rating={3.0} size="sm" />
        """)

      assert html =~ "text-amber-400"
      assert html =~ "text-gray-300"
    end

    test "defaults to zero rating" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.star_display />
        """)

      assert html =~ "0.0 out of 5 stars"
    end

    test "renders md size stars" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.star_display rating={5.0} size="md" />
        """)

      assert html =~ "w-5 h-5"
    end
  end

  describe "review_summary/1" do
    test "renders rating and count when review_count > 0" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_summary avg_rating={4.2} review_count={12} />
        """)

      assert html =~ "4.2 out of 5"
      assert html =~ "12 reviews"
    end

    test "renders singular 'review' for count of 1" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_summary avg_rating={5.0} review_count={1} />
        """)

      assert html =~ "1 review)"
    end

    test "renders nothing when review_count is 0" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_summary avg_rating={0.0} review_count={0} />
        """)

      refute html =~ "out of 5"
    end
  end

  describe "review_section/1 audit polish (2026-08-16)" do
    # The audit flagged this block on every theme's PDP: a hard white
    # full-width band that seams against cream/dark theme pages, and a
    # ~200px stack of separate boxes (purchase prompt + dead gap + empty
    # line) when a product has no reviews.

    defp empty_state_html do
      assigns = %{store: %{id: "store-1"}, product: %{id: "prod-1"}}

      rendered_to_string(~H"""
      <ReviewComponents.review_section
        store={@store}
        product={@product}
        reviews={[]}
        can_review={false}
        already_reviewed={false}
        review_form_rating={0}
        review_form_title=""
        review_form_body=""
        review_submitting={false}
        avg_rating={nil}
        review_count={0}
      />
      """)
    end

    test "the section carries no hard white band" do
      doc = LazyHTML.from_fragment(empty_state_html())
      [section] = doc |> LazyHTML.query("section#reviews") |> Enum.to_list()

      refute LazyHTML.attribute(section, "class") |> List.first() =~ "bg-white",
             "the reviews section must not paint its own full-width white band — " <>
               "it seams against every non-white theme page"
    end

    test "no reviews + cannot review collapses into one compact block" do
      html = empty_state_html()
      doc = LazyHTML.from_fragment(html)

      combined = LazyHTML.query(doc, "#reviews-empty-state")

      assert Enum.any?(combined),
             "the no-reviews/can't-review case must render one combined block, " <>
               "not a purchase-prompt box plus a separate dead-gapped empty line"

      text = LazyHTML.text(combined)
      assert text =~ "No reviews yet"
      assert text =~ "Purchase this product to leave a review"
    end
  end

  describe "review_section/1" do
    test "renders empty state when no reviews" do
      assigns = %{
        store: %{id: "store-1"},
        product: %{id: "prod-1"}
      }

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={[]}
          can_review={false}
          already_reviewed={false}
          review_form_rating={0}
          review_form_title=""
          review_form_body=""
          review_submitting={false}
          avg_rating={nil}
          review_count={0}
        />
        """)

      assert html =~ "Customer Reviews"
      assert html =~ "No reviews yet"
      assert html =~ "Purchase this product to leave a review"
    end

    test "renders review form when can_review is true" do
      assigns = %{
        store: %{id: "store-1"},
        product: %{id: "prod-1"}
      }

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={[]}
          can_review={true}
          already_reviewed={false}
          review_form_rating={0}
          review_form_title=""
          review_form_body=""
          review_submitting={false}
          avg_rating={nil}
          review_count={0}
        />
        """)

      assert html =~ "Write a Review"
      assert html =~ "Submit Review"
      assert html =~ ~s(phx-submit="submit_review")
      assert html =~ "Select a rating"
    end

    test "renders already reviewed message" do
      assigns = %{
        store: %{id: "store-1"},
        product: %{id: "prod-1"}
      }

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={[]}
          can_review={false}
          already_reviewed={true}
          review_form_rating={0}
          review_form_title=""
          review_form_body=""
          review_submitting={false}
          avg_rating={nil}
          review_count={0}
        />
        """)

      assert html =~ "You have already reviewed this product"
      refute html =~ "Write a Review"
    end

    test "renders reviews list with verified purchase badge" do
      review = %{
        id: "rev-1",
        rating: 4,
        title: "Great product",
        body: "Really loved this item, would buy again.",
        verified_purchase: true,
        customer: %{name: "Kwame Asante"},
        inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now(), -3600)
      }

      assigns = %{
        store: %{id: "store-1"},
        product: %{id: "prod-1"},
        review: review
      }

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={[@review]}
          can_review={false}
          already_reviewed={false}
          review_form_rating={0}
          review_form_title=""
          review_form_body=""
          review_submitting={false}
          avg_rating={4.0}
          review_count={1}
        />
        """)

      assert html =~ "Great product"
      assert html =~ "Really loved this item"
      assert html =~ "Verified Purchase"
      assert html =~ "Kwame"
      assert html =~ "1 hours ago"
    end

    test "renders section header with avg rating when reviews exist" do
      assigns = %{
        store: %{id: "store-1"},
        product: %{id: "prod-1"}
      }

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={[]}
          can_review={false}
          already_reviewed={false}
          review_form_rating={0}
          review_form_title=""
          review_form_body=""
          review_submitting={false}
          avg_rating={4.5}
          review_count={8}
        />
        """)

      assert html =~ "4.5 out of 5"
      assert html =~ "Based on 8 reviews"
    end

    test "disables submit button when rating is 0" do
      assigns = %{
        store: %{id: "store-1"},
        product: %{id: "prod-1"}
      }

      html =
        rendered_to_string(~H"""
        <ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={[]}
          can_review={true}
          already_reviewed={false}
          review_form_rating={0}
          review_form_title=""
          review_form_body=""
          review_submitting={false}
          avg_rating={nil}
          review_count={0}
        />
        """)

      assert html =~ "bg-gray-300 cursor-not-allowed"
    end
  end

  describe "reviewer_name/1" do
    test "extracts first name from customer" do
      assert ReviewComponents.reviewer_name(%{customer: %{name: "Ama Serwaa"}}) == "Ama"
    end

    test "returns Customer when no name" do
      assert ReviewComponents.reviewer_name(%{customer: %{name: nil}}) == "Customer"
      assert ReviewComponents.reviewer_name(%{customer: nil}) == "Customer"
      assert ReviewComponents.reviewer_name(%{}) == "Customer"
    end
  end

  describe "relative_time/1" do
    test "returns 'just now' for recent times" do
      assert ReviewComponents.relative_time(NaiveDateTime.utc_now()) == "just now"
    end

    test "returns minutes ago" do
      time = NaiveDateTime.add(NaiveDateTime.utc_now(), -120)
      assert ReviewComponents.relative_time(time) == "2 min ago"
    end

    test "returns hours ago" do
      time = NaiveDateTime.add(NaiveDateTime.utc_now(), -7200)
      assert ReviewComponents.relative_time(time) == "2 hours ago"
    end

    test "returns days ago" do
      time = NaiveDateTime.add(NaiveDateTime.utc_now(), -172_800)
      assert ReviewComponents.relative_time(time) == "2 days ago"
    end

    test "returns empty string for nil" do
      assert ReviewComponents.relative_time(nil) == ""
    end
  end
end
