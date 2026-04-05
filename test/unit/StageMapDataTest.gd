extends GdUnitTestSuite
## Unit tests for StageMapData and MapNodeData.

const SpecialStageCatalog := preload("res://Scripts/SpecialStageCatalog.gd")


# ---------------------------------------------------------------------------
# MapNodeData basics
# ---------------------------------------------------------------------------

func test_map_node_defaults() -> void:
	var node: MapNodeData = MapNodeData.new()
	assert_int(node.type).is_equal(MapNodeData.NodeType.NORMAL_STAGE)
	assert_bool(node.visited).is_false()
	assert_int(node.column).is_equal(0)
	assert_int(node.connections.size()).is_equal(0)
	assert_str(node.special_rule_id).is_equal("")


func test_map_node_display_name() -> void:
	var node: MapNodeData = MapNodeData.new()
	node.type = MapNodeData.NodeType.SHOP
	assert_str(node.get_display_name()).is_equal("Shop")


func test_map_node_icon() -> void:
	var node: MapNodeData = MapNodeData.new()
	node.type = MapNodeData.NodeType.FORGE
	assert_str(node.get_icon()).is_equal("🔨")


func test_map_node_color() -> void:
	var node: MapNodeData = MapNodeData.new()
	node.type = MapNodeData.NodeType.REST
	assert_object(node.get_color()).is_not_null()


func test_map_node_serialization_roundtrip() -> void:
	var node: MapNodeData = MapNodeData.new()
	node.type = MapNodeData.SPECIAL_STAGE_TYPE
	node.special_rule_id = "clean_room"
	node.connections = [0, 2]
	node.visited = true
	node.column = 1
	node.stage_variant = SpecialStageCatalog.Variant.HOT_TABLE
	var data: Dictionary = node.to_dict()
	var restored: MapNodeData = MapNodeData.from_dict(data)
	assert_int(restored.type).is_equal(MapNodeData.SPECIAL_STAGE_TYPE)
	assert_str(restored.special_rule_id).is_equal("clean_room")
	assert_int(restored.connections.size()).is_equal(2)
	assert_int(restored.connections[0]).is_equal(0)
	assert_int(restored.connections[1]).is_equal(2)
	assert_bool(restored.visited).is_true()
	assert_int(restored.column).is_equal(1)
	assert_int(restored.stage_variant).is_equal(SpecialStageCatalog.Variant.HOT_TABLE)


func test_special_stage_node_uses_variant_metadata() -> void:
	var node: MapNodeData = MapNodeData.new()
	node.stage_variant = SpecialStageCatalog.Variant.CLEAN_ROOM
	assert_bool(node.has_special_stage_variant()).is_true()
	assert_str(node.get_display_name()).is_equal("Clean Room")
	assert_str(node.get_map_label()).is_equal("Clean")
	assert_str(node.get_hover_text()).contains("Clean Room")


func test_special_stage_node_uses_registry_display_data() -> void:
	var node: MapNodeData = MapNodeData.new()
	node.type = MapNodeData.SPECIAL_STAGE_TYPE
	node.special_rule_id = "precision_hall"
	assert_str(node.get_display_name()).is_equal("Precision Hall")
	assert_str(node.get_icon()).is_equal("🎯")
	assert_str(node.get_hover_description()).contains("exactly 2 effective STOP")


# ---------------------------------------------------------------------------
# StageMapData generation
# ---------------------------------------------------------------------------

func test_generate_returns_correct_row_count() -> void:
	var map: StageMapData = StageMapData.generate(1)
	assert_int(map.get_row_count()).is_equal(StageMapData.ROWS_PER_LOOP)


func test_final_row_has_one_node() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		var last_row: Array = map.get_row(StageMapData.ROWS_PER_LOOP - 1)
		assert_int(last_row.size()).is_equal(1)


func test_final_node_is_normal_stage() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		var last_row: Array = map.get_row(StageMapData.ROWS_PER_LOOP - 1)
		var final_node: MapNodeData = last_row[0] as MapNodeData
		assert_int(final_node.type).is_equal(MapNodeData.NodeType.NORMAL_STAGE)


func test_each_row_has_valid_size() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		for r: int in map.get_row_count() - 1:
			var row: Array = map.get_row(r)
			assert_int(row.size()).is_greater_equal(StageMapData.MIN_NODES_PER_ROW)
			assert_int(row.size()).is_less_equal(StageMapData.MAX_NODES_PER_ROW)


func test_minimum_normal_stages() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		var count: int = map.count_type(MapNodeData.NodeType.NORMAL_STAGE)
		assert_int(count).is_greater_equal(StageMapData.MIN_NORMAL_STAGES)


func test_non_combat_types_capped() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		assert_int(map.count_type(MapNodeData.NodeType.SHOP)).is_less_equal(StageMapData.MAX_NON_COMBAT_PER_TYPE)
		assert_int(map.count_type(MapNodeData.NodeType.FORGE)).is_less_equal(StageMapData.MAX_NON_COMBAT_PER_TYPE)
		assert_int(map.count_type(MapNodeData.NodeType.REST)).is_less_equal(StageMapData.MAX_NON_COMBAT_PER_TYPE)
		assert_int(map.count_type(MapNodeData.NodeType.RANDOM_EVENT)).is_less_equal(StageMapData.MAX_NON_COMBAT_PER_TYPE)


func test_every_next_row_node_is_reachable() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		for r: int in map.get_row_count() - 1:
			var current_row: Array = map.get_row(r)
			var next_row: Array = map.get_row(r + 1)
			var reachable: Array[bool] = []
			reachable.resize(next_row.size())
			reachable.fill(false)
			for node: Variant in current_row:
				var n: MapNodeData = node as MapNodeData
				for conn: int in n.connections:
					if conn >= 0 and conn < next_row.size():
						reachable[conn] = true
			for j: int in next_row.size():
				assert_bool(reachable[j]).is_true()


