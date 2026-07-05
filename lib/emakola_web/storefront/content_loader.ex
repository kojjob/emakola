defmodule EmakolaWeb.Storefront.ContentLoader do
  @moduledoc """
  Loads a store's `StorePageContent` for the storefront, read-only.

  Returns the content struct, or an empty map when the store has no row yet.
  The renderers treat any missing/blank field as "use the neutral fallback",
  so callers never need to nil-check the result itself — both a `%StorePageContent{}`
  and a `%{}` answer `Map.get/2`.
  """

  alias Emakola.Stores.StorePageContent

  @spec load(String.t()) :: StorePageContent.t() | map()
  def load(store_id) when is_binary(store_id) do
    case Emakola.Stores.get_page_content(store_id, authorize?: false, not_found_error?: false) do
      {:ok, %StorePageContent{} = content} -> content
      _ -> %{}
    end
  end

  @doc """
  Reads a scalar text field from loaded content, treating blank/missing as nil
  so renderers can fall back with `||`.
  """
  @spec field(StorePageContent.t() | map(), atom()) :: String.t() | nil
  def field(content, key) do
    case Map.get(content, key) do
      value when is_binary(value) -> if String.trim(value) == "", do: nil, else: value
      _ -> nil
    end
  end

  @doc """
  Reads a list field (array of string-keyed maps), always returning a list of maps.
  """
  @spec list(StorePageContent.t() | map(), atom()) :: [map()]
  def list(content, key) do
    content |> Map.get(key) |> List.wrap() |> Enum.filter(&is_map/1)
  end
end
