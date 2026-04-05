## Plan: Multi-Agent Bug Fix Batch

Fix this bug/polish batch by splitting work along file-ownership boundaries instead of feature labels. Run only conflict-safe items in parallel: screen-flow work, arena physics work, and the isolated codex layout fix can happen together; gameplay-rule changes and score-bank feedback must wait because they share `RollPhase.gd` and `PhysicsDie.gd` with other streams.

**Steps**
1. Phase 0: Overseer setup and branch partitioning
- Create one dedicated worktree/branch per active stream instead of assigning bugs ad hoc.
- Reserve `feature/claude` for integration only; no bug implementation there.
- Use the overseer workflow to give each branch a bounded file-ownership charter before coding.
- Suggested streams:
  - Stream A: screen flow + transitions + archetype persistence + loop reveal memory.
  - Stream B: dice arena spawn/reroll feel.
  - Stream C: codex hover-face containment.
  - Stream D: gameplay rules + new support dice. *blocked on A because both need `RollPhase.gd`*
  - Stream E: banked score feedback + multiplier reposition. *blocked on A and B because it needs `RollPhase.gd` and `PhysicsDie.gd`*

2. Phase 1: Safe parallel workstreams
- Stream A: fix prestige-shop return leaving archetype cards invisible by correcting `ArchetypePicker._rebuild_archetype_cards()` / intro replay behavior; add first-time-per-loop reveal tracking in `StageMapPanel.open()` / `_play_intro()`; introduce a simple reusable transition layer for archetype picker, stage map, shop/prestige, new-run start, bust, and game-over overlays. This stream owns `RollPhase.gd`, `ArchetypePicker.gd`, `StageMapPanel.gd`, and any shared transition helper/scenes. *parallel with B and C*
- Stream B: fix large-pool spawn layout in `DiceArena._build_spawn_positions()` and tune reroll pacing/collision feel in `DiceArena._execute_reroll()` / `_reroll_volley_launch()` plus `PhysicsDie.play_reroll_lift()`. Keep this stream exclusive owner of `DiceArena.gd` and `PhysicsDie.gd` during the phase. *parallel with A and C*
- Stream C: fix hover face preview vertical/horizontal centering in `DiceCodexPanel._build_face_tile()` and any directly related container styling. Keep it isolated to codex UI only so it can merge at any time. *parallel with A and B*

3. Phase 2: Serial work on shared core gameplay files
- Stream D: after Stream A lands, change the default bust threshold from 3 to 4 while keeping lenient turns unchanged at 4; add the new starting shield die to the initial pool; add the new heart die to purchasable dice/content sources.
- Implement shield semantics as decided: any shield face rolled during the current turn absorbs stops rolled during that same turn even if that die is rerolled later; the effect does not persist into the next turn.
- Implement heart semantics as decided: each banked heart removes 1 from the stop counter at bank resolution only.
- Update related systems consistently: face enum/data, die factories, shop item definitions/purchases, codex text/icon mapping, roll-resolution math, HUD stop display text if needed, starting-loadout creation, and tests.
- Re-check interactions with `SHIELD_WALL`, `CURSED_STOP`, jackpot, heat bet, gambler’s rush, achievements, and bust-risk messaging so the counter math stays coherent.

4. Phase 3: Serial work on shared presentation/bank feedback
- Stream E: after Streams A and B land, rework banked score feedback so per-die point popups travel toward the HUD score bar, the bar thickens while filling, receives impact feedback on hits, and relaxes back afterward.
- Move multiplier fire VFX to the left-center of the dice tray field instead of the die location, coordinating `RollPhase` trigger timing with `PhysicsDie` effect placement and HUD score timing.
- Keep all bank-cascade presentation changes together because they share score sequencing in `RollPhase.gd` and VFX helpers in `PhysicsDie.gd`.

5. Phase 4: Integration and regression gate
- Merge order: C anytime; then B; then A; then D; then E. This minimizes `RollPhase.gd` and `PhysicsDie.gd` conflicts.
- After each merge, refresh active worktrees from `feature/claude` before starting the next blocked stream.
- Run targeted suites per stream before merge, then full regression once all streams are integrated.
- Run runtime smoke through the MCP workflow and manually exercise archetype start flow, shop/prestige flow, stage map re-open behavior, large-dice rerolls, and banking feedback.

