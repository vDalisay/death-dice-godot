class_name AchievementData
extends Resource
## Static definition of an achievement.

@export var key: String = ""
@export var title: String = ""
@export var description: String = ""
@export var steam_id: String = ""


static func make(achievement_key: String, achievement_title: String, achievement_description: String, mapped_steam_id: String) -> AchievementData:
	var data: AchievementData = AchievementData.new()
	data.key = achievement_key
	data.title = achievement_title
	data.description = achievement_description
	data.steam_id = mapped_steam_id
	return data
