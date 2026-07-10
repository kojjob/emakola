defmodule Emakola.Suppliers.ContentLocaleTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.{ContentLocale, SocialCard}

  @facts %{
    "product_title" => "Kente & Cloth",
    "supplier_description" => "Handwoven cotton.",
    "delivery_areas" => ["Accra"],
    "return_terms" => "Returns within 7 days.",
    "prices" => [6_500],
    "source_image_url" => "https://example.com/kente.jpg?x=1&y=2"
  }

  test "renders curated English and Twi variants without translating free-form claims" do
    english = ContentLocale.render(@facts, "en-GH")
    twi = ContentLocale.render(@facts, "tw-GH")

    assert english["whatsapp"] =~ "Handwoven cotton."
    assert twi["locale"] == "tw-GH"
    assert twi["whatsapp"] =~ "Yɛwɔ Kente & Cloth"
    assert twi["whatsapp"] =~ "GH₵65.00"
    refute twi["whatsapp"] =~ "Handwoven cotton."
  end

  test "generates an escaped grounded SVG data image" do
    uri = SocialCard.data_uri(@facts)
    assert String.starts_with?(uri, "data:image/svg+xml,")

    svg = uri |> String.replace_prefix("data:image/svg+xml,", "") |> URI.decode()
    assert svg =~ "Kente &amp; Cloth"
    assert svg =~ "GH₵65.00"
    assert svg =~ "x=1&amp;y=2"
    refute svg =~ "<script"
  end
end