func test_connections_are_sorted() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		for r: int in map.get_row_count():
			var row: Array = map.get_row(r)
			for node: Variant in row:
				var n: MapNodeData = node as MapNodeData
				for c: int in n.connections.size() - 1:
					assert_bool(n.connections[c] <= n.connections[c + 1]).is_true()


func test_connections_within_bounds() -> void:
	for _i: int in 20:
		var map: StageMapData = StageMapData.generate(1)
		for r: int in map.get_row_count() - 1:
			var current_row: Array = map.get_row(r)
			var next_row: Array = map.get_row(r + 1)
			for node: Variant in current_row:
				var n: MapNodeData = node as MapNodeData
				for conn: int in n.connections:
					assert_int(conn).is_greater_equal(0)
					assert_int(conn).is_less(next_row.size())


# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

func test_get_node_at_valid() -> void:
	var map: StageMapData = StageMapData.generate(1)
	var node: MapNodeData = map.get_node_at(0, 0)
	assert_object(node).is_not_null()


func test_get_node_at_out_of_bounds() -> void:
	var map: StageMapData = StageMapData.generate(1)
	assert_object(map.get_node_at(-1, 0)).is_null()
	assert_object(map.get_node_at(100, 0)).is_null()
	assert_object(map.get_node_at(0, 100)).is_null()


func test_is_reachable_from_parent() -> void:
	var map: StageMapData = StageMapData.generate(1)
	var first_row: Array = map.get_row(0)
	var node: MapNodeData = first_row[0] as MapNodeData
	if node.connections.size() > 0:
		var target_col: int = node.connections[0]
		assert_bool(map.is_reachable(1, target_col, 0, 0)).is_true()


func test_is_reachable_wrong_row() -> void:
	var map: StageMapData = StageMapData.generate(1)
	# Row 3 is not reachable from row 0 (must be consecutive).
	assert_bool(map.is_reachable(3, 0, 0, 0)).is_false()


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func test_map_serialization_roundtrip() -> void:
	var map: StageMapData = StageMapData.generate(1)
	var data: Dictionary = map.to_dict()
	var restored: StageMapData = StageMapData.from_dict(data)
	assert_int(restored.get_row_count()).is_equal(map.get_row_count())
	for r: int in map.get_row_count():
		assert_int(restored.get_row(r).size()).is_equal(map.get_row(r).size())
		for c: int in map.get_row(r).size():
			var orig: MapNodeData = map.get_node_at(r, c)
			var rest: MapNodeData = restored.get_node_at(r, c)
			assert_int(rest.type).is_equal(orig.type)
			assert_int(rest.connections.size()).is_equal(orig.connections.size())
			assert_int(rest.stage_variant).is_equal(orig.stage_variant)


func test_count_special_stage_nodes_tracks_variant_counts() -> void:
	var map := StageMapData.new()
	map.rows = [
		[_make_node([0], false, 0, SpecialStageCatalog.Variant.NONE)],
		[_make_node([0], false, 0, SpecialStageCatalog.Variant.CLEAN_ROOM), _make_node([0], false, 1, SpecialStageCatalog.Variant.HOT_TABLE)],
		[_make_node([], false, 0, SpecialStageCatalog.Variant.NONE)],
	]
	assert_int(map.count_special_stage_nodes()).is_equal(2)
	assert_int(map.count_stage_variant(SpecialStageCatalog.Variant.CLEAN_ROOM)).is_equal(1)
	assert_int(map.count_stage_variant(SpecialStageCatalog.Variant.HOT_TABLE)).is_equal(1)


# ---------------------------------------------------------------------------
# Different loops
# ---------------------------------------------------------------------------

func test_generate_loop_2() -> void:
	var map: StageMapData = StageMapData.generate(2)
	assert_int(map.get_row_count()).is_equal(StageMapData.ROWS_PER_LOOP)
	# Should still obey all the same constraints.
	assert_int(map.count_type(MapNodeData.NodeType.NORMAL_STAGE)).is_greater_equal(StageMapData.MIN_NORMAL_STAGES)


func test_generated_maps_include_special_stage_metadata() -> void:
	var map: StageMapData = StageMapData.generate(1)
	var special_count: int = 0
	for r: int in map.get_row_count():
		for node: MapNodeData in map.get_row(r):
			if node.type != MapNodeData.SPECIAL_STAGE_TYPE:
				continue
			special_count += 1
			assert_str(node.special_rule_id).is_not_empty()
	assert_int(special_count).is_greater_equal(1)


func test_connections_are_proportionally_adjacent() -> void:
	# StS-style: connections only go to columns within ±1 of proportional mapping.
	for _i: int in 30:
		var map: StageMapData = StageMapData.generate(1)
		for r: int in map.get_row_count() - 1:
			var current_row: Array = map.get_row(r)
			var next_row: Array = map.get_row(r + 1)
			var cur_count: int = current_row.size()
			var next_count: int = next_row.size()
			for c: int in cur_count:
				var node: MapNodeData = current_row[c] as MapNodeData
				var valid: Array[int] = StageMapData._adjacent_candidates(c, cur_count, next_count)
				for conn: int in node.connections:
					assert_bool(valid.has(conn)).is_true()


func _make_node(connections: Array[int], visited: bool, column: int, stage_variant: int) -> MapNodeData:
	var node := MapNodeData.new()
	node.type = MapNodeData.NodeType.NORMAL_STAGE
	node.connections = connections.duplicate()
	node.visited = visited
	node.column = column
	node.stage_variant = stage_variant
	return node
