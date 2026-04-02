# Implement "Dealer's Sweep" Dice Throw

## Objective

Rewrite the initial dice throw in `Scripts/DiceArena.gd` so dice spawn one at a time at launch, fired sequentially from a single emitter into a cone. This eliminates the current bug where all dice are instantiated into a tight grid before launching, causing pre-launch collisions that kill energy and make dice stand still.

## Root Cause Being Fixed

In `throw_dice()`, all dice are instantiated and placed into the physics world at once via `_build_spawn_positions()` before any launches happen. The grid packs them at ~99px spacing (COLLISION_RADIUS * 2.2) while die size is 90px. This means 20 dice are live RigidBody2D nodes pushing each other from frame 1. The stagger timer then fires impulses into already-jostling bodies. Early dice slam into unlaunched dice. Bump dampening (0.6^count) kills energy exponentially. Result: dice that collide early are dead within 0.5s.

## Design: Sequential Cone Sweep

### Spawn Model
- Single emitter point at lower center of the arena (reuse the existing `CENTER_BOTTOM` anchor position from `_spawn_position_for_origin`)
- Each die is instantiated into the scene tree at the exact moment it launches — NOT before
- Emitter jitter: ±15px horizontal, ±8px vertical per die (avoid exact overlap)
- Die starts unfrozen with `DiePhysicsState.FLYING` immediately

### Cone Targeting
- Base direction: from emitter toward `Vector2(ARENA_WIDTH / 2.0, ARENA_HEIGHT * 0.4)` (upper center of arena)
- Cone half-angle: 0.55 radians (~32°)
- Each die gets a direction within the cone: use a sweep bias from left-to-right across the sequence, plus random jitter within ±0.15 radians
- Sweep formula: `base_angle + cone_half * lerp(-1.0, 1.0, float(index) / max(total - 1, 1)) + randf_range(-jitter, jitter)`
- Impulse magnitude: keep current range `THROW_IMPULSE_MIN` (1400) to `THROW_IMPULSE_MAX` (2400) with slight random bias per die

### Cadence (Accelerating Burst)
The delay between consecutive dice decreases as the volley progresses. More dice = faster cadence at the tail.

```
Formula for delay before die i (0-indexed, die 0 launches immediately):
  progress = float(i) / max(total - 1, 1)     # 0.0 to 1.0
  base_delay = lerp(VOLLEY_DELAY_START, VOLLEY_DELAY_END, progress)
  cumulative_delay += base_delay + randf_range(0.0, VOLLEY_DELAY_JITTER)
```

New constants to add:
```gdscript
const VOLLEY_DELAY_START: float = 0.055      # delay before 2nd die
const VOLLEY_DELAY_END: float = 0.012        # delay between last dice in large pools
const VOLLEY_DELAY_JITTER: float = 0.008     # random variance per die
const VOLLEY_CONE_HALF_ANGLE: float = 0.55   # radians (~32°)
const VOLLEY_CONE_JITTER: float = 0.15       # radians random per die
const VOLLEY_EMITTER_JITTER_X: float = 15.0  # px horizontal spawn offset
const VOLLEY_EMITTER_JITTER_Y: float = 8.0   # px vertical spawn offset
```

### What to Change

#### 1. `throw_dice(pool)` — rewrite the spawn loop

**Before**: Instantiate all dice, place in grid, then call `_stagger_throw()`.

**After**: Build a launch queue (Array of DiceData + index pairs). Start the volley by launching die 0 immediately and scheduling the rest.

```
- Do NOT call _build_spawn_positions() for the initial throw
- Do NOT add dice to the scene tree upfront
- Store the pool as a member variable temporarily (_pending_pool)
- Call _start_volley() which processes the queue
```

#### 2. New method `_start_volley()` — replaces `_stagger_throw()` for initial throws

```
- Set _settle_check_active = true
- For i in pool.size():
    - If i == 0: call _volley_launch(0) immediately
    - Else: create_timer with cumulative delay, connect to _volley_launch(i)
- Cumulative delay uses the accelerating formula above
```

