class_name DiceCodexPanel
extends PanelContainer
## Dice Codex modal: rich die cards with discovered and locked states.

signal closed()

const _UITheme := preload("res://Scripts/UITheme.gd")

const CARD_WIDTH: int = 294
const CARD_HEIGHT: int = 176
const FACE_TILE_WIDTH: int = 84
const FACE_TILE_HEIGHT: int = 40
const FACE_TILE_PADDING_X: int = 6
const FACE_TILE_PADDING_Y: int = 6

@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _completion_badge: PanelContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CompletionBadge
@onready var _completion_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/CompletionBadge/CompletionMargin/CompletionLabel
@onready var _grid: HFlowContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/ScrollContainer/CardsGrid
@onready var _close_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	_apply_theme_styling()


func open_panel() -> void:
	_refresh()
	visible = true


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var all_dice: Array[DiceData] = DiceData.get_all_known_dice()
	var discovered_count: int = 0
	var total_count: int = all_dice.size()

	for die: DiceData in all_dice:
		var discovered: bool = SaveManager.is_die_discovered(die.dice_name)
		if discovered:
			discovered_count += 1
		_grid.add_child(_build_entry(die, discovered))

	var pct: int = 0
	if total_count > 0:
		pct = int(float(discovered_count) / float(total_count) * 100.0)
	_completion_label.text = "Discovered: %d / %d (%d%%)" % [discovered_count, total_count, pct]


func _build_entry(die: DiceData, discovered: bool) -> PanelContainer:
	var entry := PanelContainer.new()
	entry.name = "Card_%s" % die.dice_name.replace(" ", "_")
	entry.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var border_color: Color = die.get_rarity_color_value() if discovered else _UITheme.MUTED_TEXT
	var bg_color: Color = _UITheme.PANEL_SURFACE if discovered else _UITheme.ELEVATED
	entry.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(bg_color, _UITheme.CORNER_RADIUS_CARD, border_color, 2)
	)

	var margin := MarginContainer.new()
	margin.name = "EntryMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	entry.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "EntryVBox"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "HeaderRow"
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.text = die.dice_name if discovered else "???"
	name_label.add_theme_color_override("font_color", border_color)
	header.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.name = "RarityLabel"
	rarity_label.add_theme_font_override("font", _UITheme.font_mono())
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.text = _rarity_text(die.rarity) if discovered else "LOCKED"
	rarity_label.add_theme_color_override("font_color", border_color)
	header.add_child(rarity_label)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.add_theme_font_override("font", _UITheme.font_body())
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	subtitle.text = "Face Map" if discovered else "Undiscovered die"
	vbox.add_child(subtitle)

	var faces_grid := GridContainer.new()
	faces_grid.name = "FacesGrid"
	faces_grid.columns = 3
	faces_grid.add_theme_constant_override("h_separation", 6)
	faces_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(faces_grid)

	for i: int in 6:
		var tile := _build_face_tile(die.faces[i], discovered)
		faces_grid.add_child(tile)

	return entry


func _build_face_tile(face: DiceFaceData, discovered: bool) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "FaceTile"
	tile.custom_minimum_size = Vector2(FACE_TILE_WIDTH, FACE_TILE_HEIGHT)
	tile.clip_contents = true
	var color: Color = _face_accent(face.type) if discovered else _UITheme.MUTED_TEXT
	tile.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_BADGE, color, 1)
	)

	var content_margin := MarginContainer.new()
	content_margin.name = "FaceTileMargin"
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	content_margin.grow_vertical = Control.GROW_DIRECTION_BOTH
	content_margin.clip_contents = true
	content_margin.add_theme_constant_override("margin_left", FACE_TILE_PADDING_X)
	content_margin.add_theme_constant_override("margin_top", FACE_TILE_PADDING_Y)
	content_margin.add_theme_constant_override("margin_right", FACE_TILE_PADDING_X)
	content_margin.add_theme_constant_override("margin_bottom", FACE_TILE_PADDING_Y)
	tile.add_child(content_margin)

	var center := CenterContainer.new()
	center.name = "FaceTileCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(center)

	var label := Label.new()
	label.name = "FaceLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_override("font", _UITheme.font_mono())
	label.add_theme_font_size_override("font_size", 17)
	if discovered:
		label.text = "%s %s" % [_face_glyph(face.type), face.get_display_text()]
		label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)
	else:
		label.text = "?"
		label.add_theme_color_override("font_color", _UITheme.MUTED_TEXT)
	center.add_child(label)
	return tile


