class_name DeerSkullDecor
extends Node2D
## Draws a pixel-art deer skull decoration at its position.
## Used as decorative elements in the DiceArena background.

const PIXEL_SIZE: float = 3.0
const SKULL_COLOR: Color = Color("#44445a")
const ANTLER_COLOR: Color = Color("#3a3a50")
const EYE_COLOR: Color = Color("#1a1a2e")

## If true, the skull is drawn mirrored horizontally.
var flip_h: bool = false


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	var px: float = PIXEL_SIZE
	var dir: float = -1.0 if flip_h else 1.0

	# -- Antlers (drawn first, behind skull) --
	# Left antler
	_px(-7 * dir, -12, ANTLER_COLOR, px)
	_px(-8 * dir, -13, ANTLER_COLOR, px)
	_px(-9 * dir, -14, ANTLER_COLOR, px)
	_px(-10 * dir, -14, ANTLER_COLOR, px)
	_px(-6 * dir, -11, ANTLER_COLOR, px)
	_px(-5 * dir, -10, ANTLER_COLOR, px)
	_px(-4 * dir, -9, ANTLER_COLOR, px)
	_px(-9 * dir, -12, ANTLER_COLOR, px)
	_px(-10 * dir, -11, ANTLER_COLOR, px)
	_px(-11 * dir, -12, ANTLER_COLOR, px)
	_px(-7 * dir, -14, ANTLER_COLOR, px)
	_px(-6 * dir, -15, ANTLER_COLOR, px)
	_px(-5 * dir, -15, ANTLER_COLOR, px)

	# Right antler (mirrored)
	_px(7 * dir, -12, ANTLER_COLOR, px)
	_px(8 * dir, -13, ANTLER_COLOR, px)
	_px(9 * dir, -14, ANTLER_COLOR, px)
	_px(10 * dir, -14, ANTLER_COLOR, px)
	_px(6 * dir, -11, ANTLER_COLOR, px)
	_px(5 * dir, -10, ANTLER_COLOR, px)
	_px(4 * dir, -9, ANTLER_COLOR, px)
	_px(9 * dir, -12, ANTLER_COLOR, px)
	_px(10 * dir, -11, ANTLER_COLOR, px)
	_px(11 * dir, -12, ANTLER_COLOR, px)
	_px(7 * dir, -14, ANTLER_COLOR, px)
	_px(6 * dir, -15, ANTLER_COLOR, px)
	_px(5 * dir, -15, ANTLER_COLOR, px)

	# -- Skull cranium --
	# Top row
	for x: int in range(-2, 3):
		_px(float(x) * dir, -8, SKULL_COLOR, px)
	# Upper cranium
	for x: int in range(-3, 4):
		_px(float(x) * dir, -7, SKULL_COLOR, px)
	for x: int in range(-3, 4):
		_px(float(x) * dir, -6, SKULL_COLOR, px)

	# Eye level rows
	for x: int in range(-4, 5):
		_px(float(x) * dir, -5, SKULL_COLOR, px)
	for x: int in range(-4, 5):
		_px(float(x) * dir, -4, SKULL_COLOR, px)

	# Eye sockets (cut holes)
	_px(-2 * dir, -5, EYE_COLOR, px)
	_px(-1 * dir, -5, EYE_COLOR, px)
	_px(-2 * dir, -4, EYE_COLOR, px)
	_px(-1 * dir, -4, EYE_COLOR, px)
	_px(1 * dir, -5, EYE_COLOR, px)
	_px(2 * dir, -5, EYE_COLOR, px)
	_px(1 * dir, -4, EYE_COLOR, px)
	_px(2 * dir, -4, EYE_COLOR, px)

	# Cheek / nose bridge
	for x: int in range(-3, 4):
		_px(float(x) * dir, -3, SKULL_COLOR, px)
	for x: int in range(-2, 3):
		_px(float(x) * dir, -2, SKULL_COLOR, px)

	# Nose hole
	_px(0, -2, EYE_COLOR, px)

	# Lower snout
	for x: int in range(-2, 3):
		_px(float(x) * dir, -1, SKULL_COLOR, px)
	for x: int in range(-1, 2):
		_px(float(x) * dir, 0, SKULL_COLOR, px)

	# Jaw / teeth row
	_px(-2 * dir, 1, SKULL_COLOR, px)
	_px(0, 1, SKULL_COLOR, px)
	_px(2 * dir, 1, SKULL_COLOR, px)


func _px(gx: float, gy: float, color: Color, px: float) -> void:
	draw_rect(Rect2(Vector2(gx * px, gy * px), Vector2(px, px)), color)
