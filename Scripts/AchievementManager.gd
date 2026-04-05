extends Node
## Autoload for gameplay achievements with pluggable Steam/local backend.

signal achievement_unlocked(key: String, title: String)

const AchievementDataScript: GDScript = preload("res://Scripts/AchievementData.gd")

# Centralized internal-key -> Steam-ID mapping layer.
const STEAM_ID_MAP: Dictionary = {
	"first_run": "ACH_FIRST_RUN",
	"first_bank": "ACH_FIRST_BANK",
	"first_bust": "ACH_FIRST_BUST",
	"stage_clear": "ACH_STAGE_CLEAR",
	"loop_clear": "ACH_LOOP_CLEAR",
	"hot_streak": "ACH_HOT_STREAK",
	"jackpot": "ACH_JACKPOT",
	"big_bank": "ACH_BIG_BANK",
}

var _definitions: Dictionary = {}
var _backend: AchievementBackend = null


class AchievementBackend:
	extends RefCounted

	func unlock(_steam_id: String) -> void:
		pass

	func is_available() -> bool:
		return false


class LocalAchievementBackend:
	extends AchievementBackend

	func unlock(_steam_id: String) -> void:
		pass

	func is_available() -> bool:
		return true


class SteamAchievementBackend:
	extends AchievementBackend

	var _steam_singleton: Object = null

	func _init(steam_singleton: Object) -> void:
		_steam_singleton = steam_singleton

	func unlock(steam_id: String) -> void:
		if steam_id.is_empty() or _steam_singleton == null:
			return
		if _steam_singleton.has_method("setAchievement"):
			_steam_singleton.call("setAchievement", steam_id)
		if _steam_singleton.has_method("storeStats"):
			_steam_singleton.call("storeStats")

	func is_available() -> bool:
		return _steam_singleton != null


func _ready() -> void:
	_build_definitions()
	_backend = _create_backend()


func _build_definitions() -> void:
	_definitions.clear()
	_definitions["first_run"] = AchievementDataScript.make(
		"first_run",
		"First Steps",
		"Complete your first run.",
		STEAM_ID_MAP["first_run"] as String
	)
	_definitions["first_bank"] = AchievementDataScript.make(
		"first_bank",
		"Banker",
		"Bank score for the first time.",
		STEAM_ID_MAP["first_bank"] as String
	)
	_definitions["first_bust"] = AchievementDataScript.make(
		"first_bust",
		"Kaboom",
		"Bust for the first time.",
		STEAM_ID_MAP["first_bust"] as String
	)
	_definitions["stage_clear"] = AchievementDataScript.make(
		"stage_clear",
		"Stage Winner",
		"Clear a stage.",
		STEAM_ID_MAP["stage_clear"] as String
	)
	_definitions["loop_clear"] = AchievementDataScript.make(
		"loop_clear",
		"Looper",
		"Complete your first loop.",
		STEAM_ID_MAP["loop_clear"] as String
	)
	_definitions["hot_streak"] = AchievementDataScript.make(
		"hot_streak",
		"On Fire",
		"Reach a 5-bank hot streak.",
		STEAM_ID_MAP["hot_streak"] as String
	)
	_definitions["jackpot"] = AchievementDataScript.make(
		"jackpot",
		"Clean Sweep",
		"Trigger a Jackpot clean sweep.",
		STEAM_ID_MAP["jackpot"] as String
	)
	_definitions["big_bank"] = AchievementDataScript.make(
		"big_bank",
		"Big Bank",
		"Bank 100+ points in one turn.",
		STEAM_ID_MAP["big_bank"] as String
	)


func _create_backend() -> AchievementBackend:
	if Engine.has_singleton("Steam"):
		var steam_singleton: Object = Engine.get_singleton("Steam")
		return SteamAchievementBackend.new(steam_singleton)
	return LocalAchievementBackend.new()


func unlock(key: String) -> bool:
	if not _achievements_enabled_for_current_run():
		return false
	if not _definitions.has(key):
		return false
	if not SaveManager.set_achievement_unlocked(key):
		return false
	var data: AchievementData = _definitions[key] as AchievementData
	if data != null and _backend != null:
		_backend.unlock(data.steam_id)
		achievement_unlocked.emit(data.key, data.title)
	return true


func is_unlocked(key: String) -> bool:
	return SaveManager.is_achievement_unlocked(key)


func get_total_achievement_count() -> int:
	return _definitions.size()


func on_bank(banked: int, reroll_count: int, accumulated_stops: int, dice_count: int, streak: int) -> void:
	unlock("first_bank")
	if banked >= 100:
		unlock("big_bank")
	if streak >= 5:
		unlock("hot_streak")
	if reroll_count == 0 and accumulated_stops == 0 and dice_count >= 5:
		unlock("jackpot")


func on_bust() -> void:
	unlock("first_bust")


func on_stage_cleared() -> void:
	unlock("stage_clear")


func on_loop_advanced(new_loop: int) -> void:
	if new_loop >= 2:
		unlock("loop_clear")


func on_run_recorded(run: RunSaveData) -> void:
	if run != null:
		unlock("first_run")


func _achievements_enabled_for_current_run() -> bool:
	return not GameManager.is_seeded_run
