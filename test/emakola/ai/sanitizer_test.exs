defmodule Emakola.AI.SanitizerTest do
  @moduledoc """
  No emoji reaches a merchant's shop from an AI reply, whatever the model
  decided to do with the house rule. Words that carry meaning survive.
  """
  use ExUnit.Case, async: true

  alias Emakola.AI.{Response, Sanitizer}

  test "strips emoji and their joiners from free text and tidies the spacing" do
    assert Sanitizer.strip_emoji("Fresh shea butter 🧴✨ for skin ❤️ and hair 👩🏾‍🦱.") ==
             "Fresh shea butter for skin and hair."
  end

  test "leaves currency signs, accents and punctuation alone" do
    text = "GH₵ 45.00 · Café au lait, 250 ml – 100% natural (résumé)."
    assert Sanitizer.strip_emoji(text) == text
  end

  test "cleans every string inside a parsed JSON reply, at any depth" do
    response = %Response{
      text: "🔥 Hot deal",
      parsed: %{
        "title" => "Oraimo FreePods 3 🎧",
        "tags" => ["earbuds 🎵", "wireless"],
        "photo_flags" => %{"stock_photo" => false},
        "nested" => %{"alt_text" => "Black earbuds ✅ on a table"}
      }
    }

    cleaned = Sanitizer.clean(response)

    assert cleaned.text == "Hot deal"
    assert cleaned.parsed["title"] == "Oraimo FreePods 3"
    assert cleaned.parsed["tags"] == ["earbuds", "wireless"]
    assert cleaned.parsed["photo_flags"] == %{"stock_photo" => false}
    assert cleaned.parsed["nested"]["alt_text"] == "Black earbuds on a table"
  end

  test "a response with nothing to clean passes through unchanged" do
    response = %Response{text: nil, parsed: nil}
    assert Sanitizer.clean(response) == response
  end
end
