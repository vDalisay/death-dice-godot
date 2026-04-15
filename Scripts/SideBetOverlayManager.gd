class_name SideBetOverlayManager
extends Node
## Manages side-bet overlay lifecycle: double-down, insurance, heat, even/odd.
## Emits overlay_resolved when any bet overlay closes so the shop can regenerate.

signal overlay_resolved()

var _host: Control = null

var _DoubleDownScene: PackedScene = preload("res://Scenes/DoubleDownOverlay.tscn")
var _InsuranceBetScene: PackedScene = preload("res://Scenes/InsuranceBetOverlay.tscn")
var _HeatBetScene: PackedScene = preload("res://Scenes/HeatBetOverlay.tscn")
var _EvenOddBetScene: PackedScene = preload("res://Scenes/EvenOddBetOverlay.tscn")

var _double_down_overlay: DoubleDownOverlay = null
var _insurance_overlay: Node = null
var _heat_overlay: Node = null
var _even_odd_overlay: Node = null

var dd_used: bool = false
var ib_used: bool = false
var hb_used: bool = false
var eo_used: bool = false


func setup(host: Control) -> void:
	_host = host


func reset_used() -> void:
	dd_used = false
	ib_used = false
	hb_used = false
	eo_used = false


# ---------------------------------------------------------------------------
# Double-down
# ---------------------------------------------------------------------------

func open_double_down() -> void:
	if _double_down_overlay != null and is_instance_valid(_double_down_overlay):
		_double_down_overlay.queue_free()
	_double_down_overlay = _DoubleDownScene.instantiate() as DoubleDownOverlay
	_host.add_child(_double_down_overlay)
	_double_down_overlay.resolved.connect(_on_double_down_resolved)
	_double_down_overlay.open(GameManager.gold)


func _on_double_down_resolved() -> void:
	dd_used = true
	if _double_down_overlay != null and is_instance_valid(_double_down_overlay):
		_double_down_overlay.queue_free()
		_double_down_overlay = null
	overlay_resolved.emit()


# ---------------------------------------------------------------------------
# Insurance bet
# ---------------------------------------------------------------------------

func open_insurance_bet() -> void:
	if _insurance_overlay != null and is_instance_valid(_insurance_overlay):
		_insurance_overlay.queue_free()
	var gold_before: int = GameManager.gold
	_insurance_overlay = _InsuranceBetScene.instantiate()
	_host.add_child(_insurance_overlay)
	_insurance_overlay.connect("resolved", Callable(self, "_on_insurance_bet_resolved").bind(gold_before))
	_insurance_overlay.call("open")


func _on_insurance_bet_resolved(gold_before: int) -> void:
	if _insurance_overlay != null and is_instance_valid(_insurance_overlay):
		_insurance_overlay.queue_free()
		_insurance_overlay = null
	if GameManager.gold < gold_before:
		GameManager.track_shop_spend(gold_before - GameManager.gold)
		ib_used = true
	overlay_resolved.emit()


# ---------------------------------------------------------------------------
# Heat bet
# ---------------------------------------------------------------------------

func open_heat_bet() -> void:
	if _heat_overlay != null and is_instance_valid(_heat_overlay):
		_heat_overlay.queue_free()
	var gold_before: int = GameManager.gold
	_heat_overlay = _HeatBetScene.instantiate()
	_host.add_child(_heat_overlay)
	_heat_overlay.connect("resolved", Callable(self, "_on_heat_bet_resolved").bind(gold_before))
	_heat_overlay.call("open")


func _on_heat_bet_resolved(gold_before: int) -> void:
	if _heat_overlay != null and is_instance_valid(_heat_overlay):
		_heat_overlay.queue_free()
		_heat_overlay = null
	if GameManager.gold < gold_before:
		GameManager.track_shop_spend(gold_before - GameManager.gold)
		hb_used = true
	overlay_resolved.emit()


# ---------------------------------------------------------------------------
# Even/Odd bet
# ---------------------------------------------------------------------------

func open_even_odd_bet() -> void:
	if _even_odd_overlay != null and is_instance_valid(_even_odd_overlay):
		_even_odd_overlay.queue_free()
	var gold_before: int = GameManager.gold
	_even_odd_overlay = _EvenOddBetScene.instantiate()
	_host.add_child(_even_odd_overlay)
	_even_odd_overlay.connect("resolved", Callable(self, "_on_even_odd_bet_resolved").bind(gold_before))
	_even_odd_overlay.call("open")


func _on_even_odd_bet_resolved(gold_before: int) -> void:
	if _even_odd_overlay != null and is_instance_valid(_even_odd_overlay):
		_even_odd_overlay.queue_free()
		_even_odd_overlay = null
	if GameManager.gold < gold_before:
		GameManager.track_shop_spend(gold_before - GameManager.gold)
		eo_used = true
	overlay_resolved.emit()
