class_name ActiveRunSaveData
extends Resource
## Snapshot of an in-progress run used for continue/resume.

@export var save_version: int = 1
@export var created_unix_time: int = 0

@export var is_seeded_run: bool = false
@export var run_seed_text: String = ""
@export var seed_version: int = 1
@export var rng_stream_states: Dictionary = {}

@export var resume_surface: String = ""
@export var resume_payload: Dictionary = {}

@export var game_manager_state: Dictionary = {}
@export var roll_phase_state: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"created_unix_time": created_unix_time,
		"is_seeded_run": is_seeded_run,
		"run_seed_text": run_seed_text,
		"seed_version": seed_version,
		"rng_stream_states": rng_stream_states,
		"resume_surface": resume_surface,
		"resume_payload": resume_payload,
		"game_manager_state": game_manager_state,
		"roll_phase_state": roll_phase_state,
	}


static func from_dict(data: Dictionary) -> Resource:
	var snapshot: Resource = preload("res://Scripts/ActiveRunSaveData.gd").new()
	snapshot.save_version = int(data.get("save_version", 1))
	snapshot.created_unix_time = int(data.get("created_unix_time", 0))
	snapshot.is_seeded_run = bool(data.get("is_seeded_run", false))
	snapshot.run_seed_text = str(data.get("run_seed_text", ""))
	snapshot.seed_version = int(data.get("seed_version", 1))
	snapshot.rng_stream_states = data.get("rng_stream_states", {}) as Dictionary
	snapshot.resume_surface = str(data.get("resume_surface", ""))
	snapshot.resume_payload = data.get("resume_payload", {}) as Dictionary
	snapshot.game_manager_state = data.get("game_manager_state", {}) as Dictionary
	snapshot.roll_phase_state = data.get("roll_phase_state", {}) as Dictionary
	return snapshot
