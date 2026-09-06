import json, glob, os, sys, collections
files = glob.glob(os.path.expanduser("~/.claude/projects/-Users-kojo-Projects-emakola*/**/*.jsonl"), recursive=True)
seen = {}
sessions = set(); first = None; last = None
per_month = collections.defaultdict(lambda: collections.Counter())
bad = 0
for f in files:
    try:
        with open(f, "r", errors="ignore") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except Exception:
                    bad += 1; continue
                if d.get("type") != "assistant": continue
                m = d.get("message") or {}
                u = m.get("usage")
                if not u: continue
                key = d.get("requestId") or m.get("id") or d.get("uuid")
                ts = d.get("timestamp") or ""
                model = m.get("model") or "unknown"
                sessions.add(d.get("sessionId"))
                if ts:
                    first = ts if first is None or ts < first else first
                    last = ts if last is None or ts > last else last
                # keep the entry with the largest output_tokens for a given request (streaming writes repeat usage)
                prev = seen.get(key)
                rec = (model, ts[:7], u.get("input_tokens",0), u.get("cache_creation_input_tokens",0), u.get("cache_read_input_tokens",0), u.get("output_tokens",0))
                if prev is None or rec[5] > prev[5]:
                    seen[key] = rec
    except Exception as e:
        bad += 1
tot = collections.defaultdict(lambda: [0,0,0,0,0])
for model, month, i, cw, cr, o in seen.values():
    t = tot[model]; t[0]+=1; t[1]+=i; t[2]+=cw; t[3]+=cr; t[4]+=o
    pm = per_month[month]; pm["req"]+=1; pm["in"]+=i; pm["cw"]+=cw; pm["cr"]+=cr; pm["out"]+=o
# list prices $/MTok: input, cache write (1.25x), cache read (0.1x), output
price = {
 "opus": (5, 6.25, 0.5, 25), "sonnet": (3, 3.75, 0.3, 15), "haiku": (1, 1.25, 0.1, 5), "fable": (10, 12.5, 1.0, 50), "mythos": (10, 12.5, 1.0, 50)
}
def p(model):
    for k,v in price.items():
        if k in model: return v
    return (5,6.25,0.5,25)
grand = 0
print(f"files={len(files)} sessions={len(sessions)} requests={len(seen)} first={first} last={last} badlines={bad}")
print("model | requests | input | cache_write | cache_read | output | list_cost_usd")
for model, t in sorted(tot.items(), key=lambda kv: -kv[1][4]):
    pi, pcw, pcr, po = p(model)
    cost = (t[1]*pi + t[2]*pcw + t[3]*pcr + t[4]*po)/1e6
    grand += cost
    print(f"{model} | {t[0]} | {t[1]:,} | {t[2]:,} | {t[3]:,} | {t[4]:,} | ${cost:,.0f}")
print(f"GRAND list-price equivalent: ${grand:,.0f}")
print("month | requests | output_tokens | cache_read")
for m in sorted(per_month):
    pm = per_month[m]; print(f"{m} | {pm['req']} | {pm['out']:,} | {pm['cr']:,}")
