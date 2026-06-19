defmodule Emakola.Payments.SettlementBanks do
  @moduledoc """
  Resolves a Mobile Money provider to the Paystack `settlement_bank` code used
  when creating a payout subaccount (SP1).

  Paystack keys `settlement_bank` off the **`code`** field from its List Banks
  endpoint (`GET /bank?currency=GHS&type=mobile_money`), not the slug. This
  module fetches that list live and returns the authoritative `code`, so we
  track Paystack's data (e.g. the Vodafone→Telecel rebrand) instead of guessing.

  `settlement_code/1` never raises: any live failure (missing keys, network
  error, status false, provider absent) degrades silently to a last-known-good
  static code so payout onboarding never breaks. A known provider always yields
  a code; an unknown provider string is returned verbatim and never triggers an
  API call.
  """

  require Logger

  # provider => %{code: static fallback, slugs: candidate slugs, names: name substrings}.
  # The static `code` is the last-known-good Paystack GH MoMo settlement code; the
  # live lookup is authoritative when reachable.
  @providers %{
    "mtn" => %{code: "MTN", slugs: ~w(mtn-mobile-money mtn-momo mtn), names: ["mtn"]},
    "vodafone" => %{
      code: "VOD",
      slugs: ~w(vod-mobile-money vodafone-cash telecel-cash vodafone telecel),
      names: ["vodafone", "telecel"]
    },
    "airteltigo" => %{
      code: "ATL",
      slugs: ~w(atl-mobile-money airteltigo-money airteltigo atl),
      names: ["airtel", "tigo"]
    }
  }

  # Keyword list (not a map) so the query string order is deterministic.
  @list_params [currency: "GHS", type: "mobile_money"]

  @doc """
  Returns the `settlement_bank` code for `provider` ("mtn" | "vodafone" |
  "airteltigo"). Unknown providers are returned verbatim.
  """
  @spec settlement_code(String.t()) :: String.t()
  def settlement_code(provider) do
    case Map.fetch(@providers, provider) do
      :error -> provider
      {:ok, config} -> resolve(provider, config)
    end
  end

  defp resolve(provider, %{code: fallback} = config) do
    case fetch_banks() do
      {:ok, banks} ->
        case match_code(banks, config) do
          code when is_binary(code) ->
            code

          _ ->
            # Lookup succeeded but the provider was not in Paystack's list — a
            # data-drift signal, distinct from an outright failure.
            Logger.warning(
              "[settlement_banks] #{provider} not found in live List Banks; " <>
                "using static code #{fallback}"
            )

            fallback
        end

      {:error, reason} ->
        Logger.warning(
          "[settlement_banks] List Banks lookup failed for #{provider} " <>
            "(#{inspect(reason)}); using static code #{fallback}"
        )

        fallback
    end
  end

  defp fetch_banks do
    case paystack_client().list_banks(@list_params) do
      {:ok, %{"status" => true, "data" => banks}} when is_list(banks) -> {:ok, banks}
      {:ok, resp} -> {:error, {:unexpected_response, resp}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Considers only mobile-money entries (type absent is allowed defensively),
  # matches by slug first then by name substring, and returns that entry's code.
  defp match_code(banks, %{slugs: slugs, names: names}) do
    momo = Enum.filter(banks, &(&1["type"] in [nil, "mobile_money"]))

    entry =
      Enum.find(momo, fn b -> downcase(b["slug"]) in slugs end) ||
        Enum.find(momo, fn b -> name_matches?(b["name"], names) end)

    entry && entry["code"]
  end

  defp name_matches?(name, substrings) when is_binary(name) do
    down = downcase(name)
    Enum.any?(substrings, &String.contains?(down, &1))
  end

  defp name_matches?(_name, _substrings), do: false

  defp downcase(nil), do: ""
  defp downcase(str) when is_binary(str), do: String.downcase(str)

  defp paystack_client do
    Application.get_env(:emakola, :paystack_client, Emakola.Payments.PaystackClient)
  end
end