#### 3. New method `_volley_launch(index: int)` — replaces per-die work in throw_dice + _launch_die

```
- Instantiate PhysicsDie from PackedScene
- add_child(die)
- die.setup(index, _pending_pool[index])
- _dice.append(die)
- Connect signals (toggled_keep, shift_toggled_keep, collision_rerolled)
- Position at emitter point + jitter
- Roll face: pool[index].roll(), set die.current_face
- die.tumble(face)
- die.play_launch_burst()
- Compute cone direction from index/total
- Apply impulse
- Set angular_velocity
- Play SFX
```

#### 4. `_stagger_throw()` — keep for `instant_mode` only

The instant_mode path (used by tests) still needs to place all dice immediately. Keep that branch. Remove the timer-based launch branch (replaced by `_start_volley()`).

#### 5. `_launch_die()` — can be removed or kept as dead code

Its functionality is absorbed into `_volley_launch()`. If keeping for rerolls, rename to clarify.

#### 6. `_build_spawn_positions()` — keep for rerolls only

Rerolls still use `reroll_dice()` which needs spawn positions. Do not change the reroll flow.

#### 7. `reroll_dice()` — no changes needed

Current lift-and-rethrow behavior is fine and separate from initial throw.

### What Stays the Same
- All PhysicsDie internals (settling, tumble, collision reroll, bump boost, wall bounce dampening)
- Arena containment, boundary glow, soft separation
- All signals and public API (all_dice_settled, die_clicked, etc.)
- `instant_mode` / `force_settle_all()` for tests
- `reroll_dice()` flow
- All constants for physics material, settle thresholds, impulse ranges

### Testing Requirements

After implementation, verify:

1. **Existing tests pass**: Run the full GdUnit4 suite. The `instant_mode` path must still work identically. Any test that calls `throw_dice()` with `instant_mode = true` should see no behavior change.

2. **New unit tests to add** in `test/unit/DiceArenaVolleyTest.gd`:
   - `test_volley_launch_creates_dice_sequentially`: With instant_mode OFF (use a mock or short timer), verify `_dice.size()` grows as the volley progresses, not all at once.
   - `test_volley_cone_direction_spread`: Call `_volley_launch` for indices 0 and total-1 on a large pool, verify the impulse directions are spread across the cone (not all aimed at the same point).
   - `test_volley_delay_acceleration`: Verify that cumulative delay for die N is less than N * VOLLEY_DELAY_START (i.e., delays compress).
   - `test_instant_mode_still_works`: `instant_mode = true`, call `throw_dice()`, verify all dice are settled immediately with correct face count.
   - `test_reroll_unaffected`: After a volley throw, call `reroll_dice()` with a subset and verify it still uses the old spawn-position + lift flow.

3. **Manual verification**: Run the project via godot-mcp. Test with 5 dice, 12 dice, and 20+ dice. Verify:
   - Dice enter one at a time from bottom center
   - Clear cone spray pattern (not all aimed at same spot)
   - No dice standing still from pre-launch collisions
   - Wall bounces happen and look good
   - All dice eventually settle and results are correct
   - Cadence feels snappy, not sluggish

### File Checklist
- [ ] `Scripts/DiceArena.gd` — main changes (throw_dice, new volley methods, new constants)
- [ ] `test/unit/DiceArenaVolleyTest.gd` — new test file
- [ ] Run full test suite, verify 0 failures
- [ ] Run project via godot-mcp, verify visual behavior with debug output check

### Constraints
- Follow all GDScript conventions from `.github/copilot/skills/godot-gdscript-patterns.md`
- Static type everything
- Do not modify `PhysicsDie.gd` unless strictly necessary
- Do not change reroll behavior
- Do not change the public API of DiceArena (signal signatures, method signatures)
- Commit to `feature/claude` with message: `feat: dealer's sweep throw — sequential cone volley replaces grid spawn`
