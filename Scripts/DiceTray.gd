class_name DiceTray
extends HFlowContainer
## Manages a dynamic grid of DieButton instances.
## Proxies die toggle signals upward to the RollPhase.

signal die_toggled(die_index: int, is_kept: bool)

const DIE_BUTTON_SCENE: PackedScene = preload("res://Scenes/DieButton.tscn")

var _buttons: Array[DieButton] = []

func get_die_button(index: int) -> DieButton:
	return _buttons[index]

func get_button_count() -> int:
	return _buttons.size()

# ---------------------------------------------------------------------------
# Public API — called by RollPhase
# ---------------------------------------------------------------------------

func build(count: int) -> void:
	_clear()
	for i: int in count:
		var btn: DieButton = DIE_BUTTON_SCENE.instantiate() as DieButton
		btn.setup(i)
		if i < GameManager.dice_pool.size():
			btn.custom_color = GameManager.dice_pool[i].custom_color
		btn.toggled_keep.connect(_on_die_toggled)
		add_child(btn)
		_buttons.append(btn)

func update_die(index: int, face: DiceFaceData, state: DieButton.DieState) -> void:
	_buttons[index].show_face(face, state)

func lock_die(index: int, state: DieButton.DieState) -> void:
	_buttons[index].set_state(state)

func pop_die(index: int) -> void:
	_buttons[index].pop()


func tumble_die(index: int, face: DiceFaceData, state: DieButton.DieState) -> void:
	_buttons[index].tumble(face, state)


func show_chain_label(index: int, depth: int) -> void:
	_buttons[index].show_chain_label(depth)


func show_score_popup(index: int, value: int) -> void:
	_buttons[index].show_score_popup(value)


func reset_all() -> void:
	for btn: DieButton in _buttons:
		btn.setup(btn.die_index)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _on_die_toggled(die_index: int, is_kept: bool) -> void:
	die_toggled.emit(die_index, is_kept)

func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	_buttons.clear()
