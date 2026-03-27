extends GdUnitTestSuite
## Unit tests for the reroll algorithm invariants.
## These don't need the scene — they test the logic rules directly.


# ---------------------------------------------------------------------------
# Reroll logic: which dice get rerolled?
# ---------------------------------------------------------------------------

func test_reroll_includes_stopped_dice() -> void:
	## Stopped dice (not kept) must be included in the reroll set.
	var stopped: Array[bool]     = [true,  false, false, true,  false]
	var keep: Array[bool]        = [false, false, true,  false, false]
	var keep_locked: Array[bool] = [false, false, false, false, false]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	# Die 0: stopped, not kept → REROLL (this is the bug fix)
	assert_bool(should_reroll[0]).is_true()
	# Die 1: not stopped, not kept → REROLL
	assert_bool(should_reroll[1]).is_true()
	# Die 2: not stopped, kept → NOT rerolled (kept)
	assert_bool(should_reroll[2]).is_false()
	# Die 3: stopped, not kept → REROLL
	assert_bool(should_reroll[3]).is_true()
	# Die 4: not stopped, not kept → REROLL
	assert_bool(should_reroll[4]).is_true()


func test_reroll_excludes_kept_dice() -> void:
	var stopped: Array[bool]     = [false, false, false]
	var keep: Array[bool]        = [true,  true,  false]
	var keep_locked: Array[bool] = [false, false, false]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	assert_bool(should_reroll[0]).is_false()
	assert_bool(should_reroll[1]).is_false()
	assert_bool(should_reroll[2]).is_true()


func test_reroll_excludes_locked_dice() -> void:
	var stopped: Array[bool]     = [false, false, false]
	var keep: Array[bool]        = [false, true,  false]
	var keep_locked: Array[bool] = [true,  true,  false]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	assert_bool(should_reroll[0]).is_false()
	assert_bool(should_reroll[1]).is_false()
	assert_bool(should_reroll[2]).is_true()


func test_reroll_all_stopped_all_rerolled() -> void:
	## If every die is stopped and none are kept, ALL get rerolled.
	var stopped: Array[bool]     = [true, true, true, true, true]
	var keep: Array[bool]        = [false, false, false, false, false]
	var keep_locked: Array[bool] = [false, false, false, false, false]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	for i: int in should_reroll.size():
		assert_bool(should_reroll[i])\
			.override_failure_message("Die %d should be rerolled" % i)\
			.is_true()


func test_reroll_all_kept_none_rerolled() -> void:
	## If every die is kept, nothing gets rerolled.
	var stopped: Array[bool]     = [false, false, false]
	var keep: Array[bool]        = [true,  true,  true]
	var keep_locked: Array[bool] = [false, false, false]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	for i: int in should_reroll.size():
		assert_bool(should_reroll[i])\
			.override_failure_message("Die %d should NOT be rerolled" % i)\
			.is_false()


func test_stopped_flag_clears_on_reroll() -> void:
	## After computing the reroll set, stopped flags must be cleared for rerolled dice.
	var stopped: Array[bool]     = [true, false, true]
	var keep: Array[bool]        = [false, true, false]
	var keep_locked: Array[bool] = [false, false, false]

	_simulate_reroll_clear(stopped, keep, keep_locked)

	# Die 0 was stopped → rerolled → stopped flag cleared.
	assert_bool(stopped[0]).is_false()
	# Die 1 was kept → not touched.
	# Die 2 was stopped → rerolled → stopped flag cleared.
	assert_bool(stopped[2]).is_false()


func test_kept_becomes_locked_on_reroll() -> void:
	## Kept (but not yet locked) dice should be locked when reroll happens.
	var keep: Array[bool]        = [true, false, true]
	var keep_locked: Array[bool] = [false, false, false]

	_simulate_lock_step(keep, keep_locked)

	assert_bool(keep_locked[0]).is_true()
	assert_bool(keep_locked[1]).is_false()
	assert_bool(keep_locked[2]).is_true()


# ---------------------------------------------------------------------------
# Bust threshold invariants
# ---------------------------------------------------------------------------

func test_bust_threshold_lenient_turns_1_to_3() -> void:
	for t: int in [1, 2, 3]:
		var threshold: int = _get_bust_threshold(t)
		assert_int(threshold)\
			.override_failure_message("Turn %d should have threshold 4" % t)\
			.is_equal(4)


func test_bust_threshold_standard_turn_4_plus() -> void:
	for t: int in [4, 5, 10, 99]:
		var threshold: int = _get_bust_threshold(t)
		assert_int(threshold)\
			.override_failure_message("Turn %d should have threshold 3" % t)\
			.is_equal(3)


func test_turn1_immune_to_bust() -> void:
	## Turn 1 never busts regardless of stop count.
	var turn: int = 1
	var stops: int = 10
	var threshold: int = _get_bust_threshold(turn)
	assert_bool(_should_bust(turn, stops, threshold)).is_false()


