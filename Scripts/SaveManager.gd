extends Node
## Persists run history to user://save_data.json. Registered as autoload "SaveManager".

const SAVE_PATH: String = "user://save_data.json"
const RunSaveDataScript: GDScript = preload("res://Scripts/RunSaveData.gd")

# Mastery milestone definitions: runs_used -> unlock cosmetics
const MASTERY_MILESTONES: Dictionary = {
	1: {"level": 1, "cosmetics": []},
	5: {"level": 2, "cosmetics": ["glow"]},
	15: {"level": 3, "cosmetics": ["color_shift"]},
	40: {"level": 4, "cosmetics": ["particle_trail"]},
	100: {"level": 5, "cosmetics": ["legendary_shine"]},
}

signal highscore_changed(new_highscore: int)

var highscore: int = 0
var gauntlet_highscore: int = 0
var max_loops_completed: int = 0
var gauntlet_best_loop: int = 0
var run_history: Array = []
var total_runs: int = 0
var total_busts: int = 0
var total_stages_cleared: int = 0
var career_best_turn_score: int = 0
var career_best_loop: int = 0
var dice_type_counts: Dictionary = {}
var discovered_dice: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var dice_mastery: Dictionary = {}
var purchased_cosmetics: Dictionary = {}  # die_name -> Array[cosmetic_id]
var equipped_cosmetics: Dictionary = {}  # die_name -> cosmetic_id (or "" for none)

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
		update_die_mastery_on_run_completion(die_name)
	if run.score > highscore:
		highscore = run.score
		highscore_changed.emit(highscore)
	if run.run_mode == GameManager.RunMode.GAUNTLET:
		if run.score > gauntlet_highscore:
			gauntlet_highscore = run.score
			highscore_changed.emit(gauntlet_highscore)
		if run.loops_completed > gauntlet_best_loop:
			gauntlet_best_loop = run.loops_completed
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
	run.run_mode = int(GameManager.run_mode)
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


func get_mode_highscore(mode: int) -> int:
	if mode == GameManager.RunMode.GAUNTLET:
		return gauntlet_highscore
	return highscore


func get_mode_best_loop(mode: int) -> int:
	if mode == GameManager.RunMode.GAUNTLET:
		return gauntlet_best_loop
	return career_best_loop


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
# Mastery Progression
# ---------------------------------------------------------------------------

func update_die_mastery_on_run_completion(die_name: String) -> void:
	"""Update mastery level and unlock cosmetics for a die after run completion."""
	if not dice_mastery.has(die_name):
		dice_mastery[die_name] = {"level": 0, "total_runs_used": 0, "unlocked_cosmetics": []}
	
	var mastery: Dictionary = dice_mastery[die_name] as Dictionary
	mastery["total_runs_used"] = int(mastery.get("total_runs_used", 0)) + 1
	
	# Determine new level based on total runs used
	var new_level: int = 0
	var newly_unlocked_cosmetics: Array[String] = []
	
	for threshold: Variant in MASTERY_MILESTONES.keys():
		if mastery["total_runs_used"] >= threshold:
			var milestone: Dictionary = MASTERY_MILESTONES[threshold] as Dictionary
			new_level = milestone.get("level", 0) as int
			for cosmetic: Variant in (milestone.get("cosmetics", []) as Array):
				var cosmetic_name: String = cosmetic as String
				if not (cosmetic_name in (mastery.get("unlocked_cosmetics", []) as Array)):
					newly_unlocked_cosmetics.append(cosmetic_name)
	
	mastery["level"] = new_level
	var current_cosmetics: Array = mastery.get("unlocked_cosmetics", []) as Array
	for cosmetic: String in newly_unlocked_cosmetics:
		current_cosmetics.append(cosmetic)
	mastery["unlocked_cosmetics"] = current_cosmetics
	
	_save()


func get_die_mastery_level(die_name: String) -> int:
	"""Returns mastery level (0-5) for a die. 0 if not yet mastered."""
	if not dice_mastery.has(die_name):
		return 0
	return int((dice_mastery[die_name] as Dictionary).get("level", 0))


func get_die_total_runs_used(die_name: String) -> int:
	"""Returns total number of runs this die was in the player's final pool."""
	if not dice_mastery.has(die_name):
		return 0
	return int((dice_mastery[die_name] as Dictionary).get("total_runs_used", 0))


func is_cosmetic_unlocked(die_name: String, cosmetic: String) -> bool:
	"""Check if a specific cosmetic is unlocked for a die."""
	if not dice_mastery.has(die_name):
		return false
	var unlocked: Array = (dice_mastery[die_name] as Dictionary).get("unlocked_cosmetics", []) as Array
	return cosmetic in unlocked


