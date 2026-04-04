# Death Dice — Copilot Instructions

This is a **dice-rolling roguelike** in Godot 4.6.1 (GDScript). See `CLAUDE.md` at the repo root for the full project context, game design, and agent instructions.

## Quick Reference

- **Game concept**: Balatro-style stage progression + Cubitos-style dice rolling (roll all, selectively reroll, bust on too many stops).
- **Language**: GDScript with full static typing.
- **Key skill file**: `.github/copilot/skills/godot-gdscript-patterns.md` — always apply these patterns.
- **AI branch**: `feature/claude`

## Coding Rules

- Static type all variables, parameters, and return values.
- Use signals to communicate across scenes — never reach into sibling/parent nodes directly.
- Cache node references with `@onready`, never inside `_process()`.
- Store game data (dice faces, stage configs) as `Resource` subclasses.
- Global systems (score, run state) go in Autoload singletons.
- No magic numbers — use `const` or `@export`.
- Run project via godot-mcp after changes and verify zero errors in debug output.
