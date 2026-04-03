class_name StageMapGenerator
extends RefCounted
## Generates StageMapData while keeping generation algorithms out of the data Resource.

const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")

const NORMAL_STAGE_RATIO: float = 0.5
const SHOP_RATIO: float = 0.15
const EVENT_RATIO: float = 0.15
const FORGE_RATIO: float = 0.10
const REST_RATIO: float = 0.10
const FINAL_ROW_INDEX_FROM_END: int = 1
const MIN_CONNECTIONS_PER_NODE: int = 1
const MAX_CONNECTIONS_PER_NODE: int = 2


static func generate(_loop: int) -> Resource:
	var map: Resource = StageMapDataScript.new()
	map.rows.clear()

	var row_sizes: Array[int] = []
	for row_index: int in StageMapDataScript.ROWS_PER_LOOP:
		if row_index == StageMapDataScript.ROWS_PER_LOOP - FINAL_ROW_INDEX_FROM_END:
			row_sizes.append(1)
		else:
			row_sizes.append(randi_range(StageMapDataScript.MIN_NODES_PER_ROW, StageMapDataScript.MAX_NODES_PER_ROW))

	var total_nodes: int = 0
	for size_value: int in row_sizes:
		total_nodes += size_value

	var node_types: Array[MapNodeData.NodeType] = allocate_node_types(total_nodes)

	var type_index: int = 0
	for row_index: int in StageMapDataScript.ROWS_PER_LOOP:
		var row: Array[MapNodeData] = []
		for col_index: int in row_sizes[row_index]:
			var node: MapNodeData = MapNodeData.new()
			node.type = node_types[type_index]
			node.column = col_index
			type_index += 1
			row.append(node)
		map.rows.append(row)

	for row_index: int in StageMapDataScript.ROWS_PER_LOOP - 1:
		var current_row: Array = map.rows[row_index]
		var next_row: Array = map.rows[row_index + 1]
		var current_count: int = current_row.size()
		var next_count: int = next_row.size()
		var reachable: Array[bool] = []
		reachable.resize(next_count)
		reachable.fill(false)

		for node_index: int in current_count:
			var node: MapNodeData = current_row[node_index] as MapNodeData
			node.connections.clear()
			var candidates: Array[int] = adjacent_candidates(node_index, current_count, next_count)
			candidates.shuffle()
			var max_connections: int = mini(MAX_CONNECTIONS_PER_NODE, candidates.size())
			var connection_count: int = MIN_CONNECTIONS_PER_NODE if max_connections <= 1 else randi_range(MIN_CONNECTIONS_PER_NODE, max_connections)
			for candidate_index: int in connection_count:
				node.connections.append(candidates[candidate_index])
				reachable[candidates[candidate_index]] = true

		for next_index: int in next_count:
			if reachable[next_index]:
				continue
			var parent_index: int = nearest_parent(next_index, current_count, next_count)
			var parent: MapNodeData = current_row[parent_index] as MapNodeData
			if not parent.connections.has(next_index):
				parent.connections.append(next_index)

		for node_index: int in current_row.size():
			var node: MapNodeData = current_row[node_index] as MapNodeData
			node.connections.sort()

	return map


static func adjacent_candidates(col: int, current_count: int, next_count: int) -> Array[int]:
	var normalized_pos: float = float(col) / float(maxi(current_count - 1, 1))
	var mapped_center: float = normalized_pos * float(maxi(next_count - 1, 1))
	var center_col: int = roundi(mapped_center)
	var candidates: Array[int] = []
	for candidate_col: int in [center_col - 1, center_col, center_col + 1]:
		if candidate_col < 0 or candidate_col >= next_count:
			continue
		if not candidates.has(candidate_col):
			candidates.append(candidate_col)
	return candidates


static func nearest_parent(target_col: int, current_count: int, next_count: int) -> int:
	var target_pos: float = float(target_col) / float(maxi(next_count - 1, 1))
	var nearest_index: int = 0
	var nearest_distance: float = 999.0
	for parent_index: int in current_count:
		var parent_pos: float = float(parent_index) / float(maxi(current_count - 1, 1))
		var distance: float = absf(parent_pos - target_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = parent_index
	return nearest_index


static func allocate_node_types(total_nodes: int) -> Array[MapNodeData.NodeType]:
	var types: Array[MapNodeData.NodeType] = []

	var normal_count: int = maxi(StageMapDataScript.MIN_NORMAL_STAGES, int(total_nodes * NORMAL_STAGE_RATIO))
	var shop_count: int = mini(StageMapDataScript.MAX_NON_COMBAT_PER_TYPE, maxi(1, int(total_nodes * SHOP_RATIO)))
	var event_count: int = mini(StageMapDataScript.MAX_NON_COMBAT_PER_TYPE, maxi(1, int(total_nodes * EVENT_RATIO)))
	var forge_count: int = mini(StageMapDataScript.MAX_NON_COMBAT_PER_TYPE, maxi(0, int(total_nodes * FORGE_RATIO)))
	var rest_count: int = mini(StageMapDataScript.MAX_NON_COMBAT_PER_TYPE, maxi(0, int(total_nodes * REST_RATIO)))

	var allocated: int = normal_count + shop_count + event_count + forge_count + rest_count
	while allocated > total_nodes:
		if rest_count > 0 and allocated > total_nodes:
			rest_count -= 1
			allocated -= 1
		if forge_count > 0 and allocated > total_nodes:
			forge_count -= 1
			allocated -= 1
		if event_count > 1 and allocated > total_nodes:
			event_count -= 1
			allocated -= 1
		if shop_count > 1 and allocated > total_nodes:
			shop_count -= 1
			allocated -= 1

	while allocated < total_nodes:
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

	if types[types.size() - 1] != MapNodeData.NodeType.NORMAL_STAGE:
		for i: int in types.size():
			if types[i] != MapNodeData.NodeType.NORMAL_STAGE:
				continue
			var temp: MapNodeData.NodeType = types[types.size() - 1]
			types[types.size() - 1] = types[i]
			types[i] = temp
			break

	return types