func _apply_theme_styling() -> void:
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color.TRANSPARENT, 0))
	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.PANEL_SURFACE, _UITheme.CORNER_RADIUS_MODAL, _UITheme.ACTION_CYAN, 2)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", _UITheme.ACTION_CYAN)
	_completion_badge.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_BADGE, _UITheme.SCORE_GOLD, 1)
	)
	_completion_label.add_theme_font_override("font", _UITheme.font_stats())
	_completion_label.add_theme_font_size_override("font_size", 15)
	_completion_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)
	_close_button.add_theme_font_override("font", _UITheme.font_display())
	_close_button.add_theme_font_size_override("font_size", 12)


func _face_glyph(face_type: DiceFaceData.FaceType) -> String:
	match face_type:
		DiceFaceData.FaceType.NUMBER:
			return "#"
		DiceFaceData.FaceType.BLANK:
			return "-"
		DiceFaceData.FaceType.STOP:
			return _UITheme.GLYPH_STOP
		DiceFaceData.FaceType.AUTO_KEEP:
			return _UITheme.GLYPH_STAR
		DiceFaceData.FaceType.SHIELD:
			return _UITheme.GLYPH_SHIELD
		DiceFaceData.FaceType.MULTIPLY:
			return "x"
		DiceFaceData.FaceType.EXPLODE:
			return _UITheme.GLYPH_EXPLODE
		DiceFaceData.FaceType.MULTIPLY_LEFT:
			return "<x"
		DiceFaceData.FaceType.CURSED_STOP:
			return _UITheme.GLYPH_CURSED
		DiceFaceData.FaceType.INSURANCE:
			return "!"
		DiceFaceData.FaceType.LUCK:
			return "LK"
		DiceFaceData.FaceType.HEART:
			return _UITheme.GLYPH_HEART
	return "?"


func _face_accent(face_type: DiceFaceData.FaceType) -> Color:
	match face_type:
		DiceFaceData.FaceType.NUMBER:
			return _UITheme.BRIGHT_TEXT
		DiceFaceData.FaceType.BLANK:
			return _UITheme.MUTED_TEXT
		DiceFaceData.FaceType.STOP:
			return _UITheme.DANGER_RED
		DiceFaceData.FaceType.AUTO_KEEP:
			return _UITheme.SCORE_GOLD
		DiceFaceData.FaceType.SHIELD:
			return _UITheme.ACTION_CYAN
		DiceFaceData.FaceType.MULTIPLY:
			return _UITheme.NEON_PURPLE
		DiceFaceData.FaceType.EXPLODE:
			return _UITheme.EXPLOSION_ORANGE
		DiceFaceData.FaceType.MULTIPLY_LEFT:
			return _UITheme.NEON_PURPLE
		DiceFaceData.FaceType.CURSED_STOP:
			return _UITheme.ROSE_ACCENT
		DiceFaceData.FaceType.INSURANCE:
			return _UITheme.SUCCESS_GREEN
		DiceFaceData.FaceType.LUCK:
			return Color(0.6, 0.9, 0.3)
		DiceFaceData.FaceType.HEART:
			return _UITheme.ROSE_ACCENT
	return _UITheme.MUTED_TEXT


func _rarity_text(rarity: DiceData.Rarity) -> String:
	match rarity:
		DiceData.Rarity.GREY:
			return "COMMON"
		DiceData.Rarity.GREEN:
			return "UNCOMMON"
		DiceData.Rarity.BLUE:
			return "RARE"
		DiceData.Rarity.PURPLE:
			return "EPIC"
	return "COMMON"
