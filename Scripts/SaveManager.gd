extends Node
## Persists run history to user://save_data.json. Registered as autoload "SaveManager".

const SAVE_PATH: String = "user://save_data.json"
const RunSaveDataScript: GDScript = preload("res://Scripts/RunSaveData.gd")

signal highscore_changed(new_highscore: int)

var highscore: int = 0
var max_loops_completed: int = 0
var run_history: Array = []
var total_runs: int = 0
var total_busts: int = 0
var total_stages_cleared: int = 0
var career_best_turn_score: int = 0
var career_best_loop: int = 0
var dice_type_counts: Dictionary = {}
var discovered_dice: Dictionary = {}
var unlocked_achievements: Dictionary = {}

func _ready() -> void:
	_load()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func record_run(run: RunSaveData) -> void:
	run_history.append(run)
	total_runs += 1
	total_busts += run.busts
	total_stages_cleared += run.stages_cleared
	career_best_turn_score = maxi(career_best_turn_score, run.best_turn_score)
	career_best_loop = maxi(career_best_loop, run.loops_completed)
	for die_name: String in run.final_dice_names:
		dice_type_counts[die_name] = int(dice_type_counts.get(die_name, 0)) + 1
		discover_die(die_name)
	if run.score > highscore:
		highscore = run.score
		highscore_changed.emit(highscore)
	if run.loops_completed > max_loops_completed:
		max_loops_completed = run.loops_completed
	_save()

func make_run_snapshot() -> RunSaveData:
	var run: RunSaveData = RunSaveDataScript.new()
	run.score = GameManager.total_score
	run.timestamp = Time.get_datetime_string_from_system()
	run.stages_cleared = GameManager.total_stages_cleared
	run.loops_completed = GameManager.current_loop - 1
	run.busts = GameManager.run_busts
	run.best_turn_score = GameManager.best_turn_score
	var names: Array[String] = []
	for die: DiceData in GameManager.dice_pool:
		names.append(die.dice_name)
	run.final_dice_names = names
	return run


func set_achievement_unlocked(key: String) -> bool:
	if unlocked_achievements.has(key):
		return false
	unlocked_achievements[key] = true
	_save()
	return true


func is_achievement_unlocked(key: String) -> bool:
	return bool(unlocked_achievements.get(key, false))


func get_unlocked_achievement_count() -> int:
	return unlocked_achievements.size()


func get_favorite_die_type() -> String:
	if dice_type_counts.is_empty():
		return "None"
	var best_name: String = ""
	var best_count: int = -1
	for key: Variant in dice_type_counts.keys():
		var die_name: String = key as String
		var count: int = dice_type_counts[key] as int
		if count > best_count:
			best_count = count
			best_name = die_name
	return best_name


func discover_die(die_name: String) -> void:
	if not discovered_dice.has(die_name):
		discovered_dice[die_name] = true
		_save()


func is_die_discovered(die_name: String) -> bool:
	return bool(discovered_dice.get(die_name, false))


func get_discovered_count() -> int:
	return discovered_dice.size()


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _save() -> void:
	var runs_array: Array[Dictionary] = []
	for run: RunSaveData in run_history:
		runs_array.append(run.to_dict())
	var data: Dictionary = {
		"highscore": highscore,
		"max_loops_completed": max_loops_completed,
		"total_runs": total_runs,
		"total_busts": total_busts,
		"total_stages_cleared": total_stages_cleared,
		"career_best_turn_score": career_best_turn_score,
		"career_best_loop": career_best_loop,
		"dice_type_counts": dice_type_counts,
		"discovered_dice": discovered_dice,
		"unlocked_achievements": unlocked_achievements,
		"runs": runs_array,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Could not open %s for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("SaveManager: Failed to parse %s." % SAVE_PATH)
		return
	var data: Dictionary = json.data as Dictionary
	highscore = data.get("highscore", 0) as int
	max_loops_completed = data.get("max_loops_completed", 0) as int
	total_runs = data.get("total_runs", 0) as int
	total_busts = data.get("total_busts", 0) as int
	total_stages_cleared = data.get("total_stages_cleared", 0) as int
	career_best_turn_score = data.get("career_best_turn_score", 0) as int
	career_best_loop = data.get("career_best_loop", 0) as int
	dice_type_counts = data.get("dice_type_counts", {}) as Dictionary
	discovered_dice = data.get("discovered_dice", {}) as Dictionary
	unlocked_achievements = data.get("unlocked_achievements", {}) as Dictionary
	var runs: Array = data.get("runs", []) as Array
	run_history.clear()
	for entry: Variant in runs:
		if entry is Dictionary:
			var save: RunSaveData = RunSaveDataScript.new()
			var final_names: Array[String] = []
			for die_name: Variant in (entry as Dictionary).get("final_dice_names", []) as Array:
				final_names.append(die_name as String)
			save.score = (entry as Dictionary).get("score", 0) as int
			save.timestamp = (entry as Dictionary).get("timestamp", "") as String
			save.stages_cleared = (entry as Dictionary).get("stages_cleared", 0) as int
			save.loops_completed = (entry as Dictionary).get("loops_completed", 0) as int
			save.busts = (entry as Dictionary).get("busts", 0) as int
			save.best_turn_score = (entry as Dictionary).get("best_turn_score", 0) as int
			save.final_dice_names = final_names
			run_history.append(save)
	highscore_changed.emit(highscore)
