class_name SteamIntegration
extends Node
## Steam integration hooks for cosmetics and achievements.
## This is a wrapper layer that can connect to actual Steamworks SDK implementation.
## For now, it provides the interface and mock implementations.

# Steam App ID (set this to your game's Steam App ID when publishing)
const STEAM_APP_ID: int = 0  # 0 = offline/testing mode

# Track which Steam achievements have been unlocked this session
var _unlocked_achievements: Dictionary = {}


func _ready() -> void:
	_initialize_steam()


func _initialize_steam() -> void:
	"""Initialize Steam connection. Will be no-op if STEAM_APP_ID is 0."""
	if STEAM_APP_ID == 0:
		push_notification("Steam: Offline mode (STEAM_APP_ID = 0)")
		return
	
	# TODO: Implement actual Steamworks SDK initialization here
	# For now, this is a placeholder
	push_notification("Steam: Initialized (mock mode)")


func unlock_cosmetic_achievement(steam_achievement_id: String) -> void:
	"""Unlock a Steam achievement when a cosmetic is purchased."""
	if STEAM_APP_ID == 0:
		# Offline mode - just log it
		_unlocked_achievements[steam_achievement_id] = true
		return
	
	# TODO: Call Steamworks Set Achievement API
	# Example: Steam.user_stats.setAchievement(steam_achievement_id)
	_unlocked_achievements[steam_achievement_id] = true
	push_notification("Steam: Achievement unlocked: %s" % steam_achievement_id)


func is_achievement_unlocked(steam_achievement_id: String) -> bool:
	"""Check if a Steam achievement has been unlocked."""
	if STEAM_APP_ID == 0:
		return _unlocked_achievements.get(steam_achievement_id, false)
	
	# TODO: Call Steamworks Get Achievement API
	# Example: return Steam.user_stats.isAchievementUnlocked(steam_achievement_id)
	return _unlocked_achievements.get(steam_achievement_id, false)


func upload_cosmetic_stats() -> void:
	"""Sync cosmetic purchase stats with Steam (for leaderboards, if desired)."""
	if STEAM_APP_ID == 0:
		return
	
	# TODO: Call Steamworks Store Stats API if tracking cosmetics in leaderboards
	# Example: Steam.user_stats.storeStats()
	push_notification("Steam: Cosmetic stats synced")


func push_notification(message: String) -> void:
	"""Log a notification (useful for debugging Steam integration)."""
	print("[SteamIntegration] %s" % message)
