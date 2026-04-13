class_name ClusterDieHelper
extends RefCounted


static func build_child_faces(parent_value: int) -> Array[DiceFaceData]:
	var faces: Array[DiceFaceData] = []
	var half_value: int = maxi(0, int(floor(float(parent_value) / 2.0)))
	var quarter_value: int = maxi(0, int(floor(float(parent_value) / 4.0)))
	for _i: int in 3:
		var half_face := DiceFaceData.new()
		half_face.type = DiceFaceData.FaceType.NUMBER
		half_face.value = half_value
		faces.append(half_face)
	for _i: int in 3:
		var quarter_face := DiceFaceData.new()
		quarter_face.type = DiceFaceData.FaceType.NUMBER
		quarter_face.value = quarter_value
		faces.append(quarter_face)
	return faces


static func build_child_die(parent: DiceData, parent_face_value: int) -> DiceData:
	var child := DiceData.new()
	child.dice_name = "%s Shard" % parent.dice_name
	child.is_cluster = true
	child.cluster_generation = parent.cluster_generation + 1
	child.max_cluster_depth = parent.max_cluster_depth
	child.category = DiceData.DieCategory.NORMAL
	child.rarity = _child_rarity(parent.rarity)
	child.custom_color = parent.custom_color
	child.faces = build_child_faces(parent_face_value)
	return child


static func _child_rarity(parent_rarity: DiceData.Rarity) -> DiceData.Rarity:
	return maxi(int(DiceData.Rarity.GREY), int(parent_rarity) - 1) as DiceData.Rarity