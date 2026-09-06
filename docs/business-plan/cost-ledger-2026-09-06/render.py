import json, html
S="."
M=json.load(open(f"{S}/cost_model.json")); P=M["prices"]; FX=P["fx"]; T=M["tiers"]
def usd(x, d=2): return f"${x:,.{d}f}"
def ghs(x, d=2): return f"GH₵ {x:,.{d}f}"
def chip(kind):
    t={"measured":"measured","list":"list price","estimate":"estimate","unknown":"unknown"}[kind]
    return f'<span class="chip chip-{kind}">{t}</span>'

# ---------- ledger: today ----------
ai_real = M["now"]["snaps_month"]*P["ai_snap"]; ai_sticker = M["now"]["snaps_month"]*P["ai_snap_sticker"]
rows = [
 ("Fly app machine, 1 GB, running 24/7 (London)", P["fly_1gb"], "list", "shared-cpu-1x. Holds ~750 live storefront visitors before the September sweeper fix; more now."),
 ("Fly app machine, 1 GB, suspended", 0.45, "estimate", "Second machine wakes only past 100 connections. Billed for its rootfs (~$0.15) plus a few running hours."),
 ("Fly Postgres machine, 1 GB", P["fly_1gb"], "list", "Unmanaged postgres-flex 17, single node. Database is 23 MB for 45 shops."),
 ("Fly Postgres volume, 10 GB", 10*P["fly_vol_gb"], "list", "Daily snapshots (~0.7 GB stored) fall inside the free 10 GB."),
 ("Wildcard certificate *.makola.io", P["fly_cert_wild"], "list", "makola.io and www are two of the ten free single-host certificates."),
 ("Egress and Tigris storage", 0.10, "estimate", "40 MB of images in a 5 GB free tier; 719 visits in 12 days. Effectively zero."),
 ("Anthropic API (267 Snap-to-Shop calls)", ai_real, "measured", f"1,682 input + 237 output tokens per snap at Sonnet 5 $2/$10. The app's own ledger records {usd(ai_sticker)} because config still uses the $3/$15 sticker."),
 ("WhatsApp (Meta) and Arkesel SMS", 0.15, "estimate", "7 order notifications a week at $0.004 a message. Real token since 26 August."),
 ("Twilio number for the WhatsApp Business Account", P["twilio_number"], "list", "~£0.87 a month, bought 27 August."),
 ("Namecheap makola.io", P["domain_makola_io_yr"]/12, "list", "$75.98 a year at renewal (June 2027). First year was $34.98."),
 ("Namecheap emakola.com", P["domain_emakola_com_yr"]/12, "estimate", "Registered, not pointed at the app. Renewal invoice not seen."),
 ("Resend email", 0.0, "measured", "Under 200 emails a month; free tier is 3,000."),
]
today_total = sum(r[1] for r in rows)
ledger_rows = "".join(f'<tr><td>{html.escape(r[0])}</td><td class="num">{usd(r[1])}</td><td>{chip(r[2])}</td><td class="note">{r[3]}</td></tr>' for r in rows)

# ---------- per order ----------
def po(aov, take, wa=0.8, opp=5):
    sms=P["sms_ghs"]; buyer=4*(wa*P["wa_utility"]*FX+(1-wa)*sms); merchant=sms
    msgs=buyer+merchant; gw=P["paystack_pct"]*aov; tr=P["paystack_transfer_ghs"]/opp; rev=take*aov
    return dict(rev=rev, gw=gw, msgs=msgs, tr=tr, net=rev-gw-msgs-tr)
takes=[0.02,0.03,0.04,0.05]
po200={t:po(200,t) for t in takes}; po100={t:po(100,t) for t in takes}
def po_table(aov, d):
    head="".join(f"<th class='num'>{int(t*100)}% take</th>" for t in takes)
    def line(label, key, sign=""):
        return f"<tr><td>{label}</td>"+"".join(f"<td class='num'>{sign}{ghs(abs(d[t][key]))}</td>" for t in takes)+"</tr>"
    net="<tr class='total'><td>Makola keeps</td>"+"".join(f"<td class='num {'neg' if d[t]['net']<0 else 'pos'}'>{'−' if d[t]['net']<0 else '+'}{ghs(abs(d[t]['net']))}</td>" for t in takes)+"</tr>"
    return f"""<table class="ledger compact po"><thead><tr><th>{ghs(aov,0)} order</th>{head}</tr></thead><tbody>
{line('Fee revenue','rev')}{line('Paystack 1.95%','gw','−')}{line('Messages','msgs','−')}{line('Payout share','tr','−')}{net}</tbody></table>"""

