# Multi-Agent Worktree Workflow

This repo is using the correct basic pattern for parallel agent work:

- one Git worktree per agent
- one branch per worktree
- `feature/claude` as the integration branch

## Current Audit

As of 2026-04-03, the active layout is:

| Worktree | Branch | Notes |
|---|---|---|
| `C:/Users/Home/Documents/death-dice` | `feature/claude` | Integration worktree. Keep this for merges, reviews, and regression runs. |
| `C:/Users/Home/Documents/death-dice.worktrees/art-direction-pass-01` | `feat/art-direction-pass-01` | Active feature worktree. |
| `C:/Users/Home/Documents/death-dice.worktrees/prestige-sidebets` | `feature/prestige-sidebets` | Active feature worktree. |

## Recommended Rules

1. Do feature work only in agent worktrees.
2. Use the main worktree only for integration on `feature/claude`.
3. Give every active agent worktree its own branch.
4. Set an upstream for every active agent branch immediately after creation.
5. Use unique test log names per worktree to avoid confusion.
6. Remove stale worktrees after their branch is merged or abandoned.

## Create A New Agent Worktree

From the main repo root:

```powershell
git worktree add ../death-dice.worktrees/my-task -b feature/my-task feature/claude
git -C ../death-dice.worktrees/my-task push --set-upstream death-dice-godot feature/my-task
```

This creates a new worktree from the current integration branch and immediately makes pushes predictable.

## Daily Flow

1. Update `feature/claude` in the main worktree.
2. Create a fresh branch and worktree for each agent task.
3. Let each agent commit only inside its own worktree.
4. Merge validated agent branches back into `feature/claude`.
5. Run the regression gate in the main worktree.
6. Remove merged worktrees and prune metadata.

## Helpful Commands

List worktrees:

```powershell
git worktree list --porcelain
```

Inspect branch tracking:

```powershell
git branch -vv
```

Remove a stale worktree:

```powershell
git worktree remove C:/Users/Home/Documents/death-dice.worktrees/copilot-worktree-2026-03-25T21-02-14
git worktree prune
```

Check all worktrees for dirtiness:

```powershell
$worktrees = git worktree list --porcelain | Where-Object { $_ -like 'worktree *' } | ForEach-Object { $_.Substring(9) }
foreach ($wt in $worktrees) {
    Write-Output "=== $wt ==="
    git -C $wt branch --show-current
    git -C $wt status --short
}
```

## Repo-Specific Notes

- `.claude/worktrees/` is already ignored in `.gitignore`.
- `reports/` is ignored, so each worktree can generate its own gdUnit reports safely.
- If agents generate temporary stdout/stderr log files, prefer descriptive per-task names and delete them after use.

## Cleanup Notes

Stale worktrees were removed on 2026-04-03, leaving only the integration worktree plus the two active agent worktrees.

Do not remove active worktrees while an agent is still editing or while uncommitted changes exist.