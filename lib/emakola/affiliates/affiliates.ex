defmodule Emakola.Affiliates do
  @moduledoc """
  People who promote a merchant's products and earn commission on the sales
  they drive.

  Registration is phone-first and deliberately thin: a phone number, a name,
  and the MoMo number to be paid on. No email, no password — an affiliate
  gets an earnings page, not an admin, and proves who they are with the OTP
  flow the platform already uses (`Emakola.Accounts.PhoneAuth`).

  ## The payout container

  Every payout rail here is keyed to a store: `Payout.store_id` is
  `allow_nil?: false`, and `PayoutService.transfer_destination/1` resolves a
  `StorePayoutAccount` by store id. An affiliate has no shop, so registration
  creates one `:affiliate_payout` store to hold their MoMo destination.

  That buys the entire existing money rail — payable reads, refund netting,
  recovery, the Oban transfer, webhook reconciliation — with no new payout
  code, which is the code least safe to duplicate. The cost is that a row
  which is not a shop exists in the stores table, and every listing surface
  must exclude it. `Store.kind` and `PayoutStoreNeverLeaksTest` are that
  guard.
  """

  use Ash.Domain

  alias Emakola.Accounts.PhoneAuth
  alias Emakola.Affiliates.Affiliate

  resources do
    resource(Affiliate)
  end

  # transfer_destination/1 maps a provider string to a Paystack bank code.
  # Registering an affiliate on a provider outside this list would create
  # someone who can never be paid, so it is refused at the door.
  @momo_providers ~w(mtn vodafone airteltigo)

  @doc """
  Registers an affiliate and their payout container.

  The phone is normalised to E.164, so one person cannot become two accounts
  with two balances by typing their number differently.
  """
  def register(attrs) do
    phone = PhoneAuth.normalize(attrs[:phone] || attrs["phone"] || "")
    provider = to_string(attrs[:momo_provider] || attrs["momo_provider"] || "")

    with :ok <- validate_provider(provider),
         :ok <- validate_phone(phone),
         {:ok, store} <- create_payout_store(attrs, phone),
         {:ok, _account} <- create_payout_account(store, attrs, provider) do
      Affiliate
      |> Ash.Changeset.for_create(:register, %{
        phone: phone,
        name: attrs[:name] || attrs["name"],
        momo_number: attrs[:momo_number] || attrs["momo_number"],
        momo_provider: provider,
        payout_store_id: store.id
      })
      |> Ash.create(authorize?: false)
    end
  end

  @doc "Finds an affiliate however their number is spelled."
  def find_by_phone(phone) when is_binary(phone) do
    Affiliate
    |> Ash.Query.for_read(:by_phone, %{phone: PhoneAuth.normalize(phone)})
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Affiliate{} = affiliate} -> {:ok, affiliate}
      _ -> {:error, :not_found}
    end
  end

  defp validate_provider(provider) when provider in @momo_providers, do: :ok
  defp validate_provider(_provider), do: {:error, :unsupported_momo_provider}

  # PhoneAuth.normalize/1 always returns a binary, so "" is the only failure
  # shape there is — a catch-all clause here would be unreachable.
  defp validate_phone(""), do: {:error, :phone_required}
  defp validate_phone(phone) when is_binary(phone), do: :ok

  # Named and slugged from the phone so a human reading the stores table can
  # tell what this row is for. It is never resolved as a storefront: every
  # public read filters `kind == :shop`.
  defp create_payout_store(attrs, phone) do
    suffix = String.replace(phone, ~r/\D/, "")

    Emakola.Stores.Store
    |> Ash.Changeset.for_create(:create_payout_container, %{
      name: "#{attrs[:name] || attrs["name"]} (affiliate payouts)",
      slug: "affiliate-#{suffix}"
    })
    |> Ash.create(authorize?: false)
  end

  defp create_payout_account(store, attrs, provider) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{
      store_id: store.id,
      payout_provider: :paystack,
      payout_destination: %{
        "method" => "mobile_money",
        "provider" => provider,
        "number" => attrs[:momo_number] || attrs["momo_number"],
        "account_name" => attrs[:name] || attrs["name"]
      }
    })
    |> Ash.create(authorize?: false)
  end
end
