# Plan: Prestige Layer + Side-Bet Expansion

## TL;DR
Two independent features. Side-Bet Expansion adds 3 new gambling overlays in the shop alongside Double Down (InsuranceBet, HeatBet, EvenOddBet). Prestige Layer adds a skull currency earned at run-end, a separate PrestigePanel screen accessible from ArchetypePicker, and 7 permanent run-modifying unlocks that integrate into existing systems.

---

## Feature A: Side-Bet Expansion

### A1 — ShopItemData.gd
- Add 3 new `ItemType` enum values: `INSURANCE_BET`, `HEAT_BET`, `EVEN_ODD_BET`

### A2 — GameManager.gd
- Add fields: `insurance_payout: int = 0`, `heat_bet_target_stops: int = -1`, `heat_bet_payout: int = 0`, `even_odd_bet_is_even: bool = true`, `even_odd_bet_wager: int = 0`
- Add methods: `set_insurance_bet(payout)`, `resolve_insurance_bet() -> int`, `set_heat_bet(target, payout)`, `resolve_heat_bet(stops) -> int`, `set_even_odd_bet(is_even, wager)`, `resolve_even_odd_bet(even_count, odd_count) -> int`
- All bets cleared in `on_shop_entered()` and `reset_run()`

### A3 — 3 New Overlay Scenes

**InsuranceBetOverlay.gd + InsuranceBetOverlay.tscn**
- Player pays fixed 10g premium; if they bust this stage, `resolve_insurance_bet()` returns +25g (net +15g on bust)
- UI: shows premium cost, payout on bust, "Insures vs bust" flavor text
- Insurance bet clears at stage-clear OR bust (one-stage coverage only)

**HeatBetOverlay.gd + HeatBetOverlay.tscn**
- Player picks a target stop count (0–4 via buttons) + fixed 15g wager
- On bank: if `running_stop_counter == target` → +45g payout (3:1 net)
- UI: stop target picker with implied frequency labels (e.g. "2 stops: ~30% chance")

**EvenOddBetOverlay.gd + EvenOddBetOverlay.tscn**
- Player picks EVEN or ODD + wager amount (5–25g in 5g steps)
- On bank: count NUMBER-face dice among kept dice by parity; majority matches pick = 2:1 payout; **tie = push** (wager refunded)
- UI: wager selector buttons (5g/10g/15g/20g/25g), EVEN/ODD toggle, explicit "~50/50 — ties push" label

### A4 — ShopPanel.gd
- Add 3 used-this-shop flags: `_ib_used`, `_hb_used`, `_eo_used`; reset all in `open()`
- In `_generate_items()`, auto-add bet items if not used and gold meets minimum:
  - Insurance: `gold >= 10`
  - Heat: `gold >= 15`
  - Even/Odd: `gold >= 5`
- Preload 3 overlay scenes; on purchase, instantiate + `open()` overlay, mark used, deduct 10g premium instantly for Insurance
- Each bet displays as a shop card with title + explicit odds as its description line

### A5 — RollPhase.gd
- In `_on_bust()`: call `GameManager.resolve_insurance_bet()` → if payout > 0, append "Insurance paid out: +Xg" to the bust overlay message
- In `_on_bank_pressed()`:
  - Call `GameManager.resolve_heat_bet(running_stop_counter)` → if win, HUD callout "HEAT BET HIT! +Xg"
  - Count NUMBER-face values among kept dice by parity → call `GameManager.resolve_even_odd_bet(even_count, odd_count)` → flash win/push/loss banner

### A6 — Tests
- `test/unit/SideBetTest.gd`: unit test all 6 resolve methods with win/loss/no-bet/push inputs

---

## Feature B: Prestige Layer

### B1 — PrestigeUnlockData.gd (new Resource)
- `Scripts/PrestigeUnlockData.gd` extends `Resource`
- Fields: `unlock_id: String`, `display_name: String`, `description: String`, `skull_cost: int`
- Static `get_all() -> Array[PrestigeUnlockData]` returns all 7 unlock definitions:

