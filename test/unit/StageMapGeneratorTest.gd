extends GdUnitTestSuite
## Unit tests for StageMapGenerator.

const SpecialStageCatalog := preload("res://Scripts/SpecialStageCatalog.gd")


func test_generate_builds_valid_map_shape() -> void:
	var map: StageMapData = StageMapGenerator.generate(1)
	assert_int(map.get_row_count()).is_equal(StageMapData.ROWS_PER_LOOP)
	assert_int(map.get_row(StageMapData.ROWS_PER_LOOP - 1).size()).is_equal(1)


func test_adjacent_candidates_stay_in_bounds() -> void:
	var candidates: Array[int] = StageMapGenerator.adjacent_candidates(0, 3, 2)
	for col: int in candidates:
		assert_int(col).is_greater_equal(0)
		assert_int(col).is_less(2)


func test_allocate_node_types_keeps_minimum_normals() -> void:
	var types: Array[MapNodeData.NodeType] = StageMapGenerator.allocate_node_types(12)
	var normal_count: int = 0
	for t: MapNodeData.NodeType in types:
		if t == MapNodeData.NodeType.NORMAL_STAGE:
			normal_count += 1
	assert_int(normal_count).is_greater_equal(StageMapData.MIN_NORMAL_STAGES)
	assert_int(types[types.size() - 1]).is_equal(MapNodeData.NodeType.NORMAL_STAGE)


func test_assign_special_stage_variants_uses_only_shortlist_on_normal_nodes() -> void:
	var map := StageMapData.new()
	map.rows = [
		[_make_node(MapNodeData.NodeType.NORMAL_STAGE, [0, 1], 0), _make_node(MapNodeData.NodeType.SHOP, [0], 1)],
		[_make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 0), _make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 1)],
		[_make_node(MapNodeData.NodeType.RANDOM_EVENT, [0], 0), _make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 1)],
		[_make_node(MapNodeData.NodeType.FORGE, [0], 0), _make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 1)],
		[_make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 0), _make_node(MapNodeData.NodeType.REST, [0], 1)],
		[_make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 0), _make_node(MapNodeData.NodeType.NORMAL_STAGE, [0], 1)],
		[_make_node(MapNodeData.NodeType.NORMAL_STAGE, [], 0)],
	]
	StageMapGenerator.assign_special_stage_variants(map, 1)
	assert_int(map.count_special_stage_nodes()).is_equal(StageMapGenerator.desired_special_stage_count(1))
	for row_index: int in map.get_row_count():
		var row_special_count: int = 0
		for node: MapNodeData in map.get_row(row_index):
			if not node.has_special_stage_variant():
				continue
			row_special_count += 1
			assert_int(node.type).is_equal(MapNodeData.NodeType.NORMAL_STAGE)
			assert_bool(SpecialStageCatalog.is_mvp_shortlist_variant(node.stage_variant)).is_true()
			assert_int(row_index).is_greater_equal(StageMapGenerator.SPECIAL_STAGE_MIN_ROW_INDEX)
			assert_int(row_index).is_less(StageMapData.ROWS_PER_LOOP - 1)
		assert_int(row_special_count).is_less_equal(1)
	assert_int((map.get_row(StageMapData.ROWS_PER_LOOP - 1)[0] as MapNodeData).stage_variant).is_equal(SpecialStageCatalog.Variant.NONE)


func _make_node(node_type: MapNodeData.NodeType, connections: Array[int], column: int) -> MapNodeData:
	var node := MapNodeData.new()
	node.type = node_type
	node.connections = connections.duplicate()
	node.column = column
	return node
