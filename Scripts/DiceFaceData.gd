class_name DiceFaceData
extends Resource

enum FaceType { NUMBER, BLANK, STOP, AUTO_KEEP, SHIELD, MULTIPLY, EXPLODE, MULTIPLY_LEFT, CURSED_STOP, INSURANCE, LUCK, HEART }

var _type_value: FaceType = FaceType.NUMBER

@export var type: FaceType:
	get:
		return _type_value
	set(value):
		_type_value = _normalize_type(value)
@export var value: int = 0


func _init() -> void:
	_type_value = FaceType.NUMBER


static func _normalize_type(value: FaceType) -> FaceType:
	if value == FaceType.MULTIPLY_LEFT:
		return FaceType.MULTIPLY
	return value

func get_display_text() -> String:
	match type:
		FaceType.NUMBER:
			return str(value)
		FaceType.BLANK:
			return "—"
		FaceType.STOP:
			return "STOP"
		FaceType.AUTO_KEEP:
			return "★%d" % value
		FaceType.SHIELD:
			return "SH" if value <= 1 else "SH%d" % value
		FaceType.MULTIPLY:
			return "x%d" % value
		FaceType.EXPLODE:
			return "✦%d" % value
		FaceType.CURSED_STOP:
			return "☠STOP"
		FaceType.INSURANCE:
			return "INS"
		FaceType.LUCK:
			return "LK" if value <= 1 else "LK%d" % value
		FaceType.HEART:
			return "♥" if value <= 1 else "♥%d" % value
	return "?"