# diverging chart: net per GHS200 order by take rate
def diverging_svg():
    W,H=760,196; x0=300; span=400; vmax=6.0; rowh=36; top=42
    def x(v): return x0+v/vmax*span
    parts=[f'<svg class="chart" viewBox="0 0 {W} {H}" role="img" aria-labelledby="dv-title"><title id="dv-title">Makola net per GH₵ 200 order at four take rates</title>']
    for tick in (-2,0,2,4,6):
        parts.append(f'<line x1="{x(tick):.1f}" y1="{top-8}" x2="{x(tick):.1f}" y2="{top+4*rowh}" class="grid"/><text x="{x(tick):.1f}" y="{top-14}" class="tick" text-anchor="middle">{"+" if tick>0 else ""}{tick}</text>')
    parts.append(f'<line x1="{x0}" y1="{top-8}" x2="{x0}" y2="{top+4*rowh}" class="baseline"/>')
    for i,t in enumerate(takes):
        v=po200[t]["net"]; y=top+i*rowh+7; h=20
        cls="neg" if v<0 else "pos"; xa=min(x0,x(v)); w=abs(x(v)-x0)
        r=4; # rounded data end
        if v<0: path=f'M{x0},{y} H{xa+r} a{r},{r} 0 0 0 -{r},{r} v{h-2*r} a{r},{r} 0 0 0 {r},{r} H{x0} Z'
        else:   path=f'M{x0},{y} H{x0+w-r} a{r},{r} 0 0 1 {r},{r} v{h-2*r} a{r},{r} 0 0 1 -{r},{r} H{x0} Z'
        tip=f"{int(t*100)}% take: revenue {ghs(po200[t]['rev'])} − gateway {ghs(po200[t]['gw'])} − messages {ghs(po200[t]['msgs'])} − payout {ghs(po200[t]['tr'])} = {'−' if v<0 else '+'}{ghs(abs(v))}"
        parts.append(f'<path d="{path}" class="bar {cls}" data-tip="{html.escape(tip)}"/>')
        lx = x(v)-6 if v<0 else x(v)+6
        anchor="end" if v<0 else "start"
        parts.append(f'<text x="{lx:.1f}" y="{y+14}" class="val" text-anchor="{anchor}">{"−" if v<0 else "+"}{ghs(abs(v))}</text>')
        parts.append(f'<text x="{x0-16}" y="{y+14}" class="lab" text-anchor="end">{int(t*100)}% take rate</text>' if v>=0 else f'<text x="{x0+16}" y="{y+14}" class="lab" text-anchor="start">{int(t*100)}% take rate</text>')
    parts.append(f'<text x="{x0}" y="{H-6}" class="tick" text-anchor="middle">GH₵ kept per GH₵ 200 order, after Paystack, messages and payout</text></svg>')
    return "".join(parts)

# composition chart by tier
tiers=[("now","Today · 45 shops"),("500","500 shops"),("2000","2,000 shops"),("10000","10,000 shops")]
series=[("Fly infrastructure","infra_total","s1"),("Messages (WhatsApp + SMS)","messaging","s2"),("Anthropic API","ai","s3"),("Email, domains, Twilio","fixed_email","s4")]
for k,_ in tiers: T[k]["fixed_email"]=T[k]["fixed"]+T[k]["email"]
def comp_svg():
    W,H=760,214; x0=180; span=470; rowh=40; top=36
    parts=[f'<svg class="chart" viewBox="0 0 {W} {H}" role="img" aria-labelledby="cp-title"><title id="cp-title">Share of monthly operating cost by tier</title>']
    for i,(k,label) in enumerate(tiers):
        tot=T[k]["opex"]; y=top+i*rowh; x=x0
        parts.append(f'<text x="{x0-12}" y="{y+16}" class="lab" text-anchor="end">{label}</text>')
        for name,key,cls in series:
            v=T[k][key]; w=v/tot*span
            if w<=0: continue
            tip=f"{label}: {name} {usd(v)} of {usd(tot)} ({v/tot*100:.0f}%)"
            parts.append(f'<rect x="{x:.1f}" y="{y}" width="{max(w-2,0):.1f}" height="22" class="seg {cls}" data-tip="{html.escape(tip)}"/>')
            if w>44: parts.append(f'<text x="{x+(w-2)/2:.1f}" y="{y+15}" class="seglab" text-anchor="middle">{v/tot*100:.0f}%</text>')
            x+=w
        parts.append(f'<text x="{x0+span+10}" y="{y+16}" class="val" text-anchor="start">{usd(tot,0)}/mo</text>')
    offs=[0,140,340,460]
    leg="".join(f'<g transform="translate({x0+offs[i]},{H-14})"><rect width="10" height="10" rx="2" class="seg {cls}"/><text x="14" y="9" class="tick" text-anchor="start">{name}</text></g>' for i,(name,_,cls) in enumerate(series))
    parts.append(leg+"</svg>")
    return "".join(parts)

tier_rows="".join(f"<tr><td>{label}</td><td class='num'>{T[k]['orders']:,}</td><td class='num'>{usd(T[k]['infra_total'])}</td><td class='num'>{usd(T[k]['messaging'])}</td><td class='num'>{usd(T[k]['ai'])}</td><td class='num'>{usd(T[k]['fixed_email'])}</td><td class='num total'>{usd(T[k]['opex'])}</td><td class='num'>{usd(T[k]['per_merchant_opex'],2)}</td><td class='num'>{usd(T[k]['opex']/T[k]['orders'],3)}</td></tr>" for k,label in tiers)
infra_detail="".join(f"<tr><td>{label}</td><td class='note'>"+"; ".join(f"{n} {usd(v)}" for n,v in T[k]["infra"].items())+"</td></tr>" for k,label in tiers)

