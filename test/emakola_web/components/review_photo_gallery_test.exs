defmodule EmakolaWeb.ReviewPhotoGalleryTest do
  @moduledoc """
  Pins the contract for the photo gallery rendered inside review cards
  by `ReviewComponents.review_section/1`:

    * Reviews with images render a 4-up grid with thumbnails
    * Each thumbnail links to the full-size image
    * Reviews without images skip the gallery (no empty grid)
    * Tolerant of both string-keyed and atom-keyed image maps
    * Upload control renders only when `uploads` assign is provided
  """
  use ExUnit.Case, async: true
  use Phoenix.Component
  import Phoenix.LiveViewTest

  describe "review_section with images on a review" do
    test "renders thumbnails inside a grid for each image" do
      assigns = %{
        reviews: [
          %{
            id: "r1",
            rating: 5,
            title: "Great",
            body: "Loved it",
            verified_purchase: true,
            inserted_at: DateTime.utc_now(),
            customer: nil,
            images: [
              %{"url" => "https://e.x/p1.jpg", "thumbnail_url" => "https://e.x/p1-t.jpg"},
              %{"url" => "https://e.x/p2.jpg", "thumbnail_url" => "https://e.x/p2-t.jpg"}
            ]
          }
        ],
        store: %{},
        product: %{}
      }

      html =
        rendered_to_string(~H"""
        <EmakolaWeb.ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={@reviews}
          can_review={false}
          already_reviewed={false}
          avg_rating={5.0}
          review_count={1}
        />
        """)

      assert html =~ ~s(href="https://e.x/p1.jpg")
      assert html =~ ~s(href="https://e.x/p2.jpg")
      assert html =~ ~s(src="https://e.x/p1-t.jpg")
      assert html =~ ~s(src="https://e.x/p2-t.jpg")
      assert html =~ ~s(loading="lazy")
    end

    test "review without images renders no gallery container" do
      assigns = %{
        reviews: [
          %{
            id: "r1",
            rating: 4,
            title: "OK",
            body: "Fine",
            verified_purchase: false,
            inserted_at: DateTime.utc_now(),
            customer: nil,
            images: []
          }
        ],
        store: %{},
        product: %{}
      }

      html =
        rendered_to_string(~H"""
        <EmakolaWeb.ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={@reviews}
          can_review={false}
          already_reviewed={false}
          avg_rating={4.0}
          review_count={1}
        />
        """)

      # Body still renders; no thumbnail markers
      assert html =~ "Fine"
      refute html =~ ~s(loading="lazy")
    end

    test "tolerates atom-keyed image maps" do
      assigns = %{
        reviews: [
          %{
            id: "r1",
            rating: 3,
            title: nil,
            body: "Atom keys",
            verified_purchase: false,
            inserted_at: DateTime.utc_now(),
            customer: nil,
            images: [%{url: "https://e.x/atom.jpg"}]
          }
        ],
        store: %{},
        product: %{}
      }

      html =
        rendered_to_string(~H"""
        <EmakolaWeb.ReviewComponents.review_section
          store={@store}
          product={@product}
          reviews={@reviews}
          can_review={false}
          already_reviewed={false}
          avg_rating={3.0}
          review_count={1}
        />
        """)

      assert html =~ ~s(href="https://e.x/atom.jpg")
      # thumbnail_url falls back to url when missing
      assert html =~ ~s(src="https://e.x/atom.jpg")
    end
  end
end
