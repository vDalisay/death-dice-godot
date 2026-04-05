class_name StageMapData
extends Resource
## Holds the full branching map for one loop: 7 rows of MapNodeData.
## Procedurally generated with constraints on node distribution and branching.

const ROWS_PER_LOOP: int = 7
const MIN_NODES_PER_ROW: int = 2
const MAX_NODES_PER_ROW: int = 3
const MIN_NORMAL_STAGES: int = 3
const MAX_NON_COMBAT_PER_TYPE: int = 2
## The map grid: rows[row_index] is an Array[MapNodeData].
@export var rows: Array[Array] = []  # Array of Array[MapNodeData]


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

static func generate(_loop: int) -> StageMapData:
	return _get_stage_map_generator_script().generate(_loop) as StageMapData


## Returns valid connection targets in the next row for a node at (col) in a
## row of (cur_count) nodes connecting to a row of (next_count) nodes.
## Uses proportional mapping: node at position p in current row maps to the
## same proportional position in the next row, ±1 column.
static func _adjacent_candidates(col: int, cur_count: int, next_count: int) -> Array[int]:
	return _get_stage_map_generator_script().adjacent_candidates(col, cur_count, next_count)


## Find the nearest parent node (by proportional column distance) that could
## plausibly connect to target_col in the next row.
static func _nearest_parent(target_col: int, cur_count: int, next_count: int) -> int:
	return _get_stage_map_generator_script().nearest_parent(target_col, cur_count, next_count)


static func _allocate_node_types(total: int) -> Array[MapNodeData.NodeType]:
	return _get_stage_map_generator_script().allocate_node_types(total)


static func _get_stage_map_generator_script() -> GDScript:
	return load("res://Scripts/StageMapGenerator.gd") as GDScript


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

func get_row(index: int) -> Array[MapNodeData]:
	if index < 0 or index >= rows.size():
		return []
	var row_nodes: Array[MapNodeData] = []
	for node: Variant in rows[index] as Array:
		row_nodes.append(node as MapNodeData)
	return row_nodes


func get_row_count() -> int:
	return rows.size()


func get_node_at(row: int, col: int) -> MapNodeData:
	if row < 0 or row >= rows.size():
		return null
	var r: Array = rows[row]
	if col < 0 or col >= r.size():
		return null
	return r[col] as MapNodeData


func is_reachable(row: int, col: int, from_row: int, from_col: int) -> bool:
	## Can the player reach (row, col) from (from_row, from_col)?
	if row != from_row + 1:
		return false
	var parent: MapNodeData = get_node_at(from_row, from_col)
	if parent == null:
		return false
	return parent.connections.has(col)


func count_type(node_type: MapNodeData.NodeType) -> int:
	var count: int = 0
	for row: Array in rows:
		for node: Variant in row:
			var n: MapNodeData = node as MapNodeData
			if n.type == node_type:
				count += 1
	return count


func count_special_stage_nodes() -> int:
	var count: int = 0
	for row: Array in rows:
		for node: Variant in row:
			var n: MapNodeData = node as MapNodeData
			if n != null and n.has_special_stage_variant():
				count += 1
	return count


func count_stage_variant(stage_variant: int) -> int:
	var count: int = 0
	for row: Array in rows:
		for node: Variant in row:
			var n: MapNodeData = node as MapNodeData
			if n != null and n.stage_variant == stage_variant:
				count += 1
	return count


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var row_list: Array = []
	for row: Array in rows:
		var node_list: Array = []
		for node: Variant in row:
			var n: MapNodeData = node as MapNodeData
			node_list.append(n.to_dict())
		row_list.append(node_list)
	return {"rows": row_list}


static func from_dict(data: Dictionary) -> StageMapData:
	var map: StageMapData = StageMapData.new()
	map.rows.clear()
	var raw_rows: Array = data.get("rows", [])
	for row_data: Variant in raw_rows:
		var row: Array[MapNodeData] = []
		for node_data: Variant in row_data as Array:
			row.append(MapNodeData.from_dict(node_data as Dictionary))
		map.rows.append(row)
	return map
