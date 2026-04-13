extends GdUnitTestSuite


func test_build_child_faces_splits_parent_value_into_halves_and_quarters() -> void:
	var faces: Array[DiceFaceData] = ClusterDieHelper.build_child_faces(6)
	assert_int(faces.size()).is_equal(6)
	for index: int in 3:
		assert_int(faces[index].type).is_equal(DiceFaceData.FaceType.NUMBER)
		assert_int(faces[index].value).is_equal(3)
	for index: int in range(3, 6):
		assert_int(faces[index].type).is_equal(DiceFaceData.FaceType.NUMBER)
		assert_int(faces[index].value).is_equal(1)


func test_build_child_die_inherits_cluster_metadata_and_increments_generation() -> void:
	var parent: DiceData = DiceData.make_cluster_d6()
	parent.dice_name = "Cluster Core"
	parent.cluster_generation = 1
	parent.max_cluster_depth = 3
	parent.rarity = DiceData.Rarity.PURPLE
	parent.custom_color = Color(0.25, 0.5, 0.75)

	var child: DiceData = ClusterDieHelper.build_child_die(parent, 8)

	assert_str(child.dice_name).is_equal("Cluster Core Shard")
	assert_bool(child.is_cluster).is_true()
	assert_int(child.cluster_generation).is_equal(2)
	assert_int(child.max_cluster_depth).is_equal(3)
	assert_int(child.category).is_equal(DiceData.DieCategory.NORMAL)
	assert_int(child.rarity).is_equal(DiceData.Rarity.BLUE)
	assert_str(child.custom_color.to_html()).is_equal(parent.custom_color.to_html())
	assert_int(child.faces.size()).is_equal(6)
	assert_int(child.faces[0].value).is_equal(4)
	assert_int(child.faces[3].value).is_equal(2)