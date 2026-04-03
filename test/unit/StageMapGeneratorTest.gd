extends GdUnitTestSuite
## Unit tests for StageMapGenerator.


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
