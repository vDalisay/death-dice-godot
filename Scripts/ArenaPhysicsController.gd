class_name ArenaPhysicsController
extends RefCounted
## Per-frame physics: arena containment, soft separation, gravity well,
## and boundary glow for the dice arena.

const _UITheme := preload("res://Scripts/UITheme.gd")

var boundary_glow_energy: float = 0.0


## Run all per-frame physics on the arena dice.
func process_physics(
	dice: Array[PhysicsDie],
	arena_rect: Rect2,
	delta: float,
	has_gravity_well: bool,
	instant_mode: bool,
	bg_style: StyleBoxFlat
) -> void:
	if boundary_glow_energy > 0.0:
		boundary_glow_energy = maxf(0.0, boundary_glow_energy - DiceArena.BOUNDARY_GLOW_DECAY_PER_SEC * delta)
	_apply_boundary_glow(bg_style)
	_enforce_arena_containment(dice, arena_rect, instant_mode)
	_apply_soft_separation(dice, instant_mode)
	if has_gravity_well:
		_apply_gravity_well_forces(dice)


func reset() -> void:
	boundary_glow_energy = 0.0


# ---------------------------------------------------------------------------
# Containment — keep dice inside the arena walls
# ---------------------------------------------------------------------------

func _enforce_arena_containment(dice: Array[PhysicsDie], rect: Rect2, instant_mode: bool) -> void:
	if instant_mode or dice.is_empty():
		return
	var min_x: float = rect.position.x + PhysicsDie.COLLISION_RADIUS
	var max_x: float = rect.end.x - PhysicsDie.COLLISION_RADIUS
	var min_y: float = rect.position.y + PhysicsDie.COLLISION_RADIUS
	var max_y: float = rect.end.y - PhysicsDie.COLLISION_RADIUS
	var hit_count: int = 0
	for die: PhysicsDie in dice:
		if die == null or die.freeze:
			continue
		var p: Vector2 = die.position
		var corrected: bool = false
		var wall_dampen: float = pow(DiceArena.WALL_BOUNCE_DAMPEN_FACTOR, mini(die._wall_bounce_count, 10))
		var effective_min_speed: float = DiceArena.CONTAINMENT_MIN_BOUNCE_SPEED * wall_dampen
		var effective_damp: float = DiceArena.CONTAINMENT_BOUNCE_DAMP * wall_dampen
		if p.x < min_x:
			p.x = min_x
			die.linear_velocity.x = maxf(absf(die.linear_velocity.x) * effective_damp, effective_min_speed)
			corrected = true
		elif p.x > max_x:
			p.x = max_x
			die.linear_velocity.x = -maxf(absf(die.linear_velocity.x) * effective_damp, effective_min_speed)
			corrected = true
		if p.y < min_y:
			p.y = min_y
			die.linear_velocity.y = maxf(absf(die.linear_velocity.y) * effective_damp, effective_min_speed)
			corrected = true
		elif p.y > max_y:
			p.y = max_y
			die.linear_velocity.y = -maxf(absf(die.linear_velocity.y) * effective_damp, effective_min_speed)
			corrected = true
		if corrected:
			die._wall_bounce_count += 1
			die.position = p
			var inward: Vector2 = (Vector2(DiceArena.ARENA_WIDTH * 0.5, DiceArena.ARENA_HEIGHT * 0.5) - p).normalized()
			if inward != Vector2.ZERO:
				die.apply_central_impulse(inward * DiceArena.CONTAINMENT_INWARD_NUDGE)
			hit_count += 1
	if hit_count > 0:
		_accumulate_boundary_glow(hit_count)


# ---------------------------------------------------------------------------
# Soft separation — gently push overlapping slow dice apart
# ---------------------------------------------------------------------------

func _apply_soft_separation(dice: Array[PhysicsDie], instant_mode: bool) -> void:
	if instant_mode or dice.size() < 2:
		return
	var min_distance: float = PhysicsDie.COLLISION_RADIUS * DiceArena.SOFT_SEPARATION_RADIUS_MULT
	var min_distance_sq: float = min_distance * min_distance
	for i: int in dice.size():
		var a: PhysicsDie = dice[i]
		if a == null or a.freeze:
			continue
		if a.linear_velocity.length() > DiceArena.SOFT_SEPARATION_MAX_SPEED:
			continue
		for j: int in range(i + 1, dice.size()):
			var b: PhysicsDie = dice[j]
			if b == null or b.freeze:
				continue
			if b.linear_velocity.length() > DiceArena.SOFT_SEPARATION_MAX_SPEED:
				continue
			var delta_pos: Vector2 = a.position - b.position
			var dist_sq: float = delta_pos.length_squared()
			if dist_sq <= 0.0001 or dist_sq >= min_distance_sq:
				continue
			var dist: float = sqrt(dist_sq)
			var normal: Vector2 = delta_pos / dist
			var overlap_ratio: float = clampf((min_distance - dist) / min_distance, 0.0, 1.0)
			var push: float = overlap_ratio * DiceArena.SOFT_SEPARATION_PUSH
			a.apply_central_impulse(normal * push)
			b.apply_central_impulse(-normal * push)


# ---------------------------------------------------------------------------
# Gravity well — settled MULTIPLY dice pull nearby FLYING dice inward
# ---------------------------------------------------------------------------

func _apply_gravity_well_forces(dice: Array[PhysicsDie]) -> void:
	for source: PhysicsDie in dice:
		if source.physics_state != PhysicsDie.DiePhysicsState.SETTLED:
			continue
		if source.current_face == null:
			continue
		if source.current_face.type != DiceFaceData.FaceType.MULTIPLY:
			continue
		var source_pos: Vector2 = source.global_position
		for target: PhysicsDie in dice:
			if target == source:
				continue
			if target.physics_state != PhysicsDie.DiePhysicsState.FLYING:
				continue
			var diff: Vector2 = source_pos - target.global_position
			if diff.length_squared() > DiceArena.GRAVITY_WELL_RADIUS * DiceArena.GRAVITY_WELL_RADIUS:
				continue
			target.apply_central_force(diff.normalized() * DiceArena.GRAVITY_WELL_FORCE)


# ---------------------------------------------------------------------------
# Boundary glow — arena border pulses red on wall hits
# ---------------------------------------------------------------------------

func _accumulate_boundary_glow(hit_count: int) -> void:
	var gain: float = float(hit_count) * DiceArena.BOUNDARY_GLOW_HIT_GAIN
	boundary_glow_energy = clampf(boundary_glow_energy + gain, 0.0, 1.0)


func _apply_boundary_glow(bg_style: StyleBoxFlat) -> void:
	if bg_style == null:
		return
	var t: float = clampf(boundary_glow_energy, 0.0, 1.0)
	bg_style.border_color = DiceArena.ARENA_BORDER_COLOR.lerp(_UITheme.DANGER_RED, t)