# break-even at 4%
net4=po200[0.04]["net"]/FX
be=[(label, (T[k]["opex"]-T[k]["messaging"])/net4) for k,label in tiers]
be_rows="".join(f"<tr><td>{l}</td><td class='num'>{usd(T[k]['opex']-T[k]['messaging'])}</td><td class='num'>{n:,.0f}</td><td class='num'>{n/T[k]['merchants']:.2f}</td></tr>" for (l,n),(k,_) in zip(be,tiers))

# Claude usage table (measured 2026-07-11 → 2026-09-06; Sonnet 5 repriced at $2/$10)
cc=[("claude-fable-5",12509,10.90,5.24,7155),("claude-opus-5",16062,11.60,6.21,3988),("claude-fable-5-1",2028,2.23,0.85,1198),("claude-sonnet-5",14809,9.30,2.23,710),("claude-opus-4-8",3307,2.08,0.78,563),("claude-opus-4-7",199,0.11,0.01,34),("claude-haiku-4-5",838,0.32,0.04,9)]
cc_total=sum(r[4] for r in cc)
cc_rows="".join(f"<tr><td class='mono'>{m}</td><td class='num'>{r:,}</td><td class='num'>{o:.1f} M</td><td class='num'>{c:.2f} B</td><td class='num'>{usd(v,0)}</td></tr>" for m,r,o,c,v in cc)

