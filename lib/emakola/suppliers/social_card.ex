defmodule Emakola.Suppliers.SocialCard do
  @moduledoc "Generates a grounded SVG sales card from an approved product image, title, and price."

  def data_uri(facts) do
    title = facts["product_title"] |> escape() |> truncate(52)
    price = facts["prices"] |> List.first() |> money() |> escape()
    image = facts["source_image_url"] |> to_string() |> escape()

    svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1080" viewBox="0 0 1080 1080">
      <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#062f2a"/><stop offset="1" stop-color="#0f766e"/></linearGradient><clipPath id="photo"><rect x="60" y="60" width="960" height="650" rx="42"/></clipPath></defs>
      <rect width="1080" height="1080" rx="56" fill="url(#bg)"/>
      <rect x="60" y="60" width="960" height="650" rx="42" fill="#d1fae5"/>
      <image href="#{image}" x="60" y="60" width="960" height="650" preserveAspectRatio="xMidYMid slice" clip-path="url(#photo)"/>
      <text x="70" y="790" fill="#a7f3d0" font-family="Arial,sans-serif" font-size="30" font-weight="700">FULFILLED BY A VERIFIED PARTNER</text>
      <text x="70" y="865" fill="white" font-family="Arial,sans-serif" font-size="54" font-weight="800">#{title}</text>
      <text x="70" y="960" fill="#fef3c7" font-family="Arial,sans-serif" font-size="70" font-weight="900">From #{price}</text>
      <text x="70" y="1020" fill="#ccfbf1" font-family="Arial,sans-serif" font-size="25">Review product details and delivery terms before ordering.</text>
    </svg>
    """

    "data:image/svg+xml," <> URI.encode(svg)
  end

  defp escape(nil), do: ""

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp truncate(value, max), do: String.slice(value, 0, max)
  defp money(nil), do: "listed price"
  defp money(amount), do: "GH₵#{:erlang.float_to_binary(amount / 100, decimals: 2)}"
end
