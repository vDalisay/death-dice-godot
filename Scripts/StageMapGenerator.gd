class_name StageMapGenerator
extends RefCounted
## Generates StageMapData while keeping generation algorithms out of the data Resource.

const StageMapDataScript := preload("res://Scripts/StageMapData.gd")
const MapNodeDataScript := preload("res://Scripts/MapNodeData.gd")
const SpecialStageCatalogScript: GDScript = preload("res://Scripts/SpecialStageCatalog.gd")
const SpecialStageRegistryScript: GDScript = preload("res://Scripts/SpecialStageRegistry.gd")

const NORMAL_STAGE_RATIO: float = 0.5
const SHOP_RATIO: float = 0.15
const EVENT_RATIO: float = 0.15
const FORGE_RATIO: float = 0.10
const REST_RATIO: float = 0.10
const FINAL_ROW_INDEX_FROM_END: int = 1
const MIN_CONNECTIONS_PER_NODE: int = 1
const MAX_CONNECTIONS_PER_NODE: int = 2
const SPECIAL_STAGE_MIN_ROW_INDEX: int = 1
const SPECIAL_STAGE_LOOP_ONE_COUNT: int = 2
const SPECIAL_STAGE_LOOP_TWO_PLUS_COUNT: int = 3


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

	var node_types: Array[MapNodeData.NodeType] = allocate_node_types_for_loop(total_nodes, _loop)
	var special_rule_ids: Array[String] = allocate_special_rule_ids(node_types, _loop)

	var type_index: int = 0
	for row_index: int in StageMapDataScript.ROWS_PER_LOOP:
		var row: Array[MapNodeData] = []
		for col_index: int in row_sizes[row_index]:
			var node: MapNodeData = MapNodeDataScript.new() as MapNodeData
			node.type = node_types[type_index]
			node.special_rule_id = special_rule_ids[type_index]
			node.column = col_index
			type_index += 1
			row.append(node)
		map.rows.append(row)

	assign_special_stage_variants(map as StageMapData, _loop)

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
	return allocate_node_types_for_loop(total_nodes, 1)


static func allocate_node_types_for_loop(total_nodes: int, loop_number: int) -> Array[MapNodeData.NodeType]:
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

	_inject_special_stage_types(types, loop_number)

	return types


static func desired_special_stage_count(loop_number: int) -> int:
	if loop_number <= 1:
		return SPECIAL_STAGE_LOOP_ONE_COUNT
	return SPECIAL_STAGE_LOOP_TWO_PLUS_COUNT


static func assign_special_stage_variants(map: StageMapData, loop_number: int) -> void:
	if map == null:
		return
	var available_variants: Array[int] = SpecialStageCatalogScript.get_mvp_shortlist()
	available_variants.shuffle()
	var eligible_rows: Array[int] = []
	for row_index: int in range(SPECIAL_STAGE_MIN_ROW_INDEX, maxi(map.get_row_count() - 1, 0)):
		var row_nodes: Array[MapNodeData] = map.get_row(row_index)
		for node: MapNodeData in row_nodes:
			if node != null and node.type == MapNodeData.NodeType.NORMAL_STAGE and not node.has_special_stage_variant():
				eligible_rows.append(row_index)
				break
	eligible_rows.shuffle()
	var assign_count: int = mini(desired_special_stage_count(loop_number), mini(available_variants.size(), eligible_rows.size()))
	for assignment_index: int in assign_count:
		var row_index: int = eligible_rows[assignment_index]
		var candidates: Array[MapNodeData] = []
		for node: MapNodeData in map.get_row(row_index):
			if node != null and node.type == MapNodeData.NodeType.NORMAL_STAGE and not node.has_special_stage_variant():
				candidates.append(node)
		if candidates.is_empty():
			continue
		candidates.shuffle()
		candidates[0].stage_variant = int(available_variants[assignment_index])


static func allocate_special_rule_ids(types: Array[MapNodeData.NodeType], loop_number: int) -> Array[String]:
	var rule_ids: Array[String] = []
	rule_ids.resize(types.size())
	rule_ids.fill("")
	var pool: Array[String] = SpecialStageRegistryScript.call("get_generation_rule_ids", loop_number) as Array[String]
	if pool.is_empty():
		return rule_ids
	var rotating_pool: Array[String] = pool.duplicate()
	rotating_pool.shuffle()
	var pool_index: int = 0
	for i: int in types.size():
		if types[i] != MapNodeData.SPECIAL_STAGE_TYPE:
			continue
		if pool_index >= rotating_pool.size():
			rotating_pool = pool.duplicate()
			rotating_pool.shuffle()
			pool_index = 0
		rule_ids[i] = rotating_pool[pool_index]
		pool_index += 1
	return rule_ids


static func _inject_special_stage_types(types: Array[MapNodeData.NodeType], loop_number: int) -> void:
	var special_count: int = _get_special_stage_count(loop_number, types.size())
	if special_count <= 0:
		return
	var candidate_indices: Array[int] = []
	var normal_count: int = 0
	for t: MapNodeData.NodeType in types:
		if t == MapNodeData.NodeType.NORMAL_STAGE:
			normal_count += 1
	for i: int in maxi(types.size() - 1, 0):
		if types[i] == MapNodeData.NodeType.NORMAL_STAGE:
			candidate_indices.append(i)
	candidate_indices.shuffle()
	var inserted: int = 0
	for index: int in candidate_indices:
		if inserted >= special_count:
			break
		if normal_count <= StageMapDataScript.MIN_NORMAL_STAGES:
			break
		types[index] = MapNodeData.SPECIAL_STAGE_TYPE
		normal_count -= 1
		inserted += 1


static func _get_special_stage_count(loop_number: int, total_nodes: int) -> int:
	if total_nodes < 6:
		return 0
	if loop_number >= 3:
		return 2
	return 1
