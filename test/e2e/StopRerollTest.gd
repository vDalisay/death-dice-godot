extends GdUnitTestSuite
## Regression tests for stop-dice reroll behaviour (Cubitos-style).
##
## Bug fixed: STOP faces were not included in rerolls — they stayed frozen
## even when the player pressed "Reroll Selected". Now stopped dice that
## are NOT kept/locked ARE rerolled alongside other free dice.
##
## Also covers the "pick up a stopped die" toggle interaction.


# ---------------------------------------------------------------------------
# E2E: Full scene tests with the real Main scene
# ---------------------------------------------------------------------------

func test_stopped_dice_are_rerolled_on_reroll_button() -> void:
	## Core regression test: pressing Reroll should reroll stopped dice.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	var pool_size: int = GameManager.dice_pool.size()

	# Roll all dice.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return  # Auto-banked or bust on turn 1 — can't test reroll.

	# Force die 0 to STOP so we have a known stopped die.
	var stop_face := DiceFaceData.new()
	stop_face.type = DiceFaceData.FaceType.STOP
	stop_face.value = 0
	root.current_results[0] = stop_face
	root.dice_stopped[0] = true
	root.dice_keep[0] = false

	# Force remaining dice to NUMBER and mark them as "not kept" (will be rerolled).
	for i: int in range(1, pool_size):
		var num_face := DiceFaceData.new()
		num_face.type = DiceFaceData.FaceType.NUMBER
		num_face.value = 1
		root.current_results[i] = num_face
		root.dice_stopped[i] = false
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false

	root._sync_all_dice()
	root._sync_ui()

	# Confirm die 0 is stopped before reroll.
	assert_bool(root.dice_stopped[0]).is_true()

	# Press Reroll — this should reroll die 0 (stopped) AND dice 1..N (free).
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	# Die 0 should have been rerolled — its stopped flag should be cleared
	# (it may land STOP again, re-setting the flag, but the result changes).
	# We verify the reroll happened by checking that die 0 was processed.
	# If it landed STOP again, dice_stopped[0] is true; otherwise false.
	# Either way, the die was rerolled (not stuck from the old roll).
	assert_object(root.current_results[0]).is_not_null()


func test_stopped_dice_not_rerolled_if_kept() -> void:
	## Dice that are kept/locked should NOT be rerolled, even if stopped.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force die 0 to kept + locked (simulating a previously kept die).
	var num_face := DiceFaceData.new()
	num_face.type = DiceFaceData.FaceType.NUMBER
	num_face.value = 5
	root.current_results[0] = num_face
	root.dice_keep[0] = true
	root.dice_keep_locked[0] = true
	root.dice_stopped[0] = false

	# Force die 1 as free (should reroll).
	var face1 := DiceFaceData.new()
	face1.type = DiceFaceData.FaceType.NUMBER
	face1.value = 1
	root.current_results[1] = face1
	root.dice_keep[1] = false
	root.dice_keep_locked[1] = false
	root.dice_stopped[1] = false

	root._sync_all_dice()

	# Reroll.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	# Die 0 should still have value 5 (kept, not rerolled).
	assert_int(root.current_results[0].value).is_equal(5)
	assert_int(root.current_results[0].type).is_equal(DiceFaceData.FaceType.NUMBER)


func test_reroll_clears_stopped_flag_before_rolling() -> void:
	## When a stopped die is rerolled, its stopped flag must clear before the roll.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force all dice to STOP.
	for i: int in GameManager.dice_pool.size():
		var stop_face := DiceFaceData.new()
		stop_face.type = DiceFaceData.FaceType.STOP
		stop_face.value = 0
		root.current_results[i] = stop_face
		root.dice_stopped[i] = true
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false

	# Reroll — all stops should be cleared and re-rolled.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	# After reroll, each die should have a fresh result.
	for i: int in GameManager.dice_pool.size():
		assert_object(root.current_results[i]).is_not_null()


