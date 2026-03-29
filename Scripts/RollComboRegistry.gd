extends Node
## Autoload registry for named roll combos.

var _combos: Array[RollCombo] = []


func _ready() -> void:
	_ensure_default_combos()


func get_triggered_combos(results: Array[DiceFaceData], dice_stopped: Array[bool]) -> Array[RollCombo]:
	_ensure_default_combos()
	var face_counts: Dictionary = _build_face_counts(results, dice_stopped)
	var triggered: Array[RollCombo] = []
	for combo: RollCombo in _combos:
		if combo.matches(face_counts):
			triggered.append(combo)
	return triggered


func get_all_combos() -> Array[RollCombo]:
	_ensure_default_combos()
	return _combos.duplicate()


func _ensure_default_combos() -> void:
	if not _combos.is_empty():
		return
	_combos = [
		RollCombo.make(
			"shield_wall",
			"Shield Wall",
			{DiceFaceData.FaceType.SHIELD: 2},
			Color(0.35, 0.75, 1.0)
		),
		RollCombo.make(
			"chain_reaction",
			"Chain Reaction",
			{DiceFaceData.FaceType.EXPLODE: 2},
			Color(1.0, 0.55, 0.15)
		),
		RollCombo.make(
			"power_pair",
			"Power Pair",
			{DiceFaceData.FaceType.MULTIPLY: 1, DiceFaceData.FaceType.MULTIPLY_LEFT: 1},
			Color(0.95, 0.5, 0.8)
		),
	]


func _build_face_counts(results: Array[DiceFaceData], dice_stopped: Array[bool]) -> Dictionary:
	var counts: Dictionary = {}
	for i: int in results.size():
		var face: DiceFaceData = results[i]
		if face == null:
			continue
		if i < dice_stopped.size() and dice_stopped[i]:
			continue
		var face_type: int = face.type
		counts[face_type] = int(counts.get(face_type, 0)) + 1
	return counts
