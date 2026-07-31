defmodule Emakola.Payments.Protection do
  @moduledoc """
  Pure buyer-protection predicate (TC-2) — the single source of truth for
  whether an order/charge is protected.

  Order has a pay link → the link's `protected` field governs (`nil` counts
  as unprotected — legacy pre-Task-2 pay_links rows have `protected: NULL`).
  No pay link → the store's `buyer_protection_enabled` setting governs.

  Consumed by both `OrderSettlement.prepare/2` (decides the hold at charge
  time) and the admin/storefront badges (Task 11) — kept in one place so
  settlement and badge can never disagree.
  """

  def applies?(_store, %{protected: protected}), do: protected == true
  def applies?(store, nil), do: store.buyer_protection_enabled == true
end