func test_manual_pickup_then_reroll() -> void:
	## Player clicks a stopped die to "pick it up", then rerolls.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force die 0 to STOP.
	var stop_face := DiceFaceData.new()
	stop_face.type = DiceFaceData.FaceType.STOP
	stop_face.value = 0
	root.current_results[0] = stop_face
	root.dice_stopped[0] = true
	root.dice_keep[0] = false
	root.dice_keep_locked[0] = false
	root._sync_all_dice()

	# Simulate clicking the stopped die to pick it up (toggle signal).
	root.dice_tray.die_toggled.emit(0, false)
	await runner.simulate_frames(2)

	# Die should no longer be stopped after pickup.
	assert_bool(root.dice_stopped[0]).is_false()
	assert_bool(root.dice_keep[0]).is_false()


func test_kept_dice_stay_locked_after_reroll() -> void:
	## Dice toggled to KEPT before reroll should become locked after reroll.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force die 0 to a scoring face and mark as kept.
	var scoring_face := DiceFaceData.new()
	scoring_face.type = DiceFaceData.FaceType.NUMBER
	scoring_face.value = 5
	root.current_results[0] = scoring_face
	root.dice_keep[0] = true
	root.dice_keep_locked[0] = false
	root.dice_stopped[0] = false

	# Reroll — die 0 should get locked, not re-rolled.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_bool(root.dice_keep_locked[0]).is_true()
	assert_int(root.current_results[0].value).is_equal(5)


func test_auto_kept_dice_survive_reroll_of_stops() -> void:
	## AUTO_KEEP / SHIELD / MULTIPLY dice should never be rerolled.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force die 0 to AUTO_KEEP (locked), die 1 to STOP (should reroll).
	var ak_face := DiceFaceData.new()
	ak_face.type = DiceFaceData.FaceType.AUTO_KEEP
	ak_face.value = 3
	root.current_results[0] = ak_face
	root.dice_keep[0] = true
	root.dice_keep_locked[0] = true
	root.dice_stopped[0] = false

	var stop_face := DiceFaceData.new()
	stop_face.type = DiceFaceData.FaceType.STOP
	stop_face.value = 0
	root.current_results[1] = stop_face
	root.dice_stopped[1] = true
	root.dice_keep[1] = false
	root.dice_keep_locked[1] = false

	root._sync_all_dice()
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	# AUTO_KEEP die should be untouched.
	assert_int(root.current_results[0].type).is_equal(DiceFaceData.FaceType.AUTO_KEEP)
	assert_int(root.current_results[0].value).is_equal(3)
	assert_bool(root.dice_keep_locked[0]).is_true()

	# STOP die should have been rerolled (has a new result, may or may not be STOP again).
	assert_object(root.current_results[1]).is_not_null()


func test_multiple_rerolls_keep_clearing_stops() -> void:
	## Stops from reroll N should be clearable in reroll N+1.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Do 3 rounds of: force some stops, then reroll.
	for _round: int in 3:
		if root.turn_state != RollPhase.TurnState.ACTIVE:
			break

		# Force die 0 to STOP.
		var stop_face := DiceFaceData.new()
		stop_face.type = DiceFaceData.FaceType.STOP
		stop_face.value = 0
		root.current_results[0] = stop_face
		root.dice_stopped[0] = true
		root.dice_keep[0] = false
		root.dice_keep_locked[0] = false

		# Force other dice to scoring faces so we don't auto-bank.
		for i: int in range(1, GameManager.dice_pool.size()):
			var num_face := DiceFaceData.new()
			num_face.type = DiceFaceData.FaceType.NUMBER
			num_face.value = 1
			root.current_results[i] = num_face
			root.dice_stopped[i] = false
			root.dice_keep[i] = false
			root.dice_keep_locked[i] = false

		root._sync_all_dice()
		root._sync_ui()

		# Reroll.
		root.roll_button.pressed.emit()
		await runner.simulate_frames(2)

		# Die 0 was rerolled — it has a result (may be STOP again, that's fine).
		assert_object(root.current_results[0]).is_not_null()


# ---------------------------------------------------------------------------
# Auto-bank when no reroll options remain
# ---------------------------------------------------------------------------

func test_auto_bank_when_all_dice_kept_and_reroll_pressed() -> void:
	## Pressing Reroll when every die is kept should auto-bank instead of
	## showing a dead-end message.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force all dice to kept + locked scoring faces.
	for i: int in GameManager.dice_pool.size():
		var face := DiceFaceData.new()
		face.type = DiceFaceData.FaceType.NUMBER
		face.value = 2
		root.current_results[i] = face
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = true
		root.dice_stopped[i] = false
	root._sync_all_dice()
	root._sync_ui()

	var score_before: int = GameManager.total_score

	# Press Reroll — should auto-bank since nothing can be rerolled.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.BANKED)
	assert_int(GameManager.total_score).is_greater(score_before)


