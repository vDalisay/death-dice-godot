class_name ForgePanel
extends PanelContainer
## Dice Forge: sacrifice 2 dice to create a new die of higher rarity.
## Self-contained panel — call open() and listen for forge_closed signal.

signal forge_closed()

const MIN_DICE_FOR_FORGE: int = 4
const FORGE_CHANCE: float = 0.25

@onready var _instruction_label: Label = $MarginContainer/VBoxContainer/InstructionLabel
@onready var _grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var _result_label: Label = $MarginContainer/VBoxContainer/ResultLabel
@onready var _forge_button: Button = $MarginContainer/VBoxContainer/ButtonRow/ForgeButton
@onready var _skip_button: Button = $MarginContainer/VBoxContainer/ButtonRow/SkipButton

var _selected_indices: Array[int] = []
var _die_buttons: Array[Button] = []
var _forging_done: bool = false


func _ready() -> void:
	visible = false
	_forge_button.pressed.connect(_on_forge_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)


func open() -> void:
	_selected_indices.clear()
	_forging_done = false
	_result_label.text = ""
	_forge_button.disabled = true
	_forge_button.text = "Forge!"
	_skip_button.text = "Skip"
	_refresh_grid()
	_update_instruction()
	visible = true


func _on_skip_pressed() -> void:
	visible = false
	forge_closed.emit()


func _on_forge_pressed() -> void:
	if _forging_done:
		visible = false
		forge_closed.emit()
		return

	if _selected_indices.size() != 2:
		return

	# Sort descending so removal doesn't shift earlier indices.
	var sorted: Array[int] = _selected_indices.duplicate()
	sorted.sort()
	sorted.reverse()

	var die_a: DiceData = GameManager.dice_pool[_selected_indices[0]]
	var die_b: DiceData = GameManager.dice_pool[_selected_indices[1]]

	var result_die: DiceData = _roll_forge_result(die_a.rarity, die_b.rarity)
	if result_die == null:
		_result_label.text = "Cannot forge these dice!"
		return

	# Remove sacrificed dice.
	for idx: int in sorted:
		GameManager.dice_pool.remove_at(idx)

	# Add the new die.
	GameManager.add_dice(result_die)
	SaveManager.discover_die(result_die.dice_name)

	var rarity_names: Array[String] = ["Common", "Uncommon", "Rare", "Epic"]
	_result_label.text = "Forged: %s (%s)" % [result_die.dice_name, rarity_names[result_die.rarity]]
	_result_label.modulate = result_die.get_rarity_color_value()

	_forging_done = true
	_forge_button.text = "Continue"
	_forge_button.disabled = false
	_skip_button.visible = false
	_refresh_grid()


func _update_instruction() -> void:
	_instruction_label.text = "Select 2 dice to sacrifice (%d / 2 selected)" % _selected_indices.size()


func _refresh_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_die_buttons.clear()

	for i: int in GameManager.dice_pool.size():
		var die: DiceData = GameManager.dice_pool[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 60)
		btn.text = die.dice_name
		var rarity_names: Array[String] = ["Common", "Uncommon", "Rare", "Epic"]
		btn.tooltip_text = rarity_names[die.rarity]

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.16)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = die.get_rarity_color_value()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)

		if _forging_done:
			btn.disabled = true
		else:
			var idx: int = i
			btn.pressed.connect(func() -> void: _toggle_die(idx))

		if i in _selected_indices:
			var sel_style := style.duplicate() as StyleBoxFlat
			sel_style.bg_color = Color(0.25, 0.25, 0.35)
			sel_style.border_color = Color(1.0, 0.85, 0.0)
			btn.add_theme_stylebox_override("normal", sel_style)

		_die_buttons.append(btn)
		_grid.add_child(btn)


