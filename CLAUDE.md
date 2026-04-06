## GDScript Conventions (enforced)

- **Static typing everywhere** — all variables, parameters, and return types annotated.
- **Signals for decoupling** — scenes never reach into each other directly; communicate via signals.
- **`@onready` for node refs** — never call `get_node()` in `_process()`.
- **Autoloads for global state** — `GameManager`, `SaveManager` as autoloads; keep them minimal.
- **Resources for data** — dice definitions, stage configs etc. stored as `Resource` subclasses.
- **No magic numbers** — constants or exports only.
- **GDScript patterns skill** at `.github/copilot/skills/godot-gdscript-patterns.md` — follow all patterns therein.


## Agent Instructions

- **Project Lore & Mechanics:** If you need to understand the game loop, core mechanics, or current codebase state, read `ProjectInfo.md`.
- Always run the project after code changes using the godot-mcp MCP tools and check `get_debug_output` for errors before reporting done.
- **Run the full GdUnit4 test suite before committing** and verify zero failures. **Redirect stdout/stderr to files** to avoid crashing VS Code with massive terminal output: `$proc = Start-Process -FilePath $godot -ArgumentList '--path','.','-s','res://addons/gdUnit4/bin/GdUnitCmdTool.gd','--add','res://test/' -PassThru -RedirectStandardOutput test_stdout.txt -RedirectStandardError test_stderr.txt ; $proc.WaitForExit(600000)` then check results with `Select-String -Path test_stdout.txt -Pattern "FAILED|Overall Summary"`. **Do NOT use `--headless`** — GdUnit4 does not support headless mode.
- **Add tests for every new feature or behaviour change**: every gameplay mechanic, logic change, or bug fix must be accompanied by new tests (unit, e2e, or integration as appropriate). Unit tests for pure logic; e2e/scene tests for anything involving UI or scene interaction. Do NOT commit new functionality without corresponding test coverage.
- **Run the full regression suite before every commit**: after adding or changing code, run *all* tests (`res://test/`) and verify zero failures before committing. Never commit with known test failures or skipped regressions.
- Commit working changes to `feature/claude` with descriptive conventional commit messages.
- Follow the GDScript patterns skill for all new code.
- Prefer signals over direct node references across scenes.
- Do not modify `master` branch directly.
- When in doubt about game design decisions, ask — don't guess.
