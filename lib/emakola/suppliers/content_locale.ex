defmodule Emakola.Suppliers.ContentLocale do
  @moduledoc "Curated locale templates that preserve the approved supplier fact boundary."

  @supported ~w(en-GH tw-GH)

  def supported, do: @supported

  def render(facts, locale) when locale in @supported do
    title = facts["product_title"]
    price = facts["prices"] |> List.first() |> money()
    description = facts["supplier_description"]

    base(title, price, description, facts, locale)
    |> Map.put("locale", locale)
  end

  def render(facts, _locale), do: render(facts, "en-GH")

  defp base(title, price, description, facts, "en-GH") do
    detail = blank_fallback(description, "Contact us for verified product details.")

    %{
      "whatsapp" => "#{title} is available from #{price}. #{detail}",
      "facebook" => "Now available: #{title} from #{price}. #{detail}",
      "short_video_script" => "Show #{title}. Say: Available from #{price}. #{detail}",
      "faq" => [
        %{
          "question" => "Where is delivery available?",
          "answer" => areas(facts["delivery_areas"])
        },
        %{"question" => "What is the return policy?", "answer" => facts["return_terms"]}
      ]
    }
  end

  defp base(title, price, _description, facts, "tw-GH") do
    %{
      "whatsapp" => "Yɛwɔ #{title}. Ne bo fi #{price}. Bisa yɛn fa nneɛma no ne delivery ho.",
      "facebook" => "Yɛwɔ ade foforo: #{title}, ne bo fi #{price}. Bisa yɛn ansa na woatɔ.",
      "short_video_script" =>
        "Kyerɛ #{title}. Ka sɛ: Yɛwɔ bi a ne bo fi #{price}. Bisa yɛn fa delivery ho.",
      "faq" => [
        %{"question" => "Ɛhe na mode kɔma?", "answer" => twi_areas(facts["delivery_areas"])},
        %{
          "question" => "Sɛ mepɛ sɛ mede san ba a, dɛn na menyɛ?",
          "answer" => facts["return_terms"]
        }
      ]
    }
  end

  defp areas([]), do: "Confirm the delivery area with the store before ordering."
  defp areas(areas), do: "Delivery areas: #{Enum.join(areas, ", ")}."
  defp twi_areas([]), do: "Bisa sotɔɔ no fa baabi a wɔde kɔma ho ansa na woatɔ."
  defp twi_areas(areas), do: "Yɛde kɔma wɔ: #{Enum.join(areas, ", ")}."
  defp blank_fallback(value, fallback) when value in [nil, ""], do: fallback
  defp blank_fallback(value, _fallback), do: value
  defp money(nil), do: "bo a wɔakyerɛ no"
  defp money(amount), do: "GH₵#{:erlang.float_to_binary(amount / 100, decimals: 2)}"
end
