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


## Escalating multiplier applied to combo bonus based on active combo count.
const COMBO_ESCALATION_2: float = 1.15
const COMBO_ESCALATION_3_PLUS: float = 1.3


func _ensure_default_combos() -> void:
	if not _combos.is_empty():
		return
	_combos = [
		RollCombo.make(
			"shield_wall",
			"Shield Wall",
			{DiceFaceData.FaceType.SHIELD: 2},
			Color(0.35, 0.75, 1.0),
			5
		),
		RollCombo.make(
			"chain_reaction",
			"Chain Reaction",
			{DiceFaceData.FaceType.EXPLODE: 2},
			Color(1.0, 0.55, 0.15),
			8
		),
		RollCombo.make(
			"power_pair",
			"Power Pair",
			{DiceFaceData.FaceType.MULTIPLY: 2},
			Color(0.95, 0.5, 0.8),
			6
		),
		RollCombo.make(
			"lucky_streak",
			"Lucky Streak",
			{DiceFaceData.FaceType.LUCK: 2},
			Color(0.6, 0.9, 0.3),
			4
		),
		RollCombo.make(
			"full_defense",
			"Full Defense",
			{DiceFaceData.FaceType.SHIELD: 1, DiceFaceData.FaceType.INSURANCE: 1},
			Color(0.3, 0.8, 1.0),
			7
		),
		RollCombo.make(
			"all_in",
			"All In",
			{DiceFaceData.FaceType.EXPLODE: 1, DiceFaceData.FaceType.MULTIPLY: 1},
			Color(1.0, 0.3, 0.3),
			10
		),
	]


## Calculate total combo bonus for a set of active combos (with escalation).
func calculate_combo_bonus(active_combos: Array[RollCombo]) -> int:
	if active_combos.is_empty():
		return 0
	var base: int = 0
	for combo: RollCombo in active_combos:
		base += combo.bonus_points
	var escalation: float = 1.0
	if active_combos.size() == 2:
		escalation = COMBO_ESCALATION_2
	elif active_combos.size() >= 3:
		escalation = COMBO_ESCALATION_3_PLUS
	return roundi(float(base) * escalation)


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
