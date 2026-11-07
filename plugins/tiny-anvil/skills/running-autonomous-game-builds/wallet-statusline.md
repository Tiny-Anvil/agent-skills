# Wallet: letting the run read its own spend

*Claude Code-specific: it relies on `claude -p` JSON output and the Claude Code status line. Other harnesses need
their own way to report spend, or a completion/time stop rule instead.*

**Under a detached driver, no status line is needed.** `claude -p --output-format json` reports `total_cost_usd`,
and on a `--resume` call that is the session's **running total** (measured 2026-10-08: 0.142 → 0.160 → 0.166 over
three calls; the third call's own usage, 29k cached tokens plus 4 output tokens, could not cost 0.166). The
driver in `kickoff-template.md` writes the latest value to `docs/WALLET.json`. Take the latest value, never a sum.

**In an interactive session (`/loop`),** use the status line writer below.

The model cannot see its cost. Claude Code passes it to the **status line** command on stdin:
`cost.total_cost_usd` (computed client-side as tokens × list price) and `session_id`. A few lines in the status
line script write it where the run can read it. This plays the part of a host-kept wallet file.

**Install only with the owner's OK.** It edits their status line script. Add it to the existing script, never
replace it: a status line is a single command.

Node (`~/.claude/hooks/statusline.js` or similar), called with the parsed stdin object:

```js
function writeWallet(data) {
  try {
    const usd = data?.cost?.total_cost_usd, sid = data?.session_id;
    if (!Number.isFinite(usd) || !sid) return;
    const dir = require('path').join(require('os').homedir(), '.claude', 'wallets');
    require('fs').mkdirSync(dir, { recursive: true });
    require('fs').writeFileSync(require('path').join(dir, `${sid}.json`),
      JSON.stringify({ session_id: sid, total_cost_usd: usd, at: new Date().toISOString() }));
  } catch (_) { /* a status line must never fail */ }
}
```

The run reads `~/.claude/wallets/<session-id>.json`. Its session ID is in its scratchpad path, or the one the driver
passed with `--session-id`.

**Limits. Check these on the first run and write them into RULES.md:**
- **Interactive only.** The status line renders only in an interactive session. Under a headless driver, use the
  driver's `docs/WALLET.json` instead.
- **Subagents.** Whether in-process subagents and workflows are included in the session total is unverified.
  Compare against `/cost` once.
- **Staleness.** The file updates when the status line renders, not continuously. Treat it as approximate and stop
  slightly before the cap.
