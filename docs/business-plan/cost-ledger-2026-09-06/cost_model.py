import json
# ---- prices (USD unless _ghs) — PLACEHOLDER rows marked with "?" get replaced from research
P = dict(
  fx=11.37,                   # GHS per USD, xe.com 2026-09-06
  fly_512=3.62, fly_1gb=6.46, fly_2gb=12.14, fly_perf1x_2gb=35.17,   # London (lhr) list
  fly_pg_4gb=24.2,            # shared-cpu-2x 4GB, AMS $22.22 +9% lhr
  fly_pg_8gb_perf=92.8,       # performance-2x 8GB, AMS $85.17 +9% lhr
  fly_vol_gb=0.15, fly_cert_wild=1.00, fly_egress_gb=0.02, fly_rootfs_gb=0.15,
  tigris_gb=0.02, tigris_free_gb=5,
  resend_pro=20.0, resend_free=3000,
  sentry_team=26.0,
  domain_makola_io_yr=75.98, domain_emakola_com_yr=17.0,
  twilio_number=1.15,
  ai_snap=0.0057,             # measured tokens (1,682 in / 237 out per snap) at Sonnet 5 $2/$10
  ai_snap_sticker=0.0086,     # what the app's own ledger records ($3/$15 sticker)
  wa_utility=0.0040,          # Meta, Rest of Africa, from 2026-07-01
  sms_ghs=0.0288,             # Arkesel, GHS 20 top-up tier
  paystack_pct=0.0195,        # Ghana local + intl cards, no cap
  paystack_transfer_ghs=1.0,  # per MoMo transfer (bank = GHS 8)
)
# ---- measured production state (2026-09-06)
NOW = dict(stores=45, active=42, merchants=66, orders_aug=34, gmv_aug_ghs=56957.5, paid_ghs=4519.0,
           fees_settled_ghs=9.46, images=419, image_mb=39.8, db_mb=23, snaps_month=267, visits=719)

def infra(tier):
    if tier=="now":
        c = {"App machine 1GB (running)": P["fly_1gb"],
             "App machine 1GB (suspended, rootfs)": 0.6*P["fly_rootfs_gb"] + 0.3,   # ~600MB rootfs + occasional wake
             "Postgres 1GB machine": P["fly_1gb"], "Postgres volume 10GB": 10*P["fly_vol_gb"],
             "Wildcard certificate": P["fly_cert_wild"], "Egress + Tigris": 0.10}
    elif tier==500:
        c = {"App machines 2×1GB (always on)": 2*P["fly_1gb"], "Postgres 2GB machine": P["fly_2gb"],
             "Postgres volume 10GB": 10*P["fly_vol_gb"], "Wildcard certificate": P["fly_cert_wild"], "Egress + Tigris": 0.5}
    elif tier==2000:
        c = {"App machines 2×2GB": 2*P["fly_2gb"], "Postgres 4GB machine": P["fly_pg_4gb"],
             "Postgres volume 20GB": 20*P["fly_vol_gb"], "Wildcard certificate": P["fly_cert_wild"], "Egress + Tigris": 2.5}
    else:
        c = {"App machines 4×2GB": 4*P["fly_2gb"], "Postgres performance 8GB": P["fly_pg_8gb_perf"],
             "Postgres volume 50GB": 50*P["fly_vol_gb"], "Wildcard certificate": P["fly_cert_wild"], "Egress + Tigris": 12.0,
             "Sentry Team": P["sentry_team"], "Fly Standard support": 29.0}
    return c

def per_order(aov_ghs, take, wa_share=0.8, orders_per_payout=5):
    sms = P["sms_ghs"]/P["fx"]
    buyer = 4*(wa_share*P["wa_utility"] + (1-wa_share)*sms)
    merchant = 1*sms
    msgs = buyer+merchant
    gateway = P["paystack_pct"]*aov_ghs/P["fx"]
    transfer = (P["paystack_transfer_ghs"]/P["fx"])/orders_per_payout
    rev = take*aov_ghs/P["fx"]
    return dict(revenue=rev, gateway=gateway, messages=msgs, transfer=transfer, net=rev-gateway-msgs-transfer)

TIERS = {"now": dict(m=45, orders=36, new_m=37, aov=200, emails=150),
         500: dict(m=500, orders=5000, new_m=100, aov=200, emails=3000),
         2000: dict(m=2000, orders=20000, new_m=300, aov=200, emails=12000),
         10000: dict(m=10000, orders=100000, new_m=1000, aov=200, emails=60000)}

out = {"prices": P, "now": NOW, "tiers": {}, "per_order": {}}
for k, t in TIERS.items():
    inf = infra(k); infra_total = sum(inf.values())
    snaps = (NOW["snaps_month"] if k=="now" else t["new_m"]*7)   # measured 7 snaps per new shop
    ai = snaps*P["ai_snap"]
    po = per_order(t["aov"], 0.02)
    msgs = t["orders"]*po["messages"]
    email = 0.0 if t["emails"]<=P["resend_free"] else P["resend_pro"] + max(0,(t["emails"]-50000))*0.0009
    fixed = (P["domain_makola_io_yr"]+P["domain_emakola_com_yr"])/12 + P["twilio_number"]
    gateway = t["orders"]*po["gateway"]; transfer = t["orders"]*po["transfer"]
    rev2 = t["orders"]*t["aov"]*0.02/P["fx"]
    out["tiers"][str(k)] = dict(merchants=t["m"], orders=t["orders"], infra=inf, infra_total=round(infra_total,2),
        ai=round(ai,2), snaps=snaps, messaging=round(msgs,2), email=round(email,2), fixed=round(fixed,2),
        opex=round(infra_total+ai+msgs+email+fixed,2),
        gateway_borne=round(gateway,2), transfer_fees=round(transfer,2),
        revenue_at_2pct=round(rev2,2),
        net_at_2pct=round(rev2-gateway-transfer-(infra_total+ai+msgs+email+fixed),2),
        per_merchant_opex=round((infra_total+ai+msgs+email+fixed)/t["m"],3))
for take in (0.02,0.03,0.04,0.05):
    out["per_order"][str(take)] = {kk: round(v,4) for kk,v in per_order(200, take).items()}
out["per_order_ghs100"] = {str(t): {kk: round(v,4) for kk,v in per_order(100, t).items()} for t in (0.02,0.04)}
json.dump(out, open("./cost_model.json","w"), indent=1)
for k,v in out["tiers"].items():
    print(k, "infra", v["infra_total"], "ai", v["ai"], "msgs", v["messaging"], "email", v["email"], "fixed", v["fixed"], "OPEX", v["opex"], "| gateway", v["gateway_borne"], "rev2%", v["revenue_at_2pct"], "NET", v["net_at_2pct"], "| /merchant", v["per_merchant_opex"])
print("per order GHS200:", out["per_order"])