| unlock_id | Name | Cost | Effect |
|---|---|---|---|
| `starting_gold` | Gold Reserve | 5☠ | +20g at run start |
| `shop_tier` | Market Insider | 8☠ | Loop 2+ dice available from loop 1 |
| `reward_reroll` | Second Glance | 10☠ | 1 free dice reward reroll per run |
| `reroute_token` | Cartographer | 12☠ | 1 free map reroute per run |
| `new_events` | Chaos Magnet | 15☠ | Unlocks 4 new event types |
| `new_archetype` | Fortune's Fool | 20☠ | New archetype: 10 Fortune dice, LUCK×2, 15g start |
| `skull_cosmetic` | Death's Glow | 10☠ | Skull shimmer cosmetic for all dice |

### B2 — SaveManager.gd
- Add vars: `prestige_currency: int = 0`, `prestige_unlocks: Array[String] = []`
- Add to `_save()` / `_load()` dict with backward-compat defaults (0 / `[]`)
- New methods: `add_prestige_currency(amount: int)`, `spend_prestige_currency(amount: int) -> bool`, `purchase_prestige_unlock(id: String) -> bool`, `has_prestige_unlock(id: String) -> bool`
- In `record_run()`, award skulls:
  ```
  skulls = loops_completed * 3
       + (2 if busts == 0)
       + (3 if loops_completed >= 3)
       + (5 if loops_completed >= 5)
  ```
  Minimum on first run: ~6 skulls (0 loops → 0 base; first unlock at 5☠)
- Emit new signal `prestige_currency_changed(new_total: int)`

### B3 — GameManager.gd
- Add prestige run-state flags (populated in `reset_run()` from SaveManager):
  - `prestige_starting_gold_bonus: int = 0`
  - `prestige_shop_tier_active: bool = false`
  - `prestige_reward_reroll_available: bool = false`
  - `prestige_reroute_uses: int = 0`
- Add `FORTUNE_FOOL` to `Archetype` enum; `ARCHETYPE_UNLOCK_LOOPS[FORTUNE_FOOL] = 0`; add to `ARCHETYPE_NAMES`, `ARCHETYPE_DESCRIPTIONS`
  - Fortune's Fool starting state: 10× Fortune d6, starting gold = 15g, LUCK bonus ×2 (applied in `_accumulate_luck()`)
- Add `apply_prestige_reward_reroll_used()` and `use_reroute_token()` helpers

### B4 — PrestigePanel.gd + PrestigePanel.tscn (new scene)
- ColorRect backdrop + PanelContainer modal (same theming pattern as `DoubleDownOverlay`)
- Header: skull icon + current skull balance
- Body: 7 unlock cards in a `VBoxContainer` (or 2-column `GridContainer`)
  - Each card: name, description, skull cost, owned badge OR buy button (disabled if insufficient skulls OR already owned)
- On purchase: `SaveManager.purchase_prestige_unlock(id)` → refresh display
- Signal `closed()`
- Instantiated by both `ArchetypePicker` and `HighlightsPanel`

### B5 — ArchetypePicker.gd
- Add "☠ PRESTIGE SHOP" button (below the run mode toggle buttons)
- On press: instantiate `PrestigePanel`, add as child, connect `closed` → remove + refresh archetype cards
- `Fortune's Fool` archetype card gated by `SaveManager.has_prestige_unlock("new_archetype")`, not `ARCHETYPE_UNLOCK_LOOPS`

### B6 — HighlightsPanel.gd
- Add "Skulls Earned: +X☠" stat card to the staggered reveal sequence (after the Busts card)
- Add "☠ Visit Prestige Shop" secondary button at the bottom (alongside / below the New Run button)
- On press: instantiate `PrestigePanel` as child

### B7 — Integration Touch Points (5 existing scripts)

**DiceRewardOverlay.gd — Reward Reroll**
- After generating 3 reward cards, if `GameManager.prestige_reward_reroll_available`, show a "Reroll Choices (1 left)" button
- On click: regenerate `_card_data[]`, rebuild cards, call `GameManager.apply_prestige_reward_reroll_used()`

**ShopPanel.gd — Shop Tier Bonus**
- In `_generate_items()`, if `GameManager.prestige_shop_tier_active`, extend the loop 1 dice candidate pool to include all loop 2+ dice types

**StageMap.gd / RollPhase.gd — Reroute Token**
- When a map row is pending node select and `GameManager.prestige_reroute_uses > 0`, show a "↺ Reroute" button on the map panel
- On click: call `GameManager.use_reroute_token()`, deselect current row, re-enable all nodes in that row

