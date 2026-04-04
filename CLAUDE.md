# Death Dice — Project Context

## What This Game Is

**Death Dice** is a dice-rolling roguelike built in Godot 4.6.1 (mono). The core loop is inspired by two sources:

- **Balatro** — progression structure: the player advances through increasingly difficult levels/stages in a run. Each run is self-contained. Between stages the player can upgrade/empower their dice pool. The goal each stage is to hit a target score with your dice rolls.
- **Cubitos** (board game) — dice-rolling mechanic: the player has a pool of custom dice. Each turn they roll all dice simultaneously. Some faces trigger a "stop" (bust risk). The player may selectively **reroll** any subset of non-stop dice, keeping good results and fishing for better ones. The tension is: keep rolling for more points vs. locking in a safe score.

## Core Gameplay Loop

```
Start Run
  └── Begin Stage (target score shown)
        └── Roll Phase
              ├── Player rolls entire dice pool
              ├── Player views results
              ├── Player selects dice to KEEP or REROLL
              ├── Rerolled dice are re-thrown
              └── Repeat until player banks or busts
        └── Bank / Bust
              ├── Bank: score added, advance to next stage
              └── Bust: run ends (roguelike permadeath)
  └── Between Stages: Shop / Upgrade
        ├── Buy new dice (expand pool — this is the primary spend; bigger pools = more fun)
        ├── Empower existing dice (upgrade faces)
        └── Buy passive modifiers (joker-equivalents)
  └── If all stages cleared: Win screen
```

## Key Mechanics

### Dice Pool
- Player starts with a small base set of dice (e.g., 4-6 dice).
- **Rolling huge numbers of dice at once is a core fantasy** — the pool can grow very large (20+ dice) as the player buys more between stages. The satisfying chaos of throwing a massive fistful of dice is a primary source of fun.
- Dice have multiple faces with different symbols/values.
- Dice can be upgraded between stages to replace weak faces with stronger ones.

### Rolling & Rerolling (Cubitos-style)
- All dice in the pool are rolled at once.
- Player sees all results simultaneously.
- Player selects any dice to reroll (hold/keep others).
- **Stop faces**: landing STOP shows the die red, but the player CAN pick it up and reroll it. Stops are NOT permanent.
- **Running stop counter**: a running total of STOP faces rolled this turn. Each new STOP adds to the counter; picking up a stopped die does NOT reduce it. Counter resets to 0 on bank, bust, or new turn. If counter (minus shields) ≥ bust threshold → bust.
- **Shield faces**: absorb stops during bust check (reduce effective stop count).
- **Explode faces**: score their value AND immediately chain-reroll the die. If EXPLODE lands again, chains continue.
- Rerolling is free but risky — stops build up across rerolls.

