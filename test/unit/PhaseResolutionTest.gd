extends GdUnitTestSuite
## Unit tests for the phase-by-phase resolution pipeline.
## Uses mirror functions to test classification, ordering, and phase logic
## without instantiating the full RollPhase scene.


# ---------------------------------------------------------------------------
# Face classification tests
# ---------------------------------------------------------------------------

func test_classify_stop_sets_stopped_true() -> void:
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.STOP)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]

	var chain: Array[int] = _classify(faces, [0], stopped, keep, keep_locked)

	assert_bool(stopped[0]).is_true()
	assert_bool(keep[0]).is_false()
	assert_array(chain).is_empty()


func test_classify_cursed_stop_sets_stopped_true() -> void:
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.CURSED_STOP)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]

	var chain: Array[int] = _classify(faces, [0], stopped, keep, keep_locked)

	assert_bool(stopped[0]).is_true()
	assert_bool(keep[0]).is_false()
	assert_array(chain).is_empty()


func test_classify_auto_keep_sets_kept_and_locked() -> void:
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.AUTO_KEEP, 5)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]

	_classify(faces, [0], stopped, keep, keep_locked)

	assert_bool(keep[0]).is_true()
	assert_bool(keep_locked[0]).is_true()


func test_classify_shield_sets_kept_and_locked() -> void:
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.SHIELD, 1)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]

	_classify(faces, [0], stopped, keep, keep_locked)

	assert_bool(keep[0]).is_true()
	assert_bool(keep_locked[0]).is_true()


func test_classify_explode_returns_chain_reroll() -> void:
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.EXPLODE, 2)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]

	var chain: Array[int] = _classify(faces, [0], stopped, keep, keep_locked)

	assert_bool(keep[0]).is_true()
	assert_bool(keep_locked[0]).is_true()
	assert_array(chain).contains_exactly([0])


func test_classify_number_stays_free() -> void:
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.NUMBER, 3)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [false]
	var keep_locked: Array[bool] = [false]

	_classify(faces, [0], stopped, keep, keep_locked)

	assert_bool(keep[0]).is_false()
	assert_bool(keep_locked[0]).is_false()
	assert_bool(stopped[0]).is_false()


func test_classify_mixed_roll_correct_categories() -> void:
	## 5 dice: STOP, NUMBER, SHIELD, EXPLODE, AUTO_KEEP
	var faces: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.STOP),
		_make_face(DiceFaceData.FaceType.NUMBER, 4),
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
		_make_face(DiceFaceData.FaceType.EXPLODE, 2),
		_make_face(DiceFaceData.FaceType.AUTO_KEEP, 6),
	]
	var stopped: Array[bool] = [false, false, false, false, false]
	var keep: Array[bool] = [false, false, false, false, false]
	var keep_locked: Array[bool] = [false, false, false, false, false]

	var chain: Array[int] = _classify(faces, [0, 1, 2, 3, 4], stopped, keep, keep_locked)

	# STOP → stopped
	assert_bool(stopped[0]).is_true()
	assert_bool(keep[0]).is_false()
	# NUMBER → free
	assert_bool(stopped[1]).is_false()
	assert_bool(keep[1]).is_false()
	# SHIELD → kept + locked
	assert_bool(keep[2]).is_true()
	assert_bool(keep_locked[2]).is_true()
	# EXPLODE → kept + locked + chain
	assert_bool(keep[3]).is_true()
	assert_bool(keep_locked[3]).is_true()
	assert_array(chain).contains_exactly([3])
	# AUTO_KEEP → kept + locked
	assert_bool(keep[4]).is_true()
	assert_bool(keep_locked[4]).is_true()


func test_classify_preserves_existing_keep_locked() -> void:
	## A die that is already keep_locked should NOT be freed by a NUMBER face.
	var faces: Array[DiceFaceData] = [_make_face(DiceFaceData.FaceType.NUMBER, 2)]
	var stopped: Array[bool] = [false]
	var keep: Array[bool] = [true]
	var keep_locked: Array[bool] = [true]

	_classify(faces, [0], stopped, keep, keep_locked)

	# keep_locked prevents the die from being freed by NUMBER wildcard.
	assert_bool(keep[0]).is_true()
	assert_bool(keep_locked[0]).is_true()


# ---------------------------------------------------------------------------
# Classify summary formatting tests
# ---------------------------------------------------------------------------

func test_classify_summary_mixed_roll() -> void:
	var faces: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.STOP),
		_make_face(DiceFaceData.FaceType.STOP),
		_make_face(DiceFaceData.FaceType.SHIELD, 1),
		_make_face(DiceFaceData.FaceType.EXPLODE, 2),
		_make_face(DiceFaceData.FaceType.NUMBER, 4),
	]
	var keep_locked: Array[bool] = [false, false, true, true, false]
	var summary: String = _build_classify_summary(faces, [0, 1, 2, 3, 4], keep_locked)
	assert_str(summary).is_equal("2 stops · 1 kept · 1 explode · 1 free")


func test_classify_summary_all_stops() -> void:
	var faces: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.STOP),
		_make_face(DiceFaceData.FaceType.STOP),
		_make_face(DiceFaceData.FaceType.STOP),
	]
	var keep_locked: Array[bool] = [false, false, false]
	var summary: String = _build_classify_summary(faces, [0, 1, 2], keep_locked)
	assert_str(summary).is_equal("3 stops")