# ---------------------------------------------------------------------------
# Cosmetics Purchasing & Equipping (Feature #11)
# ---------------------------------------------------------------------------

func is_cosmetic_purchasable(die_name: String, cosmetic_id: String) -> bool:
	"""Check if a cosmetic can be purchased for a die (must be mastery-unlocked but not yet bought)."""
	# First check: die must have this cosmetic unlocked through mastery
	if not is_cosmetic_unlocked(die_name, cosmetic_id):
		return false
	# Second check: cosmetic must not already be purchased
	if is_cosmetic_purchased(die_name, cosmetic_id):
		return false
	return true


func is_cosmetic_purchased(die_name: String, cosmetic_id: String) -> bool:
	"""Check if a cosmetic has been purchased for a die."""
	if not purchased_cosmetics.has(die_name):
		return false
	var owned: Array = purchased_cosmetics[die_name] as Array
	return cosmetic_id in owned


func purchase_cosmetic(die_name: String, cosmetic_id: String) -> bool:
	"""Purchase a cosmetic for a die. Returns true if successful."""
	if not is_cosmetic_purchasable(die_name, cosmetic_id):
		return false
	if not purchased_cosmetics.has(die_name):
		purchased_cosmetics[die_name] = []
	(purchased_cosmetics[die_name] as Array).append(cosmetic_id)
	_save()
	return true


func equip_cosmetic(die_name: String, cosmetic_id: String) -> bool:
	"""Equip a cosmetic for a die. Cosmetic must be purchased."""
	if not is_cosmetic_purchased(die_name, cosmetic_id):
		return false
	if not equipped_cosmetics.has(die_name):
		equipped_cosmetics[die_name] = ""
	equipped_cosmetics[die_name] = cosmetic_id
	_save()
	return true


func unequip_cosmetic(die_name: String) -> void:
	"""Unequip current cosmetic for a die."""
	if not equipped_cosmetics.has(die_name):
		equipped_cosmetics[die_name] = ""
	equipped_cosmetics[die_name] = ""
	_save()


func get_equipped_cosmetic(die_name: String) -> String:
	"""Get the currently equipped cosmetic ID for a die. Returns empty string if none."""
	if not equipped_cosmetics.has(die_name):
		return ""
	return equipped_cosmetics[die_name] as String


func get_purchased_cosmetics_for_die(die_name: String) -> Array:
	"""Get array of purchased cosmetic IDs for a die."""
	if not purchased_cosmetics.has(die_name):
		return []
	return (purchased_cosmetics[die_name] as Array).duplicate()




func _save() -> void:
	var runs_array: Array[Dictionary] = []
	for run: RunSaveData in run_history:
		runs_array.append(run.to_dict())
	var data: Dictionary = {
		"highscore": highscore,
		"gauntlet_highscore": gauntlet_highscore,
		"max_loops_completed": max_loops_completed,
		"gauntlet_best_loop": gauntlet_best_loop,
		"total_runs": total_runs,
		"total_busts": total_busts,
		"total_stages_cleared": total_stages_cleared,
		"career_best_turn_score": career_best_turn_score,
		"career_best_loop": career_best_loop,
		"dice_type_counts": dice_type_counts,
		"discovered_dice": discovered_dice,
		"unlocked_achievements": unlocked_achievements,
		"dice_mastery": dice_mastery,
		"purchased_cosmetics": purchased_cosmetics,
		"equipped_cosmetics": equipped_cosmetics,
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
	gauntlet_highscore = data.get("gauntlet_highscore", 0) as int
	max_loops_completed = data.get("max_loops_completed", 0) as int
	gauntlet_best_loop = data.get("gauntlet_best_loop", 0) as int
	total_runs = data.get("total_runs", 0) as int
	total_busts = data.get("total_busts", 0) as int
	total_stages_cleared = data.get("total_stages_cleared", 0) as int
	career_best_turn_score = data.get("career_best_turn_score", 0) as int
	career_best_loop = data.get("career_best_loop", 0) as int
	dice_type_counts = data.get("dice_type_counts", {}) as Dictionary
	discovered_dice = data.get("discovered_dice", {}) as Dictionary
	unlocked_achievements = data.get("unlocked_achievements", {}) as Dictionary
	dice_mastery = data.get("dice_mastery", {}) as Dictionary
	purchased_cosmetics = data.get("purchased_cosmetics", {}) as Dictionary
	equipped_cosmetics = data.get("equipped_cosmetics", {}) as Dictionary
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
			save.run_mode = (entry as Dictionary).get("run_mode", int(GameManager.RunMode.CLASSIC)) as int
			run_history.append(save)
	highscore_changed.emit(highscore)
