defmodule Emakola.Suppliers.ContentStudio do
  @moduledoc "Creates and reviews channel content constrained to supplier-approved facts."

  require Ash.Query

  alias Emakola.Suppliers.{ContentDraft, ContentLocale, ListingImporter, SocialCard}

  def create_draft(actor, store_id, listing_id, opts \\ []) do
    with {:ok, listing} <- authorized_listing(actor, store_id, listing_id),
         {:ok, listing} <-
           Ash.load(listing, [offer: [:offer_variants, source_product: :images]],
             authorize?: false
           ) do
      facts = facts(listing)
      kind = Keyword.get(opts, :kind, :sales_kit)
      locale = Keyword.get(opts, :locale, "en-GH")

      ContentDraft
      |> Ash.Changeset.for_create(:create, %{
        store_id: store_id,
        listing_id: listing.id,
        kind: kind,
        locale: locale,
        source_facts: facts,
        source_facts_hash: facts_hash(facts),
        content: deterministic_content(facts, kind, locale),
        generator: "deterministic"
      })
      |> Ash.create(authorize?: false)
    end
  end

  def list(actor, store_id) do
    with :ok <- ensure_store_access(actor, store_id) do
      Emakola.Suppliers.list_content_drafts_for_store(store_id, authorize?: false)
    end
  end

  def approve(actor, store_id, draft_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, draft} <- Ash.get(ContentDraft, draft_id, authorize?: false),
         :ok <- ensure_draft_store(draft, store_id),
         {:ok, listing} <- authorized_listing(actor, store_id, draft.listing_id),
         {:ok, listing} <-
           Ash.load(listing, [offer: [:offer_variants, source_product: :images]],
             authorize?: false
           ),
         :ok <- ensure_fresh(draft, listing) do
      draft
      |> Ash.Changeset.for_update(:approve, %{approved_by_id: actor.id})
      |> Ash.update(authorize?: false)
    else
      error -> error
    end
  end

  def reject(actor, store_id, draft_id) do
    with :ok <- ensure_store_access(actor, store_id),
         {:ok, draft} <- Ash.get(ContentDraft, draft_id, authorize?: false),
         true <- draft.store_id == store_id do
      draft |> Ash.Changeset.for_update(:reject, %{}) |> Ash.update(authorize?: false)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  def facts_hash(facts),
    do:
      facts |> Jason.encode!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp authorized_listing(actor, store_id, listing_id) do
    with {:ok, listings} <- ListingImporter.list(actor, store_id),
         %{} = listing <- Enum.find(listings, &(&1.id == listing_id)) do
      {:ok, listing}
    else
      nil -> {:error, :forbidden}
      error -> error
    end
  end

  defp facts(listing) do
    product = listing.offer.source_product
    terms = listing.offer.offer_variants

    %{
      "product_title" => product.title,
      "supplier_description" => product.description || "",
      "delivery_areas" => listing.offer.delivery_areas,
      "return_terms" =>
        listing.offer.return_terms || "Ask the store about returns before ordering.",
      "prices" => Enum.map(terms, & &1.suggested_retail_price) |> Enum.sort(),
      "supplier_prices" => Enum.map(terms, & &1.supplier_price) |> Enum.sort(),
      "source_image_url" => product.images |> List.first() |> then(&(&1 && &1.url))
    }
  end

  defp deterministic_content(facts, :sales_kit, locale) do
    facts
    |> ContentLocale.render(locale)
    |> Map.put("social_card_data_uri", SocialCard.data_uri(facts))
  end

  defp deterministic_content(facts, kind, locale) do
    deterministic_content(facts, :sales_kit, locale)
    |> Map.put("kind", Atom.to_string(kind))
  end

  defp mark_stale(draft_id) do
    case Ash.get(ContentDraft, draft_id, authorize?: false) do
      {:ok, draft} ->
        _ = draft |> Ash.Changeset.for_update(:mark_stale, %{}) |> Ash.update(authorize?: false)
        {:error, :source_facts_changed}

      error ->
        error
    end
  end

  defp ensure_draft_store(%{store_id: store_id}, store_id), do: :ok
  defp ensure_draft_store(_draft, _store_id), do: {:error, :forbidden}

  defp ensure_fresh(draft, listing) do
    if facts_hash(facts(listing)) == draft.source_facts_hash do
      :ok
    else
      mark_stale(draft.id)
    end
  end

  defp ensure_store_access(%Emakola.Accounts.Merchant{id: merchant_id}, store_id) do
    Emakola.Accounts.StoreMembership
    |> Ash.Query.filter(merchant_id == ^merchant_id and store_id == ^store_id)
    |> Ash.Query.limit(1)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, [_membership]} -> :ok
      _ -> {:error, :forbidden}
    end
  end

  defp ensure_store_access(_actor, _store_id), do: {:error, :forbidden}
end