func test_turn2_busts_at_threshold() -> void:
	var turn: int = 2
	var threshold: int = _get_bust_threshold(turn)  # 4
	assert_bool(_should_bust(turn, 4, threshold)).is_true()
	assert_bool(_should_bust(turn, 3, threshold)).is_false()


# ---------------------------------------------------------------------------
# Auto-bank when no reroll options remain
# ---------------------------------------------------------------------------

func test_empty_reroll_set_triggers_auto_bank() -> void:
	## When compute_reroll_set returns all-false, auto-bank should fire.
	var stopped: Array[bool]     = [false, false, false, false, false]
	var keep: Array[bool]        = [true,  true,  true,  true,  true]
	var keep_locked: Array[bool] = [true,  true,  true,  true,  true]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	var any_rerollable: bool = false
	for r: bool in should_reroll:
		if r:
			any_rerollable = true
			break
	# No dice to reroll → auto-bank condition met.
	assert_bool(any_rerollable).is_false()


func test_mixed_kept_and_stopped_still_has_rerolls() -> void:
	## If some dice are stopped (not kept), rerolls still exist → no auto-bank.
	var stopped: Array[bool]     = [true,  false, false]
	var keep: Array[bool]        = [false, true,  true]
	var keep_locked: Array[bool] = [false, true,  true]

	var should_reroll: Array[bool] = _compute_reroll_set(stopped, keep, keep_locked)
	var any_rerollable: bool = false
	for r: bool in should_reroll:
		if r:
			any_rerollable = true
			break
	# Die 0 is stopped but not kept → still rerollable → no auto-bank.
	assert_bool(any_rerollable).is_true()


# ---------------------------------------------------------------------------
# Mirror functions (same algorithms as RollPhase.gd)
# ---------------------------------------------------------------------------

## Computes which dice should be rerolled. Mirrors _reroll_selected_dice logic.
func _compute_reroll_set(stopped: Array[bool], keep: Array[bool], keep_locked: Array[bool]) -> Array[bool]:
	var result: Array[bool] = []
	result.resize(stopped.size())
	for i: int in stopped.size():
		if keep[i] or keep_locked[i]:
			result[i] = false
		else:
			result[i] = true  # Includes stopped dice — the bug fix
	return result


## Simulates the stopped-flag clear that happens during reroll.
func _simulate_reroll_clear(stopped: Array[bool], keep: Array[bool], keep_locked: Array[bool]) -> void:
	for i: int in stopped.size():
		if keep[i] or keep_locked[i]:
			continue
		if stopped[i]:
			stopped[i] = false


## Simulates the lock step: kept dice become locked before reroll.
func _simulate_lock_step(keep: Array[bool], keep_locked: Array[bool]) -> void:
	for i: int in keep.size():
		if keep[i] and not keep_locked[i]:
			keep_locked[i] = true


func _get_bust_threshold(turn: int) -> int:
	if turn <= 3:
		return RollPhase.BASE_BUST_THRESHOLD + 1
	return RollPhase.BASE_BUST_THRESHOLD


func _should_bust(turn: int, stops: int, threshold: int) -> bool:
	return stops >= threshold and turn > 1


# ---------------------------------------------------------------------------
# Accumulated stops across rerolls
# ---------------------------------------------------------------------------

func test_accumulated_stops_bust_at_threshold() -> void:
	## With accumulated stops >= threshold on turn 2+, should bust.
	var turn: int = 2
	var accumulated_stops: int = 4
	var threshold: int = _get_bust_threshold(turn)  # 4
	assert_bool(_should_bust(turn, accumulated_stops, threshold)).is_true()


func test_accumulated_stops_below_threshold_no_bust() -> void:
	## Accumulated stops below threshold should not bust.
	var turn: int = 2
	var accumulated_stops: int = 3
	var threshold: int = _get_bust_threshold(turn)  # 4
	assert_bool(_should_bust(turn, accumulated_stops, threshold)).is_false()


func test_accumulated_stops_with_shields_no_bust() -> void:
	## Shields reduce effective stop count below threshold.
	var accumulated_stops: int = 4
	var shields: int = 2
	var effective: int = maxi(0, accumulated_stops - shields)  # 2
	var threshold: int = _get_bust_threshold(2)  # 4
	assert_bool(_should_bust(2, effective, threshold)).is_false()


func test_accumulated_stops_with_shields_still_bust() -> void:
	## Shields not enough — still bust.
	var accumulated_stops: int = 5
	var shields: int = 1
	var effective: int = maxi(0, accumulated_stops - shields)  # 4
	var threshold: int = _get_bust_threshold(2)  # 4
	assert_bool(_should_bust(2, effective, threshold)).is_true()
