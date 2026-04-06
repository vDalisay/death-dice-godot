# Death Dice - Gemini Agent Context

## Architecture & Conventions (Strict)
- **Project Lore & Mechanics:** If you need to understand the game loop, core mechanics, or current codebase state, read `ProjectInfo.md`.
- **GDScript 4.6.1 (Mono):** Static typing is mandatory for all variables, parameters, and return types.
- **Decoupling:** Scenes NEVER reach into each other directly. Use typed Signals for cross-scene communication.
- **Node Refs:** Always use `@onready` for node references. Never use `get_node()` inside `_process()`.
- **Data Models:** Use `Resource` subclasses for all game data (e.g., dice faces, stage configurations). Avoid magic numbers.
- **State Ownership:** `GameManager` (Autoload) owns mutable run state (score, lives, loop progression). UI panels are presentation-only. Keep Autoloads minimal.

## Git & Worktree Workflow
- **Parallel Worktrees:** Do feature work ONLY in dedicated agent worktrees, never in the main directory.
  - *Setup:* `git worktree add ../death-dice.worktrees/task-name -b feat/task-name feature/claude`
- **Integration:** The main workspace is reserved for merging into the `feature/claude` integration branch and running full regression tests.
- **Never modify the `master` branch directly.**

## Testing & Verification (Mandatory)
- **Test Coverage:** Every gameplay mechanic, logic change, or bug fix MUST be accompanied by new unit or e2e tests in `res://test/`.
- **Regression Gate:** Run the full GdUnit4 test suite before every commit. You must verify zero failures.
  - *Command:* `$proc = Start-Process -FilePath <godot_path> -ArgumentList '--path','.','-s','res://addons/gdUnit4/bin/GdUnitCmdTool.gd','--add','res://test/' -PassThru -RedirectStandardOutput test_stdout.txt -RedirectStandardError test_stderr.txt ; $proc.WaitForExit()`
- **No Headless Testing:** GdUnit4 does not support `--headless` in this project.
- **Runtime Checks:** Always run the project via `godot-mcp` after changes and check debug output for silent errors.

