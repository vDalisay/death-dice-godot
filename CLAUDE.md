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
- **Stop faces**: if accumulated stops reach the bust threshold, the turn ends forcibly (bust).
- Rerolling is free but risky — more rolls = more bust risk.

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
│   └── DieButton.tscn    # Single die button template
├── Scripts/
│   ├── RollPhase.gd      # Turn state machine (roll/reroll/bank/bust)
│   ├── GameManager.gd    # Autoload: score, lives, stage target
│   ├── SaveManager.gd    # Autoload: run persistence, highscore
│   ├── HUD.gd            # Observe-only label renderer
│   ├── DiceTray.gd       # Manages grid of DieButton instances
│   ├── DieButton.gd      # Single die visual + toggle + pop animation
│   ├── DiceData.gd       # Resource: die with N faces
│   ├── DiceFaceData.gd   # Resource: single face (type + value)
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

The core dice-rolling game loop is implemented and playable:
- **Roll phase**: roll all dice → view results → select keep/reroll → reroll → repeat until bank or bust.
- **Bust protection**: turn 1 is immune; turns 2-3 have lenient threshold (4); turns 4+ standard (3).
- **Lives system**: 3 lives per run; bust costs one life; 0 lives = run over.
- **Stage target**: score goal (500) to clear a stage.
- **Save system**: runs persisted to disk with highscore tracking.
- **New Run button**: appears on game over / stage clear; saves run and resets.

## Roadmap (rough)

1. [x] Core dice rolling system (roll N dice, display faces)
2. [x] Reroll mechanic (select dice, reroll subset)
3. [x] Stop/bust mechanic
4. [x] Basic scoring and stage targets
5. [ ] Stage progression loop
6. [ ] Between-stage shop/upgrade screen
7. [ ] Dice pool management (buy, upgrade faces)
8. [ ] Passive modifier system (Joker-equivalents)
9. [x] Run structure (start → stages → win/lose)
10. [ ] Polish: animations, sound, UI

## Agent Instructions

- Always run the project after code changes using the godot-mcp MCP tools and check `get_debug_output` for errors before reporting done.
- Commit working changes to `feature/claude` with descriptive conventional commit messages.
- Follow the GDScript patterns skill for all new code.
- Prefer signals over direct node references across scenes.
- Do not modify `master` branch directly.
- When in doubt about game design decisions, ask — don't guess.