CSS = r"""
:root{--paper:#f7f6f2;--surface:#ffffff;--ink:#0c1526;--ink-2:#3b4656;--muted:#6b7482;--rule:#dcd8cc;--rule-2:#ebe8df;--gold:#d4a843;--gold-text:#8f6a14;--gold-soft:#f5ecd3;--critical:#b42f2f;--good:#1a7f37;--chip-est:#8a8f99;
--s1:#2a78d6;--s2:#eb6834;--s3:#1baf7a;--s4:#eda100;--bar-neg:#d03b3b;--bar-pos:#0ca30c;--grid:#e6e2d6;}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--paper:#0c1526;--surface:#131f33;--ink:#efe9dc;--ink-2:#cfc8b8;--muted:#8896ab;--rule:#26334d;--rule-2:#1c2840;--gold:#d4a843;--gold-text:#e2bd5c;--gold-soft:#2a2a1e;--critical:#f08a8a;--good:#6cd08a;--chip-est:#8896ab;
--s1:#3987e5;--s2:#d95926;--s3:#199e70;--s4:#c98500;--bar-neg:#e66767;--bar-pos:#3fbf3f;--grid:#22304a;}}
:root[data-theme="dark"]{--paper:#0c1526;--surface:#131f33;--ink:#efe9dc;--ink-2:#cfc8b8;--muted:#8896ab;--rule:#26334d;--rule-2:#1c2840;--gold:#d4a843;--gold-text:#e2bd5c;--gold-soft:#2a2a1e;--critical:#f08a8a;--good:#6cd08a;--chip-est:#8896ab;
--s1:#3987e5;--s2:#d95926;--s3:#199e70;--s4:#c98500;--bar-neg:#e66767;--bar-pos:#3fbf3f;--grid:#22304a;}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font-family:"Archivo",system-ui,-apple-system,"Segoe UI",sans-serif;font-variation-settings:"wdth" 100;font-size:16px;line-height:1.55;-webkit-font-smoothing:antialiased}
.wrap{max-width:1040px;margin:0 auto;padding:40px 24px 80px}
.eyebrow{font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--gold-text);font-weight:600}
h1{font-size:clamp(34px,5vw,54px);line-height:1.02;margin:10px 0 14px;font-weight:800;font-variation-settings:"wdth" 112;letter-spacing:-.01em;text-wrap:balance}
.dek{font-size:19px;color:var(--ink-2);max-width:68ch;margin:0 0 28px}
h2{font-size:26px;line-height:1.15;margin:0 0 6px;font-weight:700;font-variation-settings:"wdth" 108;text-wrap:balance}
h3{font-size:17px;margin:26px 0 8px;font-weight:700}
section{padding:36px 0 8px;border-top:2px solid var(--rule);margin-top:24px}
section>.eyebrow{display:block;margin-bottom:6px}
p,li{max-width:68ch}
p{margin:10px 0}
ul{padding-left:20px}
li{margin:6px 0}
strong{font-weight:700}
.kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin:8px 0 6px}
.kpi{background:var(--surface);border:1px solid var(--rule);border-radius:6px;padding:16px 18px 14px;display:flex;flex-direction:column;gap:6px}
.kpi .v{font-family:"IBM Plex Mono",ui-monospace,Menlo,monospace;font-size:30px;font-weight:600;line-height:1.05;letter-spacing:-.02em}
.kpi .v.neg{color:var(--critical)}
.kpi .l{font-size:13px;color:var(--ink-2);line-height:1.35}
.kpi .l b{color:var(--ink)}
.tablewrap{overflow-x:auto;margin:14px 0 6px}
table.ledger{border-collapse:collapse;width:100%;font-size:14.5px}
table.ledger th{text-align:left;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);font-weight:600;padding:8px 10px;border-bottom:1px solid var(--rule)}
table.ledger td{padding:9px 10px;border-bottom:1px solid var(--rule-2);vertical-align:top}
table.ledger td.num,table.ledger th.num{text-align:right;font-family:"IBM Plex Mono",ui-monospace,Menlo,monospace;font-variant-numeric:tabular-nums;white-space:nowrap}
table.ledger td.note{color:var(--ink-2);font-size:13.5px;max-width:52ch}
table.ledger tr.total td{border-top:2px solid var(--ink);border-bottom:0;font-weight:700}
table.ledger .neg{color:var(--critical)} table.ledger .pos{color:var(--good)}
table.ledger td.mono{font-family:"IBM Plex Mono",ui-monospace,Menlo,monospace;font-size:13.5px}
table.compact td,table.compact th{padding:7px 10px}
.chip{display:inline-block;font-size:11px;letter-spacing:.06em;text-transform:uppercase;font-weight:600;padding:2px 7px;border-radius:3px;white-space:nowrap;border:1px solid transparent}
.chip-measured{background:var(--gold-soft);color:var(--gold-text);border-color:var(--gold)}
.chip-list{border-color:var(--ink-2);color:var(--ink-2)}
.chip-estimate{border-style:dashed;border-color:var(--chip-est);color:var(--chip-est)}
.chip-unknown{color:var(--muted);border-color:var(--rule)}
.callout{border-left:4px solid var(--gold);background:var(--surface);padding:14px 18px;margin:18px 0;border-radius:0 6px 6px 0}
.callout.crit{border-left-color:var(--critical)}
.callout p{margin:6px 0}
.chart{width:100%;height:auto;display:block;margin:14px 0 4px;font-family:"Archivo",system-ui,sans-serif}
.chart .grid{stroke:var(--grid);stroke-width:1}
.chart .baseline{stroke:var(--ink);stroke-width:1.5}
.chart .tick{fill:var(--muted);font-size:12px}
.chart .lab{fill:var(--ink);font-size:13px;font-weight:600}
.chart .val{fill:var(--ink);font-size:12.5px;font-family:"IBM Plex Mono",ui-monospace,monospace}
.chart .seglab{fill:#fff;font-size:11.5px;font-weight:600}
.chart .bar.neg{fill:var(--bar-neg)} .chart .bar.pos{fill:var(--bar-pos)}
.chart .seg.s1{fill:var(--s1)} .chart .seg.s2{fill:var(--s2)} .chart .seg.s3{fill:var(--s3)} .chart .seg.s4{fill:var(--s4)}
.chart .seg,.chart .bar{cursor:default}
#tip{position:fixed;pointer-events:none;background:var(--ink);color:var(--paper);font-size:12.5px;padding:7px 10px;border-radius:4px;max-width:340px;line-height:1.4;z-index:10;transform:translate(-50%,calc(-100% - 12px));font-family:"IBM Plex Mono",ui-monospace,monospace}
#tip[hidden]{display:none}
.facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px 18px;margin:12px 0 4px}
.fact .v{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:24px;font-weight:600;line-height:1.1}
.fact .l{font-size:12.5px;color:var(--muted);margin-top:2px}
.two{display:grid;grid-template-columns:1fr 1fr;gap:24px;align-items:start}
table.po td:first-child,table.po th:first-child{white-space:nowrap}
table.po td.num,table.po th.num{padding-left:6px;padding-right:6px}
.decisions li{margin:10px 0}
.small{font-size:13.5px;color:var(--ink-2)}
.sources li{font-size:13.5px;color:var(--ink-2);max-width:none}
.sources code,.small code,p code,li code{font-family:"IBM Plex Mono",ui-monospace,monospace;font-size:.92em;background:var(--rule-2);padding:1px 5px;border-radius:3px}
a{color:var(--gold-text);text-decoration-thickness:1px;text-underline-offset:2px}
a:focus-visible,[tabindex]:focus-visible{outline:2px solid var(--gold);outline-offset:2px}
@media (max-width:900px){.kpis{grid-template-columns:repeat(2,1fr)}.two{grid-template-columns:1fr}}
@media (max-width:520px){.kpis{grid-template-columns:1fr}.wrap{padding:28px 16px 60px}}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
"""

