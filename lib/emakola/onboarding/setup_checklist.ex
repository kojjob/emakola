defmodule Emakola.Onboarding.SetupChecklist do
  @moduledoc """
  Computes the merchant's "store setup" checklist — the work that
  remains after the initial onboarding wizard so a new merchant can
  see, in one glance, what's left before they're ready to sell.

  The wizard at `/onboarding` covers store name, currency, theme
  pick, and (optionally) a first product. Everything else — delivery
  zones, WhatsApp number for customer contact, social media links —
  happens piecemeal across admin pages and is easy to forget.

  Pure transform: store struct in, list of step maps out. No DB
  writes, no LiveView coupling. The Dashboard renders it via the
  `setup_checklist/1` component; tests assert on the return value
  directly.

  ## Step shape

      %{
        key: :theme,
        done?: true,
        title: "Pick a theme",
        description: "Choose a look for your storefront",
        cta_label: "Customize",
        cta_path: "/admin/theme",
        icon: "palette"
      }

  Steps stay in a stable order regardless of done state — the
  component dims completed steps but doesn't reorder them.
  """

  alias Emakola.Stores.Store

  @type step :: %{
          key: atom(),
          done?: boolean(),
          title: String.t(),
          description: String.t(),
          cta_label: String.t(),
          cta_path: String.t(),
          icon: String.t()
        }

  @doc """
  Computes all setup steps for the given store.

  Pass `product_count` and `delivery_zone_count` from the caller
  (typically the Dashboard) so this module stays free of DB calls
  and easy to test in isolation.
  """
  @spec steps(Store.t(), keyword()) :: [step()]
  def steps(%Store{} = store, opts \\ []) do
    product_count = Keyword.get(opts, :product_count, 0)
    delivery_zone_count = Keyword.get(opts, :delivery_zone_count, 0)

    [
      %{
        key: :theme,
        done?: theme_set?(store),
        title: "Pick a theme",
        description: "Choose a look that fits your brand",
        cta_label: "Customize",
        cta_path: "/admin/theme",
        icon: "palette"
      },
      %{
        key: :first_product,
        done?: product_count > 0,
        title: "Add your first product",
        description: "List something for sale so the store has content",
        cta_label: "Add product",
        cta_path: "/admin/products/new",
        icon: "inventory_2"
      },
      %{
        key: :delivery_zones,
        done?: delivery_zone_count > 0,
        title: "Configure delivery zones",
        description: "Set fees and ETAs for the regions you ship to",
        cta_label: "Set delivery",
        cta_path: "/admin/settings/delivery",
        icon: "local_shipping"
      },
      %{
        key: :whatsapp,
        done?: whatsapp_set?(store),
        title: "Connect WhatsApp",
        description: "Customers reach you here for questions and orders",
        cta_label: "Add number",
        cta_path: "/admin/settings",
        icon: "chat"
      },
      %{
        key: :social,
        done?: any_social_url_set?(store),
        title: "Add social media",
        description: "Link Instagram, TikTok, or Facebook to your store",
        cta_label: "Add links",
        cta_path: "/admin/settings",
        icon: "share"
      }
    ]
  end

  @doc "Count of completed steps. Used to render the progress badge."
  @spec completed_count(Store.t(), keyword()) :: non_neg_integer()
  def completed_count(store, opts \\ []) do
    store |> steps(opts) |> Enum.count(& &1.done?)
  end

  @doc """
  True when every checklist step is done. Dashboard hides the widget
  once this returns true.
  """
  @spec complete?(Store.t(), keyword()) :: boolean()
  def complete?(store, opts \\ []) do
    store |> steps(opts) |> Enum.all?(& &1.done?)
  end

  # ── Detection helpers ──────────────────────────────────────────────

  defp theme_set?(%Store{theme_config: %{"theme" => theme}})
       when is_binary(theme) and theme != "",
       do: true

  defp theme_set?(%Store{theme_config: %{"theme_id" => id}})
       when is_binary(id) and id != "",
       do: true

  defp theme_set?(_), do: false

  defp whatsapp_set?(%Store{whatsapp_number: phone})
       when is_binary(phone) and phone != "",
       do: true

  defp whatsapp_set?(_), do: false

  defp any_social_url_set?(%Store{} = store) do
    Enum.any?([:instagram_url, :tiktok_url, :facebook_url, :youtube_url, :x_url], fn field ->
      case Map.get(store, field) do
        url when is_binary(url) and url != "" -> true
        _ -> false
      end
    end)
  end
end
