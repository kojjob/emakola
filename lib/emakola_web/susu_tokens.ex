defmodule EmakolaWeb.SusuTokens do
  @moduledoc """
  Signs and verifies buyer-authorization tokens for a susu plan's signed
  "My susu" progress link (TC-3 Task 7), delivered to the buyer at
  activation (Task 8's notification).

  `EmakolaWeb.TrackingTokens` is a distinct concern scoped to order
  tracking — a susu plan token must never authorize order-tracking actions
  and vice versa, so this gets its own module and salt, mirroring
  `TrackingTokens`' exact shape.

  Bare-code `/susu/:code` access is view + start only (the intentionally
  public entry point before activation — no token needed). Once a plan
  activates, chunk/edit/cancel require this token to verify AND match the
  specific plan (see `EmakolaWeb.Storefront.SusuLinkLive`).
  """

  @salt "susu_plan_v1"
  # Plans run up to 8 weeks (`SusuPlan.deadline`) plus slack for nudges and
  # the expiry sweep to converge — 120 days comfortably covers that.
  @max_age 60 * 60 * 24 * 120

  @doc "Signs a susu plan id as a buyer-authorization token for its signed link."
  def sign_susu_plan(plan_id) when is_binary(plan_id) do
    Phoenix.Token.sign(EmakolaWeb.Endpoint, @salt, plan_id)
  end

  @doc """
  Verifies a susu plan token. Returns `{:ok, plan_id}` or `{:error, reason}`.
  Safely rejects nil and non-binary input.
  """
  def verify_susu_plan(signed) when is_binary(signed) do
    Phoenix.Token.verify(EmakolaWeb.Endpoint, @salt, signed, max_age: @max_age)
  end

  def verify_susu_plan(_), do: {:error, :missing}
end
