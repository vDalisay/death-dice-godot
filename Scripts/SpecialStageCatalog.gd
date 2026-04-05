class_name SpecialStageCatalog
extends RefCounted

enum Variant {
	NONE,
	LUCKY_FLOOR,
	CLEAN_ROOM,
	PRECISION_HALL,
	HOT_TABLE,
	DEVILS_MARGIN,
	BLOOM_CHAMBER,
}

const MVP_SHORTLIST: Array[int] = [
	Variant.LUCKY_FLOOR,
	Variant.CLEAN_ROOM,
	Variant.PRECISION_HALL,
	Variant.HOT_TABLE,
]

const STAGE_INFO: Dictionary = {
	Variant.NONE: {
		"name": "Stage",
		"map_label": "Stage",
		"hover": "Standard stage. No special rules.",
		"accent": Color("#CCCCCC"),
	},
	Variant.LUCKY_FLOOR: {
		"name": "Lucky Floor",
		"map_label": "Lucky",
		"hover": "Lucky Floor: rerolls feed bonus number value for the stage.",
		"accent": Color("#4DD0E1"),
	},
	Variant.CLEAN_ROOM: {
		"name": "Clean Room",
		"map_label": "Clean",
		"hover": "Clean Room: target pressure is trimmed for a cleaner score chase.",
		"accent": Color("#81C784"),
	},
	Variant.PRECISION_HALL: {
		"name": "Precision Hall",
		"map_label": "Precise",
		"hover": "Precision Hall: landing close to target unlocks the payoff hook.",
		"accent": Color("#FFB74D"),
	},
	Variant.HOT_TABLE: {
		"name": "Hot Table",
		"map_label": "Hot",
		"hover": "Hot Table: banking after a dangerous stop climb is the intended test.",
		"accent": Color("#EF5350"),
	},
	Variant.DEVILS_MARGIN: {
		"name": "Devil's Margin",
		"map_label": "Margin",
		"hover": "Devil's Margin: the bust threshold hook tightens this stage's margin.",
		"accent": Color("#AB47BC"),
	},
	Variant.BLOOM_CHAMBER: {
		"name": "Bloom Chamber",
		"map_label": "Bloom",
		"hover": "Bloom Chamber: stage-only upgrade spending opens during this stop.",
		"accent": Color("#AED581"),
	},
}


static func sanitize(variant_value: int) -> int:
	if STAGE_INFO.has(variant_value):
		return variant_value
	return Variant.NONE


static func get_metadata(variant_value: int) -> Dictionary:
	return (STAGE_INFO.get(sanitize(variant_value), STAGE_INFO[Variant.NONE]) as Dictionary).duplicate(true)


static func get_display_name(variant_value: int) -> String:
	return str(get_metadata(variant_value).get("name", "Stage"))


static func get_map_label(variant_value: int) -> String:
	return str(get_metadata(variant_value).get("map_label", "Stage"))


static func get_hover_text(variant_value: int) -> String:
	return str(get_metadata(variant_value).get("hover", "Standard stage. No special rules."))


static func get_accent_color(variant_value: int) -> Color:
	return get_metadata(variant_value).get("accent", Color.WHITE) as Color


static func is_mvp_shortlist_variant(variant_value: int) -> bool:
	return sanitize(variant_value) in MVP_SHORTLIST


static func get_mvp_shortlist() -> Array[int]:
	return MVP_SHORTLIST.duplicate()