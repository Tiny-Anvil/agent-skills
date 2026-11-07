# Setup questions

Ask them as structured multiple-choice questions (in Claude Code: AskUserQuestion): two rounds of up to four questions, then the follow-ups that apply. Put the
recommended option first. Offer only what this session can actually do: generative services are the MCPs (or CLIs) present
right now, and the opt-in rows mention their cost. Record every answer verbatim in `docs/RULES.md`.

## Round 1: what gets built

| Header | Question | Options |
|---|---|---|
| Assets | Where may models and textures come from? | **Self-authored only** (Blender by script, procedural or baked textures, nothing downloaded; the strictest) · **+ CC0 libraries** (Poly Haven, ambientCG, Quaternius; logged in credits.md) · **+ purchased packs** (from a folder the owner names) · **Anything licensed** (logged) |
| Generative | Which generative services may it use, as acknowledged exceptions to the asset rule? (multi-select) | **Tripo3D** (text/image to 3D + auto-rig; e.g. for enemy characters as an exception to "self-authored") · the 3D/animation MCPs this session has, e.g. **Meshy**, **Mixamo animations** · **None**. Offer a service only if its access works (MCP connected; for Tripo, `tripo doctor` passes) **and its balance is above zero** (`tripo balance`). |
| Audio | Where may sound come from? | **Real recordings from free libraries** (Pixabay and similar, logged) · **Synthesized/generated allowed** · **Both** · **No audio** |
| Quality | What bar should it aim for? | **AAA feel** (every placeholder is unfinished work) · **Polished indie** · **Playable prototype** (greybox fine) |

## Round 2: how the run is governed

| Header | Question | Options |
|---|---|---|
| Stop rule | When does the run end? | **Budget cap** (keep improving until $X is spent; needs the wallet) · **Completion conditions** (the brief's tests pass, no major defect open) · **Completion + cap** (whichever comes first) · **Time cap** (wall clock) |
| Reviews | Where should it pause for you? (multi-select) | **Brief approval** · **First working look** · **Midpoint** (half the cap, or after the behaviour pass) · **Final candidate** · **None** |
| Agents | How should the work be split? | **Lead + 1-2 helpers** (spawned agents, separate files each) · **Lead alone** (slowest, cheapest) · **Lead + role workers, no cap** (spawned agents per domain: city, enemies, audio…) · **+ workflows** (scripted parallel fan-out as well, e.g. Claude Code workflow scripts; the owner's explicit opt-in; costs the most) |
| Loop | What brings the lead back when it ends a turn? | **Self-paced loop in this session** (in Claude Code: `/loop`; re-prompts itself; the owner can watch) · **Detached driver** (a script re-runs `claude -p --resume <session> "continue per docs/RULES.md"` until the stop rule holds; survives the terminal) · **None** (one session; the run ends when the lead ends its turn) |

## Follow-ups (only when they apply)

- **Budget or time cap chosen:** "How much?" (free text: dollars, or an end time).
- **Budget chosen with the self-paced loop (Claude Code `/loop`):** "May I add a wallet writer to your status line?" (`wallet-statusline.md`).
  Without it, the run cannot read its spend. In that case, record that the owner enforces the cap and treat the
  stop rule as completion conditions. With a detached driver nothing is installed: the driver keeps
  `docs/WALLET.json` from each call's reported cost.
- **Generative service with credits (Tripo, Meshy):** "For which asset classes?" (e.g. characters/enemies only),
  "Credit cap?" and "May its own textures be kept?" Record them as one sentence in RULES.md, e.g. "Self-authored,
  except: Tripo3D for enemy characters, at most 300 credits, its textures may be kept; every task in credits.md".
- **Purchased packs:** "Which folder?"
- **Store page kit:** "Should the run make the store-page kit in its finish pass?" **None** (default) · **Steam**
  (capsules, library art, icons, ≥ 5 screenshots, a gameplay trailer, the AI-disclosure draft) · **itch.io** (cover,
  screenshots, the trailer) · **Both**. If not none: "AI key art?" **May propose it** (the run proposes at a review
  or in the final report and generates only after your yes, each time) · **Never**. Made with
  designing-game-store-pages.

## Not asked: derived or the builder's call

- The engine and its version (detected), and target resolution and FPS (in the brief).
- The game design, the scope, and anything else covered by the brief's "your real task".
