class_name RollCombo
extends Resource
## Data-driven combo definition evaluated from the current rolled faces.

@export var combo_id: String = ""
@export var display_name: String = ""
@export var required_faces: Dictionary = {}
@export var flash_color: Color = Color.WHITE
## Bonus points awarded when this combo is active at bank time.
@export var bonus_points: int = 0


static func make(id: String, name: String, requirements: Dictionary, color: Color, bonus: int = 0) -> RollCombo:
	var combo: RollCombo = RollCombo.new()
	combo.combo_id = id
	combo.display_name = name
	combo.required_faces = requirements
	combo.flash_color = color
	combo.bonus_points = bonus
	return combo


func matches(face_counts: Dictionary) -> bool:
	for key: Variant in required_faces.keys():
		var face_type: int = int(key)
		var required_count: int = int(required_faces[key])
		var actual_count: int = int(face_counts.get(face_type, 0))
		if actual_count < required_count:
			return false
	return true
