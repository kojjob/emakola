defmodule Emakola.Stores.FeaturingChecklist do
  @moduledoc """
  The eligibility floor, phrased for the merchant who has to clear it.

  Same bars as `DirectoryEligibility`, turned into things a merchant can do
  this afternoon — put up a photo, add a MoMo number, publish something.
  Pure in the `SetupChecklist` style: the caller passes counts and flags,
  this module does no database work.

  Labels obey the eight-word ceiling: many Makola merchants do not read
  fluently, and a checklist is only a help if it can be read at a glance.
  """

  @minimum_products 3

  @type item :: %{id: atom(), label: String.t(), done?: boolean()}

  @doc "The floor as a checklist. Order is the order a merchant should fix things."
  @spec items(map(), keyword()) :: [item()]
  def items(store, opts) do
    [
      %{
        id: :photo,
        label: "Add a shop photo",
        done?: present?(store.logo_url) or present?(store.cover_image_url)
      },
      %{
        id: :words,
        label: "Say what you sell",
        done?: present?(store.tagline) or present?(store.description)
      },
      %{
        id: :contact,
        label: "Add a phone or WhatsApp",
        done?:
          present?(store.contact_phone) or present?(store.whatsapp_number) or
            present?(store.contact_email)
      },
      %{id: :region, label: "Pick your region", done?: present?(store.region)},
      %{
        id: :products,
        label: "Put up #{@minimum_products} items",
        done?: Keyword.fetch!(opts, :product_count) >= @minimum_products
      },
      %{
        id: :payout,
        label: "Add your MoMo payout",
        done?: Keyword.fetch!(opts, :payout_verified?)
      },
      %{
        id: :activity,
        label: "Sell or restock recently",
        done?: Keyword.fetch!(opts, :active_recently?)
      }
    ]
  end

  @spec eligible?([item()]) :: boolean()
  def eligible?(items), do: Enum.all?(items, & &1.done?)

  defp present?(nil), do: false
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
end