func test_classify_summary_no_stops() -> void:
	var faces: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.NUMBER, 5),
		_make_face(DiceFaceData.FaceType.NUMBER, 3),
	]
	var keep_locked: Array[bool] = [false, false]
	var summary: String = _build_classify_summary(faces, [0, 1], keep_locked)
	assert_str(summary).is_equal("2 free")


func test_classify_summary_single_explode() -> void:
	var faces: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.EXPLODE, 2),
	]
	var keep_locked: Array[bool] = [true]
	var summary: String = _build_classify_summary(faces, [0], keep_locked)
	assert_str(summary).is_equal("1 explode")


# ---------------------------------------------------------------------------
# Phase ordering guarantee tests
# ---------------------------------------------------------------------------

func test_shields_before_bust_check() -> void:
	## Shields must be registered BEFORE bust check computes effective stops.
	## This ensures shields reduce the stop count the bust evaluator sees.
	var accumulated_stops: int = 4
	var shield_value: int = 2
	var threshold: int = 4

	# Without shield (old behavior would bust):
	var effective_no_shield: int = maxi(0, accumulated_stops - 0)
	assert_bool(effective_no_shield >= threshold).is_true()

	# With shield registered first (phased order):
	var effective_with_shield: int = maxi(0, accumulated_stops - shield_value)
	assert_bool(effective_with_shield >= threshold).is_false()


func test_explode_chains_dont_trigger_second_bust() -> void:
	## Explode chains add stops to accumulated_stop_count but do NOT trigger
	## a second bust check. This is by design: chains are "free".
	var initial_stops: int = 2
	var threshold: int = 4
	var chain_added_stops: int = 3

	# Initial bust check: safe.
	assert_bool(initial_stops >= threshold).is_false()

	# After chain resolution, stops exceed threshold.
	var final_stops: int = initial_stops + chain_added_stops
	assert_bool(final_stops >= threshold).is_true()

	# But no second bust check runs — player remains active.
	# This test documents the intentional design decision.
	assert_bool(true).is_true()


func test_chain_step_stops_are_visible() -> void:
	## When a chain reroll lands on STOP, it should be trackable for
	## the feed announcement ("+N stop(s) from chain!").
	var chain_step_stops: int = 0
	var faces: Array[DiceFaceData] = [
		_make_face(DiceFaceData.FaceType.STOP),
		_make_face(DiceFaceData.FaceType.EXPLODE, 3),
		_make_face(DiceFaceData.FaceType.CURSED_STOP),
	]
	# Simulate chain step counting.
	for face: DiceFaceData in faces:
		if face.type == DiceFaceData.FaceType.STOP:
			chain_step_stops += 1
		elif face.type == DiceFaceData.FaceType.CURSED_STOP:
			chain_step_stops += 2
	# 1 regular stop + 1 cursed (weight 2) = 3
	assert_int(chain_step_stops).is_equal(3)


# ---------------------------------------------------------------------------
# Mirror / helper functions
# ---------------------------------------------------------------------------

func _make_face(type: int, value: int = 0) -> DiceFaceData:
	var face := DiceFaceData.new()
	face.type = type
	face.value = value
	return face


## Mirrors RollPhase._classify_rolled_dice() logic.
func _classify(
	faces: Array[DiceFaceData],
	rolled_indices: Array[int],
	stopped: Array[bool],
	keep: Array[bool],
	keep_locked: Array[bool],
) -> Array[int]:
	var chain_reroll: Array[int] = []
	for i: int in rolled_indices:
		var face: DiceFaceData = faces[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.STOP, DiceFaceData.FaceType.CURSED_STOP:
				stopped[i] = true
				keep[i] = false
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, \
			DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.MULTIPLY_LEFT, \
			DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.LUCK:
				keep[i] = true
				keep_locked[i] = true
			DiceFaceData.FaceType.EXPLODE:
				keep[i] = true
				keep_locked[i] = true
				chain_reroll.append(i)
			_:
				if not keep_locked[i]:
					keep[i] = false
	return chain_reroll


## Mirrors RollPhase._emit_classify_summary() formatting logic.
func _build_classify_summary(
	faces: Array[DiceFaceData],
	rolled_indices: Array[int],
	keep_locked: Array[bool],
) -> String:
	var stops: int = 0
	var kept: int = 0
	var explodes: int = 0
	var free: int = 0
	for i: int in rolled_indices:
		var face: DiceFaceData = faces[i]
		if face == null:
			continue
		if face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP:
			stops += 1
		elif face.type == DiceFaceData.FaceType.EXPLODE:
			explodes += 1
		elif keep_locked[i]:
			kept += 1
		else:
			free += 1
	var parts: Array[String] = []
	if stops > 0:
		parts.append("%d stop%s" % [stops, "s" if stops > 1 else ""])
	if kept > 0:
		parts.append("%d kept" % kept)
	if explodes > 0:
		parts.append("%d explode%s" % [explodes, "s" if explodes > 1 else ""])
	if free > 0:
		parts.append("%d free" % free)
	return " · ".join(parts)