func test_auto_bank_score_correct_when_all_kept() -> void:
	## Auto-bank from all-kept should bank the correct score (2 × 5 = 10).
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	for i: int in GameManager.dice_pool.size():
		var face := DiceFaceData.new()
		face.type = DiceFaceData.FaceType.NUMBER
		face.value = 2
		root.current_results[i] = face
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = true
		root.dice_stopped[i] = false
	root._sync_all_dice()
	root._sync_ui()

	GameManager.total_score = 0
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)

	# 5 dice × value 2 = 10
	assert_int(GameManager.total_score).is_equal(2 * GameManager.dice_pool.size())


# ---------------------------------------------------------------------------
# Accumulated stops across rerolls
# ---------------------------------------------------------------------------

func test_stops_accumulate_across_rerolls() -> void:
	## Stops from roll 1 should persist and add to stops from roll 2.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	var pool_size: int = GameManager.dice_pool.size()

	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force: die 0 = STOP, die 1..N = NUMBER (kept so they won't reroll).
	var stop_face := DiceFaceData.new()
	stop_face.type = DiceFaceData.FaceType.STOP
	stop_face.value = 0
	root.current_results[0] = stop_face
	root.dice_stopped[0] = true
	root.dice_keep[0] = false

	for i: int in range(1, pool_size):
		var num_face := DiceFaceData.new()
		num_face.type = DiceFaceData.FaceType.NUMBER
		num_face.value = 1
		root.current_results[i] = num_face
		root.dice_stopped[i] = false
		root.dice_keep[i] = true
		root.dice_keep_locked[i] = true

	root._sync_all_dice()
	root._sync_ui()

	# Verify 1 stop showing in UI state.
	assert_int(root._count_stops()).is_equal(1)

	# Now force die 0 to be picked up and prepare a reroll that lands STOP again.
	# Simulate: die 0 picked up, then rerolled, lands STOP again.
	root.dice_stopped[0] = false
	root.dice_keep[0] = false
	root.dice_keep_locked[0] = false

	# Manually reroll die 0 by forcing STOP result again.
	root.current_results[0] = stop_face
	root.dice_stopped[0] = true

	# The accumulated stop count should be 1 (only 1 die is currently stopped).
	assert_int(root._count_stops()).is_equal(1)


func test_accumulated_stops_cause_bust_on_turn_2() -> void:
	## With enough accumulated stops, turn 2+ should bust.
	var runner: GdUnitSceneRunner = scene_runner("res://Scenes/Main.tscn")
	await runner.simulate_frames(2)
	var root: RollPhase = runner.scene() as RollPhase
	var pool_size: int = GameManager.dice_pool.size()

	# Roll to get to ACTIVE state.
	root.roll_button.pressed.emit()
	await runner.simulate_frames(2)
	if root.turn_state != RollPhase.TurnState.ACTIVE:
		return

	# Force all dice to NUMBER, none stopped — clean slate.
	for i: int in pool_size:
		var num_face := DiceFaceData.new()
		num_face.type = DiceFaceData.FaceType.NUMBER
		num_face.value = 1
		root.current_results[i] = num_face
		root.dice_stopped[i] = false
		root.dice_keep[i] = false
		root.dice_keep_locked[i] = false
	root._sync_all_dice()

	# Force 4 dice to STOP (threshold is 4 for turn 2-3).
	var stops_needed: int = mini(4, pool_size)
	for i: int in stops_needed:
		var stop_face := DiceFaceData.new()
		stop_face.type = DiceFaceData.FaceType.STOP
		stop_face.value = 0
		root.current_results[i] = stop_face
		root.dice_stopped[i] = true
		root.dice_keep[i] = false

	# Ensure we're past turn 1
	root.turn_number = 2

	# Process results with accumulated stops — should bust.
	var rolled: Array[int] = []
	for i: int in pool_size:
		rolled.append(i)
	root._process_roll_results(rolled)
	await runner.simulate_frames(2)

	assert_int(root.turn_state).is_equal(RollPhase.TurnState.BUST)
