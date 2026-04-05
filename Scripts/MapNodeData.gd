class_name MapNodeData
extends Resource
## A single node on the stage map. Holds type, connections to next row, and visit state.

const SpecialStageRegistryScript: GDScript = preload("res://Scripts/SpecialStageRegistry.gd")

enum NodeType { NORMAL_STAGE, SHOP, RANDOM_EVENT, FORGE, REST, SPECIAL_STAGE }
const SPECIAL_STAGE_TYPE: NodeType = 5 as NodeType

const NODE_TYPE_NAMES: Dictionary = {
	NodeType.NORMAL_STAGE: "Stage",
	NodeType.SHOP: "Shop",
	NodeType.RANDOM_EVENT: "Event",
	NodeType.FORGE: "Forge",
	NodeType.REST: "Rest",
	NodeType.SPECIAL_STAGE: "Special",
}

const NODE_TYPE_ICONS: Dictionary = {
	NodeType.NORMAL_STAGE: "⚔",
	NodeType.SHOP: "🛒",
	NodeType.RANDOM_EVENT: "❓",
	NodeType.FORGE: "🔨",
	NodeType.REST: "💤",
	NodeType.SPECIAL_STAGE: "✦",
}

const NODE_TYPE_COLORS: Dictionary = {
	NodeType.NORMAL_STAGE: Color("#CCCCCC"),
	NodeType.SHOP: Color("#FFD700"),
	NodeType.RANDOM_EVENT: Color("#BB86FC"),
	NodeType.FORGE: Color("#FF6B35"),
	NodeType.REST: Color("#00E676"),
	NodeType.SPECIAL_STAGE: Color("#7DFF9B"),
}

const NODE_TYPE_STAMPS: Dictionary = {
	NodeType.NORMAL_STAGE: "CLASH",
	NodeType.SHOP: "SHOP",
	NodeType.RANDOM_EVENT: "OMEN",
	NodeType.FORGE: "FORGE",
	NodeType.REST: "REST",
	NodeType.SPECIAL_STAGE: "RULE",
}

const NODE_TYPE_FLAVOR: Dictionary = {
	NodeType.NORMAL_STAGE: "A live table. Push forward and clear the line the hard way.",
	NodeType.SHOP: "A crooked stall lit by brass lamps and bad ideas.",
	NodeType.RANDOM_EVENT: "An unstable detour. Odds shift and the route gets strange.",
	NodeType.FORGE: "A tuning bench where weak faces get cut away and replaced.",
	NodeType.REST: "A rare breather. Patch the run and steady the next climb.",
	NodeType.SPECIAL_STAGE: "A marked rule-board. The next fight runs on altered terms.",
}

const NODE_TYPE_MECHANICS: Dictionary = {
	NodeType.NORMAL_STAGE: "Combat stage: beat the target score to keep climbing.",
	NodeType.SHOP: "Shop: buy dice, modifiers, and side-bet support before the next stage.",
	NodeType.RANDOM_EVENT: "Event: take a swing on a random reward, twist, or payout.",
	NodeType.FORGE: "Forge: upgrade and tune a die in your pool.",
	NodeType.REST: "Rest: recover and take the safer route reward window.",
	NodeType.SPECIAL_STAGE: "Special stage: a rules modifier changes how the next clear pays out.",
}

@export var type: NodeType = NodeType.NORMAL_STAGE
## Indices into the next row that this node connects to.
@export var connections: Array[int] = []
@export var visited: bool = false
## Column index within the row (set during generation).
@export var column: int = 0
@export var stage_variant: int = SpecialStageCatalog.Variant.NONE
@export var special_rule_id: String = ""


func get_display_name() -> String:
	if type == NodeType.NORMAL_STAGE and has_special_stage_variant():
		return SpecialStageCatalog.get_display_name(stage_variant)
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return str(SpecialStageRegistryScript.call("get_rule_name", special_rule_id))
	return NODE_TYPE_NAMES.get(type, "Unknown")


func get_type_name() -> String:
	return NODE_TYPE_NAMES.get(type, "Unknown")


func get_map_label() -> String:
	if type == NodeType.NORMAL_STAGE:
		return SpecialStageCatalog.get_map_label(stage_variant)
	return get_display_name()


func get_hover_text() -> String:
	if type == NodeType.NORMAL_STAGE:
		return SpecialStageCatalog.get_hover_text(stage_variant)
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return "%s: %s" % [get_display_name(), get_hover_description()]
	return "%s node." % get_display_name()


func has_special_stage_variant() -> bool:
	return type == NodeType.NORMAL_STAGE and stage_variant != SpecialStageCatalog.Variant.NONE


func get_icon() -> String:
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return str(SpecialStageRegistryScript.call("get_rule_icon", special_rule_id))
	return NODE_TYPE_ICONS.get(type, "?")


func get_color() -> Color:
	if has_special_stage_variant():
		return SpecialStageCatalog.get_accent_color(stage_variant)
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return SpecialStageRegistryScript.call("get_rule_color", special_rule_id) as Color
	return NODE_TYPE_COLORS.get(type, Color.WHITE)


func get_hover_description() -> String:
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return str(SpecialStageRegistryScript.call("get_rule_summary", special_rule_id))
	if has_special_stage_variant():
		return get_hover_text()
	return get_inspector_summary()


func get_map_stamp() -> String:
	return NODE_TYPE_STAMPS.get(type, "MARK")


func get_inspector_title() -> String:
	return get_display_name()


func get_inspector_type_label() -> String:
	if type == SPECIAL_STAGE_TYPE:
		return "Special Stage"
	return get_type_name()


func get_inspector_flavor() -> String:
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return "A marked rule-board. The next table bends around a named condition."
	return str(NODE_TYPE_FLAVOR.get(type, "A marked path forward."))


func get_inspector_summary() -> String:
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return str(NODE_TYPE_MECHANICS.get(type, get_display_name()))
	return str(NODE_TYPE_MECHANICS.get(type, get_display_name()))


func get_special_rule_preview() -> String:
	if type == SPECIAL_STAGE_TYPE and SpecialStageRegistryScript.call("has_rule", special_rule_id):
		return str(SpecialStageRegistryScript.call("get_rule_summary", special_rule_id))
	return ""


func to_dict() -> Dictionary:
	return {
		"type": type,
		"connections": connections,
		"visited": visited,
		"column": column,
		"stage_variant": stage_variant,
		"special_rule_id": special_rule_id,
	}


static func from_dict(data: Dictionary) -> MapNodeData:
	var node: MapNodeData = MapNodeData.new()
	node.type = int(data.get("type", 0)) as NodeType
	var raw_connections: Array = data.get("connections", [])
	node.connections.clear()
	for c: Variant in raw_connections:
		node.connections.append(int(c))
	node.visited = bool(data.get("visited", false))
	node.column = int(data.get("column", 0))
	node.stage_variant = SpecialStageCatalog.sanitize(int(data.get("stage_variant", SpecialStageCatalog.Variant.NONE)))
	node.special_rule_id = str(data.get("special_rule_id", ""))
	return node
