class_name DiceFaceData
extends Resource

enum FaceType { NUMBER, BLANK, STOP, AUTO_KEEP, SHIELD, MULTIPLY }

@export var type: FaceType = FaceType.NUMBER
@export var value: int = 0

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
	return "?"