func _toggle_die(index: int) -> void:
	if _forging_done:
		return

	if index in _selected_indices:
		_selected_indices.erase(index)
	elif _selected_indices.size() < 2:
		_selected_indices.append(index)

	_forge_button.disabled = _selected_indices.size() != 2

	# Check if purple + purple (cannot forge).
	if _selected_indices.size() == 2:
		var r1: DiceData.Rarity = GameManager.dice_pool[_selected_indices[0]].rarity
		var r2: DiceData.Rarity = GameManager.dice_pool[_selected_indices[1]].rarity
		if r1 == DiceData.Rarity.PURPLE and r2 == DiceData.Rarity.PURPLE:
			_forge_button.disabled = true
			_result_label.text = "Cannot forge two Epic dice!"
		else:
			_result_label.text = ""

	_update_instruction()
	_refresh_grid()


## Roll the forge outcome based on two sacrifice rarity tiers.
## Returns null only for Purple+Purple (handled above).
static func _roll_forge_result(r1: DiceData.Rarity, r2: DiceData.Rarity) -> DiceData:
	# Normalize so r1 <= r2 (lower or equal tier first).
	if r1 > r2:
		var tmp: DiceData.Rarity = r1
		r1 = r2
		r2 = tmp

	var target_rarity: DiceData.Rarity = _pick_result_rarity(r1, r2)
	return _random_die_of_rarity(target_rarity)


## Pick the result rarity tier from the probability table.
static func _pick_result_rarity(r1: DiceData.Rarity, r2: DiceData.Rarity) -> DiceData.Rarity:
	var roll: float = randf()

	# Same-tier pairs: guaranteed upgrade.
	if r1 == r2:
		match r1:
			DiceData.Rarity.GREY:
				return DiceData.Rarity.GREEN
			DiceData.Rarity.GREEN:
				return DiceData.Rarity.BLUE
			DiceData.Rarity.BLUE:
				return DiceData.Rarity.PURPLE
			DiceData.Rarity.PURPLE:
				# Should not reach here — blocked in UI.
				return DiceData.Rarity.PURPLE

	# Cross-tier pairs.
	match [r1, r2]:
		[DiceData.Rarity.GREY, DiceData.Rarity.GREEN]:
			if roll < 0.55:
				return DiceData.Rarity.GREEN
			elif roll < 0.85:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREY
		[DiceData.Rarity.GREY, DiceData.Rarity.BLUE]:
			if roll < 0.50:
				return DiceData.Rarity.BLUE
			elif roll < 0.80:
				return DiceData.Rarity.GREEN
			return DiceData.Rarity.PURPLE
		[DiceData.Rarity.GREY, DiceData.Rarity.PURPLE]:
			if roll < 0.45:
				return DiceData.Rarity.PURPLE
			elif roll < 0.80:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREEN
		[DiceData.Rarity.GREEN, DiceData.Rarity.BLUE]:
			if roll < 0.55:
				return DiceData.Rarity.BLUE
			elif roll < 0.85:
				return DiceData.Rarity.PURPLE
			return DiceData.Rarity.GREEN
		[DiceData.Rarity.GREEN, DiceData.Rarity.PURPLE]:
			if roll < 0.50:
				return DiceData.Rarity.PURPLE
			elif roll < 0.85:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREEN
		[DiceData.Rarity.BLUE, DiceData.Rarity.PURPLE]:
			if roll < 0.60:
				return DiceData.Rarity.PURPLE
			elif roll < 0.95:
				return DiceData.Rarity.BLUE
			return DiceData.Rarity.GREEN

	# Fallback (shouldn't reach).
	return DiceData.Rarity.GREEN


## Pick a random die of the given rarity tier.
static func _random_die_of_rarity(rarity: DiceData.Rarity) -> DiceData:
	var all: Array[DiceData] = DiceData.get_all_known_dice()
	var candidates: Array[DiceData] = []
	for die: DiceData in all:
		if die.rarity == rarity:
			candidates.append(die)
	if candidates.is_empty():
		return DiceData.make_standard_d6()
	return candidates[randi() % candidates.size()]
