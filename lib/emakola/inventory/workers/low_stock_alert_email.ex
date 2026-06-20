defmodule Emakola.Inventory.Workers.LowStockAlertWorker.Email do
  @moduledoc """
  Builds and sends low-stock alert emails to store merchants.

  Generates a plain-text email listing all variants below the stock threshold
  for a given store.
  """

  import Swoosh.Email

  @doc """
  Sends a low-stock alert email to a merchant.

  ## Parameters
    - `merchant` — Merchant struct with `:email` and `:name`
    - `store` — Store struct with `:name`
    - `variants` — List of low-stock Variant structs (with `:product` loaded)
  """
  def send_alert(merchant, store, variants) do
    email = build_email(merchant, store, variants)
    Emakola.Mailer.deliver(email)
  end

  defp build_email(merchant, store, variants) do
    email_str = to_string(merchant.email)
    name_str = if merchant.name, do: to_string(merchant.name), else: email_str

    new()
    |> from({"Makola", "noreply@emakola.com"})
    |> to({name_str, email_str})
    |> subject("Low Stock Alert — #{store.name}")
    |> text_body(text_body_content(store, variants))
    |> html_body(html_body_content(store, variants))
  end

  defp text_body_content(store, variants) do
    items =
      Enum.map_join(variants, "\n", fn variant ->
        product_title = variant_product_title(variant)
        sku = variant.sku || "N/A"
        "- #{product_title} (SKU: #{sku}): #{variant.stock_quantity} remaining"
      end)

    """
    Low Stock Alert for #{store.name}

    The following #{length(variants)} item(s) are running low:

    #{items}

    Please restock these items to avoid stockouts.

    — Makola
    """
  end

  defp html_body_content(store, variants) do
    rows =
      Enum.map_join(variants, "\n", fn variant ->
        product_title = variant_product_title(variant)
        sku = variant.sku || "N/A"

        """
        <tr>
          <td style="padding:8px;border-bottom:1px solid #e2e8f0;">#{escape(product_title)}</td>
          <td style="padding:8px;border-bottom:1px solid #e2e8f0;">#{escape(sku)}</td>
          <td style="padding:8px;border-bottom:1px solid #e2e8f0;text-align:center;font-weight:bold;color:#dc2626;">#{variant.stock_quantity}</td>
        </tr>
        """
      end)

    """
    <div style="font-family:Inter,system-ui,sans-serif;max-width:600px;margin:0 auto;">
      <h2 style="color:#0f172a;">Low Stock Alert — #{escape(store.name)}</h2>
      <p style="color:#475569;">The following #{length(variants)} item(s) are running low on stock:</p>
      <table style="width:100%;border-collapse:collapse;margin:16px 0;">
        <thead>
          <tr style="background:#f1f5f9;">
            <th style="padding:8px;text-align:left;font-size:12px;color:#64748b;">Product</th>
            <th style="padding:8px;text-align:left;font-size:12px;color:#64748b;">SKU</th>
            <th style="padding:8px;text-align:center;font-size:12px;color:#64748b;">Stock</th>
          </tr>
        </thead>
        <tbody>
          #{rows}
        </tbody>
      </table>
      <p style="color:#475569;font-size:14px;">Please restock these items to avoid stockouts.</p>
    </div>
    """
  end

  defp variant_product_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp variant_product_title(_), do: "Unknown Product"

  defp escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape(text), do: escape(to_string(text))
end