**StageEventOverlay.gd — New Events (Chaos Magnet)**
- Add 4 new event entries guarded by `SaveManager.has_prestige_unlock("new_events")` at the head of the blessing/curse pool:
  - **Windfall** (blessing): +5g per total stop accumulated this loop at run end
  - **Clone** (blessing): free duplicate of a random die added to pool
  - **Chaos** (curse): all die faces are shuffled/randomized this loop
  - **Debt** (curse): must spend 20g before banking or lose 1 life; persists until paid

**CosmeticData.gd — Skull Cosmetic**
- Add `"skull_shimmer"` cosmetic type; only purchasable in the mastery shop if `SaveManager.has_prestige_unlock("skull_cosmetic")`

### B8 — Tests
- `test/unit/PrestigeCurrencyTest.gd`: skull earning formula across loop/bust combos, `spend_prestige_currency` success/failure, `purchase_prestige_unlock` idempotence, `has_prestige_unlock` correctness
- `test/unit/PrestigeGameManagerTest.gd`: `reset_run()` correctly applies prestige bonus gold and flags based on SaveManager state

---

## Relevant Files

**New:**
- `Scripts/InsuranceBetOverlay.gd` + `Scenes/InsuranceBetOverlay.tscn`
- `Scripts/HeatBetOverlay.gd` + `Scenes/HeatBetOverlay.tscn`
- `Scripts/EvenOddBetOverlay.gd` + `Scenes/EvenOddBetOverlay.tscn`
- `Scripts/PrestigeUnlockData.gd`
- `Scripts/PrestigePanel.gd` + `Scenes/PrestigePanel.tscn`
- `test/unit/SideBetTest.gd`
- `test/unit/PrestigeCurrencyTest.gd`
- `test/unit/PrestigeGameManagerTest.gd`

**Modified:**
- `Scripts/ShopItemData.gd` — 3 new ItemType values
- `Scripts/GameManager.gd` — side-bet state, prestige flags, FORTUNE_FOOL archetype, reset_run() prestige application
- `Scripts/SaveManager.gd` — prestige_currency, prestige_unlocks, record_run skull award, new helpers
- `Scripts/ShopPanel.gd` — 3 new bet items + overlay instantiation
- `Scripts/RollPhase.gd` — bust/bank bet resolution hooks
- `Scripts/ArchetypePicker.gd` — Prestige Shop button, Fortune's Fool card gating
- `Scripts/HighlightsPanel.gd` — skulls earned card, Prestige Shop button
- `Scripts/DiceRewardOverlay.gd` — Reward Reroll button
- `Scripts/StageEventOverlay.gd` — 4 new prestige-gated events
- `Scripts/StageMap.gd` (or RollPhase.gd) — Reroute Token button
- `Scripts/CosmeticData.gd` — skull_shimmer cosmetic

---

## Verification Steps
1. Run full GdUnit4 suite — zero failures
2. Insurance: place bet in shop → bust → "+X Insurance payout" visible in bust overlay
3. Heat Bet: pick target N → bank with exactly N stops → payout received
4. Even/Odd: test all 3 outcomes (win/push/loss) in a single play session
5. Earn skulls after a run → amount shown in HighlightsPanel staggered reveal
6. Open PrestigePanel → buy **Gold Reserve** → confirm +20g at start of next run
7. Buy **Cartographer** → reroute button appears on map, works once per run
8. Buy **Second Glance** → Reroll Choices button appears in pick-3 reward overlay
9. Buy **Fortune's Fool** unlock → archetype appears in ArchetypePicker; run starts with 10 Fortune dice + 15g
10. `godot-mcp get_debug_output` after all changes — zero parser/runtime errors

---

## Decisions
- Side-bets placed in shop (same location as Double Down), one per shop visit
- Even/Odd counts only NUMBER-face dice among kept dice; ties = push
- Heat Bet: win condition = exact `running_stop_counter` at bank matches picked target
- Prestige currency name: **Skulls** (☠)
- Skull earning: auto-awarded at run end, `loops×3` + milestone bonuses; no manual reset mechanic
- PrestigePanel accessible from ArchetypePicker (pre-run) and HighlightsPanel (post-run)
- Fortune's Fool gated by prestige unlock, not `max_loops_completed`
- New events only enter pool when **Chaos Magnet** is purchased

## Scope Exclusions
- No prestige reset / manual sacrifice mechanic
- No online leaderboard
- Prestige cosmetics are additive alongside existing mastery cosmetics
