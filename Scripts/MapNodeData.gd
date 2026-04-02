class_name MapNodeData
extends Resource
## A single node on the stage map. Holds type, connections to next row, and visit state.

enum NodeType { NORMAL_STAGE, SHOP, RANDOM_EVENT, FORGE, REST }

const NODE_TYPE_NAMES: Dictionary = {
	NodeType.NORMAL_STAGE: "Stage",
	NodeType.SHOP: "Shop",
	NodeType.RANDOM_EVENT: "Event",
	NodeType.FORGE: "Forge",
	NodeType.REST: "Rest",
}

const NODE_TYPE_ICONS: Dictionary = {
	NodeType.NORMAL_STAGE: "⚔",
	NodeType.SHOP: "🛒",
	NodeType.RANDOM_EVENT: "❓",
	NodeType.FORGE: "🔨",
	NodeType.REST: "💤",
}

const NODE_TYPE_COLORS: Dictionary = {
	NodeType.NORMAL_STAGE: Color("#CCCCCC"),
	NodeType.SHOP: Color("#FFD700"),
	NodeType.RANDOM_EVENT: Color("#BB86FC"),
	NodeType.FORGE: Color("#FF6B35"),
	NodeType.REST: Color("#00E676"),
}

@export var type: NodeType = NodeType.NORMAL_STAGE
## Indices into the next row that this node connects to.
@export var connections: Array[int] = []
@export var visited: bool = false
## Column index within the row (set during generation).
@export var column: int = 0


func get_display_name() -> String:
	return NODE_TYPE_NAMES.get(type, "Unknown")


func get_icon() -> String:
	return NODE_TYPE_ICONS.get(type, "?")


func get_color() -> Color:
	return NODE_TYPE_COLORS.get(type, Color.WHITE)


func to_dict() -> Dictionary:
	return {
		"type": type,
		"connections": connections,
		"visited": visited,
		"column": column,
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
	return node
