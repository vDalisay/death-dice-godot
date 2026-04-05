class_name SpecialStageRegistry
extends RefCounted

const LUCKY_FLOOR: String = "lucky_floor"
const CLEAN_ROOM: String = "clean_room"
const PRECISION_HALL: String = "precision_hall"
const HOT_TABLE: String = "hot_table"
const DEVILS_MARGIN: String = "devils_margin"
const BLOOM_CHAMBER: String = "bloom_chamber"

const FIRST_WAVE_RULE_IDS: Array[String] = [LUCKY_FLOOR, CLEAN_ROOM, PRECISION_HALL]

const RULES: Dictionary = {
	LUCKY_FLOOR: {
		"name": "Lucky Floor",
		"icon": "🍀",
		"color": Color("#7DFF9B"),
		"summary": "First reroll each turn grants +2 LUCK. Bank after 2+ rerolls for +12g.",
	},
	CLEAN_ROOM: {
		"name": "Clean Room",
		"icon": "🧼",
		"color": Color("#87F3FF"),
		"summary": "Banks with 0-1 effective STOP gain +6 score. Clear clean for +15g.",
	},
	PRECISION_HALL: {
		"name": "Precision Hall",
		"icon": "🎯",
		"color": Color("#FFD166"),
		"summary": "Banks with exactly 2 effective STOP gain +8g. Exact clears gain +3 LUCK.",
	},
	HOT_TABLE: {
		"name": "Hot Table",
		"icon": "🔥",
		"color": Color("#FF8C42"),
		"summary": "Later wave: risky rerolls charge the table for a high-risk clear bonus.",
	},
	DEVILS_MARGIN: {
		"name": "Devil's Margin",
		"icon": "😈",
		"color": Color("#FF6B9D"),
		"summary": "Later wave: near-death banks pay out harder than safe lines.",
	},
	BLOOM_CHAMBER: {
		"name": "Bloom Chamber",
		"icon": "🌸",
		"color": Color("#C59BFF"),
		"summary": "Later wave: evolving dice accelerate and bloom into premium clears.",
	},
}


static func get_rule(rule_id: String) -> Dictionary:
	return (RULES.get(rule_id, {}) as Dictionary).duplicate(true)


static func has_rule(rule_id: String) -> bool:
	return RULES.has(rule_id)


static func get_generation_rule_ids(_loop: int) -> Array[String]:
	return FIRST_WAVE_RULE_IDS.duplicate()


static func get_rule_name(rule_id: String) -> String:
	var rule: Dictionary = RULES.get(rule_id, {}) as Dictionary
	return str(rule.get("name", "Special Stage"))


static func get_rule_icon(rule_id: String) -> String:
	var rule: Dictionary = RULES.get(rule_id, {}) as Dictionary
	return str(rule.get("icon", "✦"))


static func get_rule_color(rule_id: String) -> Color:
	var rule: Dictionary = RULES.get(rule_id, {}) as Dictionary
	return rule.get("color", Color("#7DFF9B")) as Color


static func get_rule_summary(rule_id: String) -> String:
	var rule: Dictionary = RULES.get(rule_id, {}) as Dictionary
	return str(rule.get("summary", ""))