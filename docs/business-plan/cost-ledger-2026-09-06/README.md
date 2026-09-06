# Cost ledger, 6 September 2026

`../cost-ledger-2026-09-06.html` is the report (also published as
https://claude.ai/code/artifact/dcc33a55-95fe-4ea8-a531-a3b6e657fa4e).

To refresh the numbers:

```bash
cd docs/business-plan/cost-ledger-2026-09-06
python3 cost_model.py     # prices and measured state at the top; writes cost_model.json
python3 render.py         # writes makola-cost-ledger.html next to it
python3 cc_usage.py       # Claude Code token usage from ~/.claude transcripts
```

Measured inputs came from `fly status`, `fly scale show`, `fly machines list`,
`fly volumes list`, `fly certs list`, and read-only SQL through
`/app/bin/emakola rpc` (see docs/RUNBOOK.md). Vendor prices were read on
6 September 2026 from the pages listed in the report's last section.
