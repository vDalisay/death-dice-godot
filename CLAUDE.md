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
        ├── Buy new dice (expand pool)
        ├── Empower existing dice (upgrade faces)
        └── Buy passive modifiers (joker-equivalents)
  └── If all stages cleared: Win screen
```

## Key Mechanics

### Dice Pool
- Player starts with a small base set of dice (e.g., 4-6 dice).
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
├── Scenes/          # .tscn scene files
│   └── Main.tscn    # Current main scene (placeholder box-picker demo)
├── Scripts/         # GDScript files
│   ├── game.gd      # Current placeholder game logic
│   └── show_text.gd # Legacy prototype (to be removed)
├── Mcp/godot-mcp/   # MCP server for AI → Godot communication
├── .github/
│   ├── copilot-instructions.md
│   └── copilot/skills/
│       └── godot-gdscript-patterns.md  # Godot 4 GDScript patterns skill
└── CLAUDE.md        # This file
```

## GDScript Conventions (enforced)

- **Static typing everywhere** — all variables, parameters, and return types annotated.
- **Signals for decoupling** — scenes never reach into each other directly; communicate via signals.
- **`@onready` for node refs** — never call `get_node()` in `_process()`.
- **Autoloads for global state** — `GameManager`, `EventBus` as autoloads; keep them minimal.
- **Resources for data** — dice definitions, stage configs etc. stored as `Resource` subclasses.
- **No magic numbers** — constants or exports only.
- **GDScript patterns skill** at `.github/copilot/skills/godot-gdscript-patterns.md` — follow all patterns therein.

## Current State of the Codebase

The repo currently contains a **placeholder prototype**: a 4-box clicking game used to validate the Godot MCP toolchain. This is NOT the final game. It demonstrates:
- Scene loading and running via MCP.
- Basic UI (Control nodes, Button, Label).
- Signal-based interaction.

All of this will be replaced or heavily extended as the actual dice game is built.

## Roadmap (rough)

1. [ ] Core dice rolling system (roll N dice, display faces)
2. [ ] Reroll mechanic (select dice, reroll subset)
3. [ ] Stop/bust mechanic
4. [ ] Basic scoring and stage targets
5. [ ] Stage progression loop
6. [ ] Between-stage shop/upgrade screen
7. [ ] Dice pool management (buy, upgrade faces)
8. [ ] Passive modifier system (Joker-equivalents)
9. [ ] Run structure (start → stages → win/lose)
10. [ ] Polish: animations, sound, UI

## Agent Instructions

- Always run the project after code changes using the godot-mcp MCP tools and check `get_debug_output` for errors before reporting done.
- Commit working changes to `feature/claude` with descriptive conventional commit messages.
- Follow the GDScript patterns skill for all new code.
- Prefer signals over direct node references across scenes.
- Do not modify `master` branch directly.
- When in doubt about game design decisions, ask — don't guess.
