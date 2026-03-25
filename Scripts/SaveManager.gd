extends Node
## Persists run history to user://save_data.json. Registered as autoload "SaveManager".

const SAVE_PATH: String = "user://save_data.json"
const RunSaveDataScript: GDScript = preload("res://Scripts/RunSaveData.gd")

signal highscore_changed(new_highscore: int)

var highscore: int = 0
var run_history: Array = []

func _ready() -> void:
	_load()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func record_run(run: Resource) -> void:
	run_history.append(run)
	if run.score > highscore:
		highscore = run.score
		highscore_changed.emit(highscore)
	_save()

func make_run_snapshot() -> Resource:
	var run: Resource = RunSaveDataScript.new()
	run.score = GameManager.total_score
	run.timestamp = Time.get_datetime_string_from_system()
	run.stages_cleared = GameManager.total_stages_cleared
	run.loops_completed = GameManager.current_loop - 1
	return run

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _save() -> void:
	var runs_array: Array[Dictionary] = []
	for run: Resource in run_history:
		runs_array.append(run.to_dict())
	var data: Dictionary = {
		"highscore": highscore,
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
	var runs: Array = data.get("runs", []) as Array
	run_history.clear()
	for entry: Variant in runs:
		if entry is Dictionary:
			var save: Resource = RunSaveDataScript.new()
			save.score = (entry as Dictionary).get("score", 0) as int
			save.timestamp = (entry as Dictionary).get("timestamp", "") as String
			save.stages_cleared = (entry as Dictionary).get("stages_cleared", 0) as int
			save.loops_completed = (entry as Dictionary).get("loops_completed", 0) as int
			run_history.append(save)
	highscore_changed.emit(highscore)
