#!/usr/bin/env bash
#
# Post-keys validation — run this the moment real provider keys land in prod.
#
# Automates every checkable step of LAUNCH_TODO §8 (smoke) and §9 (revenue
# rails). The steps a human must do in a browser (register, place a test
# order, approve a payout) are in docs/POST_KEYS_VALIDATION.md, which tells
# you exactly which subcommand of this script verifies each one afterwards.
#
# Usage:
#   scripts/post_keys_validation.sh preflight            # secrets + endpoints + wss
#   scripts/post_keys_validation.sh payment REF          # a payment's status + splits
#   scripts/post_keys_validation.sh subaccount SLUG      # store's payout account state
#   scripts/post_keys_validation.sh payouts SLUG         # store's payouts + backlog
#   scripts/post_keys_validation.sh finance              # platform fee/owed totals
#
# Read-only throughout: nothing here mutates production.

set -euo pipefail

APP="emakola"
HOST="https://makola.io"

rpc() {
  fly ssh console --app "$APP" -C "/app/bin/emakola rpc \"$1\"" 2>&1 |
    grep -v "Connecting to"
}

case "${1:-}" in
  preflight)
    echo "── 1. Provider secrets (prefixes only — values never printed) ──"
    rpc "
for var <- ~w(PAYSTACK_SECRET_KEY PAYSTACK_PUBLIC_KEY RESEND_API_KEY SMS_API_KEY WHATSAPP_API_TOKEN) do
  v = System.get_env(var) || \\\"\\\"
  status = cond do
    v == \\\"\\\" -> \\\"UNSET\\\"
    String.contains?(String.downcase(v), \\\"dummy\\\") -> \\\"DUMMY — not ready\\\"
    String.starts_with?(v, \\\"sk_live\\\") or String.starts_with?(v, \\\"pk_live\\\") -> \\\"LIVE\\\"
    String.starts_with?(v, \\\"sk_test\\\") or String.starts_with?(v, \\\"pk_test\\\") -> \\\"TEST MODE\\\"
    true -> \\\"set (len=#{String.length(v)})\\\"
  end
  IO.puts(\\\"  #{var}: #{status}\\\")
end
"

    echo "── 2. Endpoints ──"
    printf "  %-32s HTTP %s\n" "$HOST" "$(curl -sL -o /dev/null -w '%{http_code}' --max-time 25 $HOST)"
    printf "  %-32s HTTP %s\n" "$HOST/api/health" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 $HOST/api/health)"

    echo "── 3. Webhook route live + signature check enforced (expect 401) ──"
    printf "  POST /webhooks/paystack (unsigned) -> HTTP %s\n" \
      "$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 -X POST -H 'Content-Type: application/json' -d '{}' $HOST/webhooks/paystack)"

    echo "── 4. LiveView websocket (a 200 page can hide a broken socket) ──"
    ws_status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
      -H "Origin: $HOST" \
      "$HOST/live/websocket?vsn=2.0.0")
    if [ "$ws_status" = "101" ]; then
      printf "  wss handshake -> 101 CONNECTED\n"
    else
      # curl cannot complete Phoenix's full socket negotiation (csrf/session),
      # so a non-101 here is INCONCLUSIVE, not a failure. Stage 1 settles it:
      # onboarding is a LiveView — a broken socket means forms won't submit.
      # Definitive check: browser DevTools -> Network -> WS -> /live/websocket
      # must show Status 101.
      printf "  wss handshake -> HTTP %s — inconclusive via curl; verify in browser DevTools (see note)\n" "$ws_status"
    fi
    ;;

  payment)
    REF="${2:?usage: payment <gateway_reference>}"
    rpc "
sq = <<39>>
q = fn sql -> Ecto.Adapters.SQL.query!(Emakola.Repo, sql, []).rows end
rows = q.(\\\"select status::text, amount, currency, split_mode::text from payments where gateway_reference = \\\" <> sq <> \\\"$REF\\\" <> sq)
case rows do
  [] -> IO.puts(\\\"payment $REF: NOT FOUND\\\")
  [[status, amount, cur, mode]] ->
    IO.puts(\\\"payment $REF: status=#{status} amount=#{amount} #{cur} split_mode=#{mode}\\\")
    splits = q.(\\\"select role::text, status::text, amount, coalesce(paystack_split_reference, (\\\" <> sq <> \\\"-\\\" <> sq <> \\\")::text) from payment_splits ps join payments p on p.id = ps.payment_id where p.gateway_reference = \\\" <> sq <> \\\"$REF\\\" <> sq)
    Enum.each(splits, fn [r, s, a, ref] -> IO.puts(\\\"  split #{r}: #{s} #{a} settlement_ref=#{ref}\\\") end)
    if splits == [], do: IO.puts(\\\"  (no splits — expected for split_mode=none)\\\")
end
"
    ;;

  subaccount)
    SLUG="${2:?usage: subaccount <store-slug>}"
    rpc "
sq = <<39>>
q = fn sql -> Ecto.Adapters.SQL.query!(Emakola.Repo, sql, []).rows end
rows = q.(\\\"select coalesce(a.subaccount_code, (\\\" <> sq <> \\\"-\\\" <> sq <> \\\")::text), a.verification_status::text from store_payout_accounts a join stores s on s.id = a.store_id where s.slug = \\\" <> sq <> \\\"$SLUG\\\" <> sq)
case rows do
  [] -> IO.puts(\\\"$SLUG: NO payout account — merchant has not saved payout details\\\")
  [[code, status]] -> IO.puts(\\\"$SLUG: subaccount=#{code} verification=#{status}\\\")
end
"
    ;;

  payouts)
    SLUG="${2:?usage: payouts <store-slug>}"
    rpc "
sq = <<39>>
q = fn sql -> Ecto.Adapters.SQL.query!(Emakola.Repo, sql, []).rows end
rows = q.(\\\"select p.status::text, p.amount, p.transfer_reference from payouts p join stores s on s.id = p.store_id where s.slug = \\\" <> sq <> \\\"$SLUG\\\" <> sq <> \\\" order by p.inserted_at desc limit 5\\\")
if rows == [], do: IO.puts(\\\"$SLUG: no payouts yet\\\")
Enum.each(rows, fn [s, a, ref] -> IO.puts(\\\"payout #{ref}: #{s} #{a}\\\") end)
[[owed]] = q.(\\\"select coalesce(sum(amount), 0) from payments pm join stores s on s.id = pm.store_id where s.slug = \\\" <> sq <> \\\"$SLUG\\\" <> sq <> \\\" and pm.status = \\\" <> sq <> \\\"success\\\" <> sq <> \\\" and pm.split_mode = \\\" <> sq <> \\\"none\\\" <> sq <> \\\" and pm.payout_held = false and pm.paid_out_at is null\\\")
IO.puts(\\\"outstanding backlog: #{owed}\\\")
"
    ;;

  finance)
    rpc "
IO.puts(\\\"platform fees (settled, net): #{Emakola.Platform.FinanceStats.total_platform_fees()}\\\")
IO.puts(\\\"outstanding owed to merchants: #{Emakola.Platform.FinanceStats.total_outstanding_payouts()}\\\")
"
    ;;

  *)
    grep '^#   scripts/' "$0" | sed 's/^#   //'
    exit 1
    ;;
esac