JS = r"""
(function(){var tip=document.getElementById('tip');
function show(e){var t=e.target.getAttribute('data-tip');if(!t)return;tip.textContent=t;tip.hidden=false;move(e);}
function move(e){tip.style.left=e.clientX+'px';tip.style.top=e.clientY+'px';}
function hide(){tip.hidden=true;}
document.querySelectorAll('[data-tip]').forEach(function(el){el.addEventListener('mouseenter',show);el.addEventListener('mousemove',move);el.addEventListener('mouseleave',hide);el.setAttribute('tabindex','0');el.addEventListener('focus',function(e){tip.textContent=el.getAttribute('data-tip');tip.hidden=false;var r=el.getBoundingClientRect();tip.style.left=(r.left+r.width/2)+'px';tip.style.top=r.top+'px';});el.addEventListener('blur',hide);});})();
"""

n=M["now"]; fees_ghs=n["fees_settled_ghs"]
page=f"""<title>Makola.io Cost Ledger</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,100..900&family=IBM+Plex+Mono:wght@400;600&display=swap">
<style>{CSS}</style>
<div class="wrap">
<span class="eyebrow">Makola.io · cost ledger · 6 September 2026</span>
<h1>Makola.io Cost Ledger</h1>
<p class="dek">What the platform costs to run today, what every order and every shop costs, what it costs as it grows, what building it has cost, and the one number that has to change before the live Paystack keys go in.</p>

<div class="kpis">
 <div class="kpi"><div class="v">{usd(today_total,0)}<span style="font-size:15px;font-weight:400"> /mo</span></div><div class="l"><b>To run today.</b> 45 shops, 2 Fly machines, 1 Postgres, domains, AI and messages. Fly's invoice is bigger: it carries three other apps.</div></div>
 <div class="kpi"><div class="v neg">−GH₵ {abs(po200[0.02]['net']):.2f}</div><div class="l"><b>Kept per GH₵ 200 order at 2%.</b> Paystack's 1.95% is charged to Makola, not the merchant, so the fee rail loses money on every order.</div></div>
 <div class="kpi"><div class="v">GH₵ {fees_ghs:.2f}</div><div class="l"><b>Platform fees settled, ever.</b> 4 settled splits on test-key orders. GH₵ 151 more sits pending on 19 orders.</div></div>
 <div class="kpi"><div class="v">{usd(cc_total,0)}</div><div class="l"><b>Claude tokens, 11 Jul – 6 Sep, at API list price.</b> Paid as a subscription, so the real cost is the plan fee. It is the largest cost line of the project.</div></div>
</div>

<section id="today">
<span class="eyebrow">Running cost · measured 6 September</span>
<h2>Twenty-seven dollars a month runs the whole platform</h2>
<p>Every line below was read from the live Fly account, the production database, or the vendor's current price list. Chips say which. Prices in London (lhr) run about 9% above Fly's Amsterdam table.</p>
<div class="tablewrap"><table class="ledger"><thead><tr><th>Line</th><th class="num">USD / month</th><th>Evidence</th><th>Note</th></tr></thead><tbody>{ledger_rows}<tr class="total"><td>Total</td><td class="num">{usd(today_total)}</td><td></td><td class="note">≈ GH₵ {today_total*FX:,.0f} a month at 11.37 GH₵/$.</td></tr></tbody></table></div>
<h3>Off this ledger, on purpose</h3>
<ul>
<li><strong>Paystack.</strong> Still the <code>sk_test</code> key. The 7 successful payments (GH₵ 4,519) were test-mode money. Once live keys go in, gateway fees become the biggest line by far, see the next section.</li>
<li><strong>Sentry, Cloudflare, GitHub Actions.</strong> $0. No <code>SENTRY_DSN</code> is set in production, DNS goes straight from Namecheap to Fly, and the repository is public so CI minutes are free (100 runs in the last 30 days, about 6 minutes each).</li>
<li><strong>Firebase push, Google Search Console, WhatsApp catalog sync.</strong> Free APIs.</li>
<li><strong>Your Claude subscription, Monid and Higgsfield credits for the ad videos, your own hours.</strong> Development and marketing, not running cost. The Claude part is sized below.</li>
<li><strong>Fly's other apps.</strong> pricelysis, transfilio and wellness-connect (each with a database) share the personal org. Read Makola's cost from this table, not from the Fly invoice.</li>
</ul>
</section>

<section id="order">
<span class="eyebrow">Per order · the number to fix</span>
<h2>At a 2% fee, every paid order loses about thirty pesewas</h2>
<p>The business plan says gateway fees are "passed through to the merchant". The code does the opposite: the Paystack split is sent with <code>bearer_type: "account"</code>, which makes Makola's main account pay the 1.95% on every charge. On orders from shops without a verified payout, the whole charge lands in Makola's account and is paid out later by transfer, so Makola bears the fee there too. Two percent in, 1.95% out, then messages and the GH₵ 1 MoMo transfer.</p>
<div class="two">
<div>{po_table(200, po200)}</div>
<div>{po_table(100, po100)}</div>
</div>
{diverging_svg()}
<p class="small">"Messages" is four buyer notifications (placed, confirmed, shipped, delivered) plus one merchant SMS. "Payout share" is one GH₵ 1 MoMo transfer spread over five orders. Message cost assumes 80% of buyers reachable on WhatsApp (utility template $0.004, Meta "Rest of Africa" rate from 1 July 2026) and 20% on Arkesel SMS at GH₵ 0.0288. Hover a bar for the arithmetic.</p>
<div class="callout crit">
<p><strong>Three ways out, in order of how easy they are to explain to a merchant who reads slowly.</strong></p>
<p>1. <strong>Charge 4% all-in and keep paying Paystack.</strong> "We keep 4 pesewas of every cedi." Makola keeps GH₵ {po200[0.04]['net']:.2f} of a GH₵ 200 order (46% of fee revenue). Paystack direct costs a merchant 1.95% plus their own payouts, so 4% for checkout, messages, a shop and payouts is still a fair pitch.</p>
<p>2. <strong>Let the merchant bear the gateway fee.</strong> One line in <code>lib/emakola/payments/gateways/paystack.ex</code>: <code>bearer_type: "subaccount"</code> with the merchant's subaccount as bearer. The 2% then nets GH₵ 3.60. But shops with no verified payout still route through Makola's account, so the non-split path needs its own fee deduction.</p>
<p>3. <strong>Add the fee to the buyer at checkout.</strong> Common in Ghana, unpopular with buyers, and it changes every theme's checkout copy.</p>
<p>Whichever you pick, it has to land before the live key. Today the rate is a config default (<code>:platform_fee_rate_bps</code>, 200) so option 1 is a one-value change.</p>
</div>
<h3>Break-even at 4%</h3>
<p>Take messaging out of operating cost (it is already inside the per-order figure) and divide what is left by the GH₵ {po200[0.04]['net']:.2f} kept per order.</p>
<div class="tablewrap"><table class="ledger compact"><thead><tr><th>Tier</th><th class="num">Fixed cost / mo</th><th class="num">Orders / mo to break even</th><th class="num">Orders per shop</th></tr></thead><tbody>{be_rows}</tbody></table></div>
<p>At 4%, one order a month per shop covers the platform. At 2% no volume ever does.</p>
</section>

<section id="shop">
<span class="eyebrow">Per shop · measured</span>
<h2>A shop costs about fifty cents a month to host and six cents to onboard</h2>
<div class="facts">
<div class="fact"><div class="v">{usd(T['now']['per_merchant_opex'])}</div><div class="l">operating cost per shop per month today (45 shops)</div></div>
<div class="fact"><div class="v">{usd(T['10000']['per_merchant_opex'])}</div><div class="l">at 10,000 shops</div></div>
<div class="fact"><div class="v">7</div><div class="l">Snap-to-Shop calls per new shop (267 calls, 37 new shops in August)</div></div>
<div class="fact"><div class="v">{usd(7*P['ai_snap'],3)}</div><div class="l">Anthropic cost to onboard one shop</div></div>
<div class="fact"><div class="v">0.5 MB</div><div class="l">database per shop (23 MB for 45)</div></div>
<div class="fact"><div class="v">95 KB</div><div class="l">average stored image (419 images, 40 MB)</div></div>
</div>
<p>The business plan budgeted GH₵ 15 of infrastructure and GH₵ 20 of SMS and WhatsApp per merchant per month, GH₵ 65 with support. The ledger says GH₵ {T['now']['per_merchant_opex']*FX:.0f} all-in today and GH₵ {T['10000']['per_merchant_opex']*FX:.1f} at scale, with messages costing GH₵ {po200[0.02]['msgs']:.2f} per order rather than a flat GH₵ 20. Support is your time and is not priced here.</p>
<p>Snap-to-Shop is the only AI feature with real usage: 267 of 269 calls in the month. Product descriptions and alt text were called once each. The blog generator (Sonnet, up to 3,000 tokens a post) shows no production usage since 5 August.</p>
</section>

<section id="scale">
<span class="eyebrow">Growth · projected from measured rates</span>
<h2>Infrastructure stays small. Messages grow with every order.</h2>
<p>Each tier assumes 10 orders a shop a month at GH₵ 200, 7 snaps per new shop, and the machine sizes the capacity benchmark calls for. Paystack fees are excluded here because they scale with revenue, not with cost.</p>
{comp_svg()}
<div class="tablewrap"><table class="ledger compact"><thead><tr><th>Tier</th><th class="num">Orders / mo</th><th class="num">Fly</th><th class="num">Messages</th><th class="num">Anthropic</th><th class="num">Email + fixed</th><th class="num">Operating cost</th><th class="num">Per shop</th><th class="num">Per order</th></tr></thead><tbody>{tier_rows}</tbody></table></div>
<h3>What each tier's Fly bill is made of</h3>
<div class="tablewrap"><table class="ledger compact"><tbody>{infra_detail}</tbody></table></div>
<h3>Capacity facts behind the sizes</h3>
<ul>
<li>One shared-cpu-1x machine renders storefronts at 75 to 90 requests a second and the landing page at 573. A 1 GB machine held about 750 live visitors before the idle-connection sweeper shipped on 6 September; the fix cut an idle handler from ~600 KB to under 8 KB.</li>
<li>The database is 23 MB. The 10 GB volume lasts past 10,000 shops at today's 0.5 MB a shop because images live in Tigris, not Postgres. Postgres RAM is the first thing to raise: 1 GB is the floor for two app machines at pool size 10; 2 GB when the third machine arrives.</li>
<li>Images cost $0.02 a GB a month on Tigris with free egress. 10,000 shops at 30 images each is 28 GB, or 56 cents.</li>
<li>Fly Managed Postgres starts at $38 a month for the same 1 GB, five times unmanaged. Worth it only when a lost night of orders costs more than the difference.</li>
<li>Sentry Team ($26) and a Fly support plan ($29) appear only in the 10,000-shop tier. Below that they are optional.</li>
</ul>
</section>

<section id="build">
<span class="eyebrow">Building it · measured from git and Claude Code transcripts</span>
<h2>The project's biggest cost is the tokens that wrote it</h2>
<div class="facts">
<div class="fact"><div class="v">1,828</div><div class="l">commits, 21 March to 4 September (168 days)</div></div>
<div class="fact"><div class="v">195 k</div><div class="l">lines in lib/, Elixir and HEEx</div></div>
<div class="fact"><div class="v">136 k</div><div class="l">lines of tests, 7,467 test cases</div></div>
<div class="fact"><div class="v">178</div><div class="l">database migrations</div></div>
<div class="fact"><div class="v">122</div><div class="l">Claude Code sessions on this machine since 11 July</div></div>
<div class="fact"><div class="v">49,767</div><div class="l">model requests in those sessions</div></div>
</div>
<p>The transcripts on this Mac start on 11 July, so the table covers 8 of the project's 24 weeks, roughly a fifth of the commits. Cost is what the same tokens would have been on the API at list price: input, cache writes at 1.25×, cache reads at 0.1×, output. Sonnet 5 is priced at its now-permanent $2/$10.</p>
<div class="tablewrap"><table class="ledger compact"><thead><tr><th>Model</th><th class="num">Requests</th><th class="num">Output tokens</th><th class="num">Cache-read tokens</th><th class="num">API list cost</th></tr></thead><tbody>{cc_rows}<tr class="total"><td>Total, 11 Jul – 6 Sep</td><td class="num">49,767</td><td class="num">36.5 M</td><td class="num">15.4 B</td><td class="num">{usd(cc_total,0)}</td></tr></tbody></table></div>
<div class="callout">
<p><strong>What you actually paid is the subscription.</strong> This machine is signed in on a Stripe subscription, not API billing. At $200 a month for Max that is about $400 for the same eight weeks, thirty-four times less than list. The comparison is the point: the plan is the cheapest engineering line the company has, and the reason a one-person, part-time, diaspora founder has 195 thousand lines of tested Elixir.</p>
<p>If the earlier sixteen weeks ran at the same pace, the whole build is in the region of $60,000 to $70,000 of API-equivalent tokens. A two-engineer, one-designer team for six months would have cost $13,000 to $24,000 at Accra senior rates or $145,000 to $215,000 at UK contract rates, and would not have shipped 22 themes.</p>
</div>
<p class="small">Cache reads are 99% of input tokens. That is the 1-hour prompt cache doing its job: each turn re-reads the conversation from cache at a tenth of the price. Fable 5 is 52% of the list cost on 25% of the requests.</p>
</section>

<section id="plan">
<span class="eyebrow">Business plan · reconciled</span>
<h2>Where the plan and the ledger disagree</h2>
<div class="tablewrap"><table class="ledger"><thead><tr><th>Item</th><th>Business plan (docs/business-plan)</th><th>This ledger</th></tr></thead><tbody>
<tr><td>Exchange rate</td><td>GH₵ 15.5 per dollar</td><td>GH₵ 11.37 (xe.com, 6 Sep 2026). Every dollar figure in the plan is 27% too high in cedis.</td></tr>
<tr><td>Gateway fee</td><td>Passed through to the merchant, outside Makola's P&amp;L</td><td>Borne by Makola on every split (<code>bearer_type: "account"</code>) and on every held charge</td></tr>
<tr><td>Infrastructure per merchant</td><td>GH₵ 15 a month</td><td>GH₵ {T['now']['per_merchant_opex']*FX:.0f} all-in today, GH₵ {T['10000']['per_merchant_opex']*FX:.1f} at 10,000 shops</td></tr>
<tr><td>SMS and WhatsApp per merchant</td><td>GH₵ 20 a month</td><td>GH₵ {po200[0.02]['msgs']:.2f} an order, about GH₵ 2 a month at 10 orders</td></tr>
<tr><td>Revenue per merchant</td><td>GH₵ 449 (GH₵ 49 plan + 2% of GH₵ 20,000)</td><td>Subscriptions were deferred in June. At 2% of GH₵ 2,000 of real volume: GH₵ 40 in, GH₵ 43 out.</td></tr>
<tr><td>Break-even</td><td>Month 4 at 85 merchants, subscription-led</td><td>At 4% fee-only: {be[0][1]:.0f} orders a month today. At 2%: never.</td></tr>
<tr><td>Team cost year 1</td><td>GH₵ 180,000 for four to five hires</td><td>One founder plus a Claude subscription. Unpriced, but see the previous section.</td></tr>
</tbody></table></div>
</section>

<section id="decide">
<span class="eyebrow">Decisions this ledger points to</span>
<h2>Four calls, one of them before the live key</h2>
<ul class="decisions">
<li><strong>Set the take rate to 4% all-in, or move the gateway fee to the merchant, before <code>PAYSTACK_SECRET_KEY</code> goes live.</strong> Today's default loses GH₵ 0.30 an order; nothing else in this document matters until that is fixed. Your call which lever; the first is one config value and one sentence for merchants.</li>
<li><strong>Leave the infrastructure alone.</strong> Two 1 GB machines and a 1 GB Postgres carry the first 500 shops. Raise Postgres to 2 GB when a third app machine is needed, not before.</li>
<li><strong>Fix the AI price table.</strong> <code>config/config.exs</code> still bills Sonnet 5 at $3/$15. The $2/$10 introductory rate became permanent, so the in-app cost ledger overstates by 50%.</li>
<li><strong>Keep WhatsApp first, but stop treating SMS as the expensive fallback.</strong> In Ghana an Arkesel SMS ($0.0025) now costs less than a WhatsApp utility message ($0.004). The <code>SUPPLIER_SMS_FALLBACK</code> ship-dark flag was gated on cost; the gate can open. From 1 October Meta also bills in-window replies at $0.004.</li>
</ul>
<p class="small">Numbers still unknown to me: which Claude plan you are on, what Monid and Higgsfield have billed for the ad videos, and the emakola.com renewal. None of them change the running-cost picture.</p>
</section>

<section id="method">
<span class="eyebrow">Method and sources</span>
<h2>How each number was obtained</h2>
<ul class="sources">
<li><strong>Fly inventory:</strong> <code>fly status</code>, <code>fly scale show</code>, <code>fly machines list</code>, <code>fly volumes list</code>, <code>fly certs list</code>, <code>fly secrets list</code> (names only), <code>fly storage list</code> against the emakola and emakola-db-lhr apps.</li>
<li><strong>Production data:</strong> read-only SQL through <code>/app/bin/emakola rpc</code>: table row counts, <code>pg_database_size</code>, sums over images, payments, orders, payment_splits, ai_usage and oban_jobs (Oban keeps 7 days).</li>
<li><strong>Claude Code usage:</strong> every assistant message's <code>usage</code> block in <code>~/.claude/projects/-Users-kojo-Projects-emakola*/</code>, de-duplicated by request id, priced at list.</li>
<li><strong>Vendor prices, all fetched 6 September 2026:</strong> <a href="https://fly.io/docs/about/pricing/">fly.io pricing</a>, <a href="https://fly.io/docs/mpg/">Fly Managed Postgres</a>, <a href="https://www.tigrisdata.com/pricing/">Tigris</a>, <a href="https://resend.com/pricing">Resend</a>, <a href="https://sentry.io/pricing/">Sentry</a>, <a href="https://www.namecheap.com/domains/registration/cctld/io/">Namecheap .io</a>, <a href="https://paystack.com/gh/pricing">Paystack Ghana</a> and support articles 2130306 and 2130370, <a href="https://explore.hubtel.com/legal/service-fees/">Hubtel service fees</a>, <a href="https://arkesel.com/pricing">Arkesel</a>, <a href="https://developers.facebook.com/docs/whatsapp/pricing/">Meta WhatsApp pricing</a> (USD rate CSV, July and October 2026 files), <a href="https://platform.claude.com/docs/en/about-claude/pricing">Anthropic pricing</a>, <a href="https://www.xe.com/">xe.com</a> for USD/GHS.</li>
<li><strong>Code facts:</strong> <code>order_settlement.ex</code> (2% default, 10% on dropship margin), <code>gateways/paystack.ex:221</code> (bearer), <code>order_notification_worker.ex</code> (4 buyer events, merchant SMS on placed and cancelled), <code>ai/prompts.ex</code> (model and token budgets), <code>server-capacity-benchmark.md</code>.</li>
<li><strong>Assumptions:</strong> GH₵ 200 average order (August's GH₵ 1,675 average is test data), 10 orders a shop a month, 80% WhatsApp reach, one payout per five orders, second Fly machine awake 5% of the time, London prices 9% above Amsterdam.</li>
</ul>
</section>
</div>
<div id="tip" hidden></div>
<script>{JS}</script>
"""
open(f"{S}/makola-cost-ledger.html","w").write(page)
print("written", len(page), "bytes; today total", round(today_total,2), "; net4 per order GHS", round(po200[0.04]["net"],2), "; break-even", [(l, round(n)) for l,n in be])