**Relevant files**
- `c:/Users/Home/Documents/death-dice/Scripts/ArchetypePicker.gd` — prestige-shop return bug; intro rebuild behavior.
- `c:/Users/Home/Documents/death-dice/Scripts/StageMapPanel.gd` — loop reveal animation gating and panel intro behavior.
- `c:/Users/Home/Documents/death-dice/Scripts/RollPhase.gd` — transition orchestration, bust threshold, shield/heart resolution, bank-score animation sequencing, multiplier trigger timing.
- `c:/Users/Home/Documents/death-dice/Scripts/DiceArena.gd` — spawn layout and reroll volley pacing/collision tuning.
- `c:/Users/Home/Documents/death-dice/Scripts/PhysicsDie.gd` — reroll lift feel, shield ring VFX, score popup trajectory, multiplier VFX placement.
- `c:/Users/Home/Documents/death-dice/Scripts/HUD.gd` — score bar fill/thickness/impact behavior and any target-anchor exposure for score popups.
- `c:/Users/Home/Documents/death-dice/Scripts/DiceCodexPanel.gd` — hover-preview face tile centering.
- `c:/Users/Home/Documents/death-dice/Scripts/DiceData.gd` — starting die and new heart die factories; loadout references.
- `c:/Users/Home/Documents/death-dice/Scripts/DiceFaceData.gd` — add `HEART` face type and metadata.
- `c:/Users/Home/Documents/death-dice/Scripts/ShopItemData.gd` — new purchasable die definitions.
- `c:/Users/Home/Documents/death-dice/Scripts/ShopPanel.gd` — support-die shop entries and purchase handling.
- `c:/Users/Home/Documents/death-dice/Scripts/GameManager.gd` — initial pool setup and any loop/seen-state persistence if chosen here instead of panel-local state.
- `c:/Users/Home/Documents/death-dice/Scripts/RollResolutionService.gd` — shield/heart stop-accounting helpers.
- `c:/Users/Home/Documents/death-dice/Scripts/BustFlowResolver.gd` — confirm threshold/effective-stop usage remains consistent.
- `c:/Users/Home/Documents/death-dice/Scripts/SFXManager.gd` — shield pulse / heart redemption / score-hit sound reuse or additions.
- `c:/Users/Home/Documents/death-dice/Scenes/Main.tscn` — transition-layer wiring if the helper is scene-based.
- `c:/Users/Home/Documents/death-dice/Scenes/ArchetypePicker.tscn` — picker transition integration if needed.
- `c:/Users/Home/Documents/death-dice/Scenes/StageMap.tscn` — map transition integration if needed.
- `c:/Users/Home/Documents/death-dice/test/unit/ArchetypePickerTest.gd` — add regression for prestige close preserving visible archetype cards.
- `c:/Users/Home/Documents/death-dice/test/unit/StageMapPanelTest.gd` — add first-view-per-loop reveal behavior coverage.
- `c:/Users/Home/Documents/death-dice/test/unit/DiceArenaTest.gd` — add spawn layout coverage for large pools.
- `c:/Users/Home/Documents/death-dice/test/unit/DiceArenaVolleyTest.gd` — add reroll pacing/launch expectations if feasible at unit level.
- `c:/Users/Home/Documents/death-dice/test/unit/RerollLogicTest.gd` — threshold and stop-accounting updates.
- `c:/Users/Home/Documents/death-dice/test/unit/DiceCodexPanelTest.gd` — add layout/container expectations if the test harness can inspect anchors/margins.
- `c:/Users/Home/Documents/death-dice/test/e2e/MainSceneTest.gd` — flow regressions for start/shop/map transitions.
- `c:/Users/Home/Documents/death-dice/test/e2e/Phase1JuiceTest.gd` — reroll/bank feedback and juice regressions.
- `c:/Users/Home/Documents/death-dice/test/e2e/StopRerollTest.gd` — shield/heart/threshold behavior regressions.

**Verification**
1. Stream A gate: run targeted tests for archetype/map/start-flow behavior and manually verify prestige close, repeated map open on the same loop, and overlay transitions.
2. Stream B gate: run arena-focused tests and manually verify large pools stay centered and rerolled dice no longer collide/slide unnaturally.
3. Stream C gate: run codex unit tests and manually verify face tiles stay centered inside their preview box.
4. Stream D gate: run rule-focused unit/e2e tests covering threshold, shield absorption within the same turn, banked heart reduction, and starting loadout composition.
5. Stream E gate: run juice/e2e tests plus manual validation of popup-to-bar motion, progress-bar thickening/relaxing, and left-center multiplier VFX placement.
6. Final gate: run the full gdUnit suite with redirected output, then Godot runtime smoke through the MCP workflow, then one manual run covering new run -> archetype -> map -> combat -> bank -> shop -> loop reveal revisit.

**Decisions**
- Default bust threshold changes from 3 to 4, but lenient turns do not shift upward.
- New shield behavior: any shield rolled in the current turn absorbs stops rolled in that same turn even if the die is later rerolled; no carryover to the next turn.
- New heart behavior: each banked heart removes 1 from the stop counter at bank resolution.
- Transition scope includes archetype picker, stage map, shop/prestige shop, new run / game start, bust overlays, and game-over overlays.
- Conflict rule: never assign two simultaneous streams that both modify `RollPhase.gd` or `PhysicsDie.gd`.

**Further Considerations**
1. Loop reveal persistence choice: prefer storing "seen loop reveals" in `GameManager` or save-backed run state if it must survive panel recreation; panel-local state is only sufficient if the panel instance persists for the whole run.
2. Transition helper scope: prefer one minimal reusable fade/slide helper rather than bespoke tweens in every panel, otherwise merge risk rises quickly.
3. New support dice unlock path: decide whether the shield die is part of the default starting pool only, also shop-purchasable, or both; current request explicitly requires a starting die and a purchasable heart die, but not yet a purchasable shield die.