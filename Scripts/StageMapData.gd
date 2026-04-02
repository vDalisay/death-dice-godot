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
@export var rows: Array = []  # Array of Array[MapNodeData]


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

static func generate(_loop: int) -> StageMapData:
	var map: StageMapData = StageMapData.new()
	map.rows.clear()

	# Step 1: decide row sizes (last row always 1 node for convergence).
	var row_sizes: Array[int] = []
	for r: int in ROWS_PER_LOOP:
		if r == ROWS_PER_LOOP - 1:
			row_sizes.append(1)
		else:
			row_sizes.append(randi_range(MIN_NODES_PER_ROW, MAX_NODES_PER_ROW))

	# Step 2: allocate node types respecting constraints.
	var total_nodes: int = 0
	for s: int in row_sizes:
		total_nodes += s

	var types: Array[MapNodeData.NodeType] = _allocate_node_types(total_nodes)

	# Step 3: fill the grid row by row.
	var type_idx: int = 0
	for r: int in ROWS_PER_LOOP:
		var row: Array[MapNodeData] = []
		for c: int in row_sizes[r]:
			var node: MapNodeData = MapNodeData.new()
			node.type = types[type_idx]
			node.column = c
			type_idx += 1
			row.append(node)
		map.rows.append(row)

	# Step 4: wire connections — Slay the Spire style.
	# Each node connects only to nodes in the next row at the same column
	# or diagonally adjacent (col ± 1). Never sideways within same row.
	for r: int in ROWS_PER_LOOP - 1:
		var current_row: Array = map.rows[r]
		var next_row: Array = map.rows[r + 1]
		var cur_count: int = current_row.size()
		var next_count: int = next_row.size()
		# Ensure every node in the next row is reachable by at least one parent.
		var reachable: Array[bool] = []
		reachable.resize(next_count)
		reachable.fill(false)
		for n_idx: int in cur_count:
			var node: MapNodeData = current_row[n_idx] as MapNodeData
			node.connections.clear()
			# Candidate targets: columns in next row that are within ±1 of
			# this node's proportional position (scaled for different row widths).
			var candidates: Array[int] = _adjacent_candidates(n_idx, cur_count, next_count)
			candidates.shuffle()
			# Pick 1-2 connections from the valid candidates.
			var num_connections: int = 1 if candidates.size() <= 1 else randi_range(1, mini(2, candidates.size()))
			for j: int in num_connections:
				node.connections.append(candidates[j])
				reachable[candidates[j]] = true
		# Patch: ensure all next-row nodes are reachable.
		for j: int in next_count:
			if not reachable[j]:
				# Find the nearest parent that can reach this column.
				var best_parent: int = _nearest_parent(j, cur_count, next_count)
				var parent: MapNodeData = current_row[best_parent] as MapNodeData
				if not parent.connections.has(j):
					parent.connections.append(j)
		# Sort connections for deterministic rendering.
		for n_idx: int in current_row.size():
			var node: MapNodeData = current_row[n_idx] as MapNodeData
			node.connections.sort()

	return map


## Returns valid connection targets in the next row for a node at (col) in a
## row of (cur_count) nodes connecting to a row of (next_count) nodes.
## Uses proportional mapping: node at position p in current row maps to the
## same proportional position in the next row, ±1 column.
static func _adjacent_candidates(col: int, cur_count: int, next_count: int) -> Array[int]:
	# Map current column to proportional position in [0, 1].
	var t: float = float(col) / float(maxi(cur_count - 1, 1))
	# Map to next row column space.
	var center: float = t * float(maxi(next_count - 1, 1))
	var center_col: int = roundi(center)
	var result: Array[int] = []
	for c: int in [center_col - 1, center_col, center_col + 1]:
		if c >= 0 and c < next_count and not result.has(c):
			result.append(c)
	return result


## Find the nearest parent node (by proportional column distance) that could
## plausibly connect to target_col in the next row.
static func _nearest_parent(target_col: int, cur_count: int, next_count: int) -> int:
	var target_t: float = float(target_col) / float(maxi(next_count - 1, 1))
	var best: int = 0
	var best_dist: float = 999.0
	for p: int in cur_count:
		var p_t: float = float(p) / float(maxi(cur_count - 1, 1))
		var dist: float = absf(p_t - target_t)
		if dist < best_dist:
			best_dist = dist
			best = p
	return best


static func _allocate_node_types(total: int) -> Array[MapNodeData.NodeType]:
	## Allocate node types respecting:
	## - At least MIN_NORMAL_STAGES Normal Stages
	## - No more than MAX_NON_COMBAT_PER_TYPE of any non-combat type
	## - ~50% Normal, ~15% Shop, ~15% Event, ~10% Forge, ~10% Rest
	var types: Array[MapNodeData.NodeType] = []

	# Compute target counts.
	var normal_count: int = maxi(MIN_NORMAL_STAGES, int(total * 0.5))
	var shop_count: int = mini(MAX_NON_COMBAT_PER_TYPE, maxi(1, int(total * 0.15)))
	var event_count: int = mini(MAX_NON_COMBAT_PER_TYPE, maxi(1, int(total * 0.15)))
	var forge_count: int = mini(MAX_NON_COMBAT_PER_TYPE, maxi(0, int(total * 0.10)))
	var rest_count: int = mini(MAX_NON_COMBAT_PER_TYPE, maxi(0, int(total * 0.10)))

	# Clamp totals.
	var allocated: int = normal_count + shop_count + event_count + forge_count + rest_count
	while allocated > total:
		# Reduce from the largest non-normal category.
		if rest_count > 0 and allocated > total:
			rest_count -= 1
			allocated -= 1
		if forge_count > 0 and allocated > total:
			forge_count -= 1
			allocated -= 1
		if event_count > 1 and allocated > total:
			event_count -= 1
			allocated -= 1
		if shop_count > 1 and allocated > total:
			shop_count -= 1
			allocated -= 1
	# Fill remaining with Normal Stages.
	while allocated < total:
		normal_count += 1
		allocated += 1

	for _i: int in normal_count:
		types.append(MapNodeData.NodeType.NORMAL_STAGE)
	for _i: int in shop_count:
		types.append(MapNodeData.NodeType.SHOP)
	for _i: int in event_count:
		types.append(MapNodeData.NodeType.RANDOM_EVENT)
	for _i: int in forge_count:
		types.append(MapNodeData.NodeType.FORGE)
	for _i: int in rest_count:
		types.append(MapNodeData.NodeType.REST)

	types.shuffle()

	# Ensure the final node (row 7) is always a Normal Stage.
	# The last element in the array becomes the convergence node.
	if types[types.size() - 1] != MapNodeData.NodeType.NORMAL_STAGE:
		# Find a Normal Stage and swap it to the end.
		for i: int in types.size():
			if types[i] == MapNodeData.NodeType.NORMAL_STAGE:
				var tmp: MapNodeData.NodeType = types[types.size() - 1]
				types[types.size() - 1] = types[i]
				types[i] = tmp
				break

	return types


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

func get_row(index: int) -> Array:
	if index < 0 or index >= rows.size():
		return []
	return rows[index]


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