### Empowerment / Roguelike Progression
- Dice can be upgraded with special face types (multipliers, special symbols).
- Passive card-like modifiers (inspired by Balatro's Jokers) augment scoring.
- Each run is unique — order of upgrades available is randomised.
- Score targets scale up each stage within a run.

## Technical Stack

| Layer | Choice |
|---|---|
| Engine | Godot 4.6.1 stable mono |
| Language | GDScript (primary), C# (available via mono) |
| Platform | Windows (primary dev target) |
| AI tooling | godot-mcp for live editor control |
| Branch | `feature/claude` — AI agent workspace |

## Project Structure

```
death-dice/
├── Scenes/
│   ├── Main.tscn         # Root scene (RollPhase.gd attached)
│   ├── HUD.tscn          # HUD label panel
│   ├── DiceTray.tscn     # Dynamic die-button grid
│   ├── DieButton.tscn    # Single die button template
│   └── ShopPanel.tscn    # Between-stage shop UI
├── Scripts/
│   ├── RollPhase.gd      # Turn state machine (roll/reroll/bank/bust)
│   ├── GameManager.gd    # Autoload: score, lives, stage, gold, dice pool
│   ├── SaveManager.gd    # Autoload: run persistence, highscore
│   ├── HUD.gd            # Observe-only label renderer
│   ├── DiceTray.gd       # Manages grid of DieButton instances
│   ├── DieButton.gd      # Single die visual + toggle + pop animation
│   ├── DiceData.gd       # Resource: die with N faces + factory methods
│   ├── DiceFaceData.gd   # Resource: single face (type + value)
│   ├── ShopItemData.gd   # Resource: shop item definition
│   ├── ShopPanel.gd      # Between-stage shop logic + purchase handling
│   └── RunSaveData.gd    # Resource: run snapshot for persistence
├── Mcp/godot-mcp/        # MCP server for AI → Godot communication
├── .github/
│   ├── copilot-instructions.md
│   └── copilot/skills/
│       ├── godot-gdscript-patterns.md
│       └── game-design-fun.md
└── CLAUDE.md             # This file
```

## GDScript Conventions (enforced)

- **Static typing everywhere** — all variables, parameters, and return types annotated.
- **Signals for decoupling** — scenes never reach into each other directly; communicate via signals.
- **`@onready` for node refs** — never call `get_node()` in `_process()`.
- **Autoloads for global state** — `GameManager`, `SaveManager` as autoloads; keep them minimal.
- **Resources for data** — dice definitions, stage configs etc. stored as `Resource` subclasses.
- **No magic numbers** — constants or exports only.
- **GDScript patterns skill** at `.github/copilot/skills/godot-gdscript-patterns.md` — follow all patterns therein.

## Current State of the Codebase

The full game loop is implemented and playable:
- **Roll phase**: roll all dice → view results → select keep/reroll → reroll → repeat until bank or bust.
- **Bust protection**: turn 1 is immune; turns 2-3 have lenient threshold (4); turns 4+ standard (3).
- **Running stop counter**: every STOP rolled adds to a running total for the turn. Picking up a die does NOT reduce the counter. Counter resets on bank/bust/new turn. Bust check uses this counter minus shields against threshold.
- **Rerollable stops**: STOP faces show red but player can click to pick them up and reroll. Cubitos-style informed risk.
- **Shield mechanic**: SHIELD faces auto-keep and absorb stops during bust check (reduces effective stop count).
- **Multiplier mechanic**: MULTIPLY faces auto-keep and multiply the entire turn score when banking.
- **Explode mechanic**: EXPLODE faces score their value and chain-reroll the die. Chains until non-EXPLODE.
- **Lives system**: 3 lives per run; bust costs one life; 0 lives = run over.
- **Endless loop progression**: Loop 1 has 5 stages, loop 2+ has 7 stages. Clearing all stages advances to the next loop with scaled targets and gold bonuses. Run only ends on death.
- **Stage targets scale by loop**: base × (1 + 0.5 × (loop−1)). Loop 1: 30–130, Loop 2: 45–270, etc.
- **Gold economy**: 1 gold per banked point + scaled bonus on stage clear (20 + 10 per loop).
- **Cubitos-inspired dice lineup**: Standard (1 stop), Lucky (1 stop), Gambler (2 stops), Golden (2 stops), Heavy (2 stops), Explosive (3 stops), Blank Canvas (1 stop, upgrade target).
- **Between-stage shop**: Standard Die (20g), Blank Canvas (10g), Lucky Die (50g), Empower Die (30g). Loop 2+ unlocks Gambler (40g), Golden (50g), Heavy (45g), Explosive (60g).
- **Dice balance invariant**: every die always retains at least 1 STOP face; upgrades skip the last STOP.
- **Dice pool growth**: pool starts at 5 dice, grows via shop purchases between stages.
- **Save system**: runs persisted to disk with highscore, stages_cleared, and loops_completed tracking.
- **New Run button**: appears on game over; saves run and resets.
- **Hot Streak bonus**: 3 consecutive banks without bust = x1.1 score; 5+ = x1.2. Resets on bust or stage change.
- **Jackpot clean sweep**: bank on first roll with 5+ dice and 0 stops = +25% gold bonus + "JACKPOT!" flash.
- **Shop refresh**: "Refresh Shop (5g)" button re-generates shop items. Mini gambling loop.
- **Upgrade face preview**: Empower Die row shows candidate dice and their weakest face.
- **Personal best turn score**: tracked in GameManager; "NEW BEST TURN!" flash when beaten.
- **Bust risk indicator**: after each roll, HUD shows "Bust risk: LOW / MEDIUM / HIGH" based on stop count vs threshold.

## Roadmap (rough)

1. [x] Core dice rolling system (roll N dice, display faces)
2. [x] Reroll mechanic (select dice, reroll subset)
3. [x] Stop/bust mechanic
4. [x] Basic scoring and stage targets
5. [x] Stage progression loop
6. [x] Between-stage shop/upgrade screen
7. [x] Dice pool management (buy, upgrade faces)
8. [x] Dice balance invariant (every die keeps ≥1 STOP face)
9. [x] New face types (SHIELD absorbs stops, MULTIPLY amplifies score)
10. [x] New dice types (Runner, Shield, Multiplier — Cubitos-inspired)
11. [x] Endless loop progression (loops escalate targets and unlock dice)
12. [ ] Passive modifier system (Joker-equivalents)
13. [x] Run structure (start → stages → loops → die)
14. [ ] Polish: animations, sound, UI

## Agent Instructions

- Always run the project after code changes using the godot-mcp MCP tools and check `get_debug_output` for errors before reporting done.
- **Run the full GdUnit4 test suite before committing** and verify zero failures. **Redirect stdout/stderr to files** to avoid crashing VS Code with massive terminal output: `$proc = Start-Process -FilePath $godot -ArgumentList '--path','.','-s','res://addons/gdUnit4/bin/GdUnitCmdTool.gd','--add','res://test/' -PassThru -RedirectStandardOutput test_stdout.txt -RedirectStandardError test_stderr.txt ; $proc.WaitForExit(600000)` then check results with `Select-String -Path test_stdout.txt -Pattern "FAILED|Overall Summary"`. **Do NOT use `--headless`** — GdUnit4 does not support headless mode.
- **Add tests for every new feature or behaviour change**: every gameplay mechanic, logic change, or bug fix must be accompanied by new tests (unit, e2e, or integration as appropriate). Unit tests for pure logic; e2e/scene tests for anything involving UI or scene interaction. Do NOT commit new functionality without corresponding test coverage.
- **Run the full regression suite before every commit**: after adding or changing code, run *all* tests (`res://test/`) and verify zero failures before committing. Never commit with known test failures or skipped regressions.
- Commit working changes to `feature/claude` with descriptive conventional commit messages.
- Follow the GDScript patterns skill for all new code.
- Prefer signals over direct node references across scenes.
- Do not modify `master` branch directly.
- When in doubt about game design decisions, ask — don't guess.
