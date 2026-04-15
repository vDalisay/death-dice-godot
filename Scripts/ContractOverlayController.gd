class_name ContractOverlayController
extends Node
## Renders the active loop-contract sidebar overlay.  Pure presentation —
## reads contract data from GameManager and formats it for display.

const _UITheme := preload("res://Scripts/UITheme.gd")
const CONTRACT_OVERLAY_WIDTH: float = 420.0
const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")

# ── Node references (injected via setup) ──────────────────────────────────
var _overlay: PanelContainer
var _title_label: Label
var _check_label: Label
var _text_label: Label

## Optional reference to ContractProgressService for formatting.
var _progress_service: RefCounted = null

## Reference to _roll_content for visibility checks.
var _roll_content: Control = null


func setup(
	overlay: PanelContainer,
	title_label: Label,
	check_label: Label,
	text_label: Label,
	progress_service: RefCounted,
	roll_content: Control,
) -> void:
	_overlay = overlay
	_title_label = title_label
	_check_label = check_label
	_text_label = text_label
	_progress_service = progress_service
	_roll_content = roll_content
	_apply_theme()


## Refresh display from GameManager contract state.
func refresh() -> void:
	if _overlay == null:
		return
	if GameManager.active_loop_contract_id.is_empty() or (_roll_content != null and not _roll_content.visible):
		_overlay.visible = false
		return
	var contract: Variant = LoopContractCatalogScript.get_by_id(GameManager.active_loop_contract_id)
	if contract == null:
		_overlay.visible = false
		return
	_overlay.visible = true
	var completed: bool = bool(GameManager.active_loop_contract_progress.get("completed", false))
	_check_label.text = _UITheme.GLYPH_CHECK if completed else "[ ]"
	_check_label.modulate = _UITheme.SUCCESS_GREEN if completed else _UITheme.MUTED_TEXT
	var progress_text: String = ""
	if _progress_service != null:
		progress_text = _progress_service.format_progress_text(
			GameManager.active_loop_contract_id,
			GameManager.active_loop_contract_progress
		)
	if progress_text.is_empty():
		_text_label.text = contract.description
	else:
		_text_label.text = "%s\n%s" % [contract.description, progress_text]
	_text_label.reset_size()


# ── Private ───────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _overlay == null:
		return
	_overlay.custom_minimum_size = Vector2(CONTRACT_OVERLAY_WIDTH, 0.0)
	_overlay.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("inspector", _UITheme.CORNER_RADIUS_CARD, 1)
	)
	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_ACCENT_TEXT)
	_check_label.add_theme_font_override("font", _UITheme.font_display())
	_check_label.add_theme_font_size_override("font_size", 28)
	_check_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_text_label.add_theme_font_override("font", _UITheme.font_mono())
	_text_label.add_theme_font_size_override("font_size", 28)
	_text_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_BODY_TEXT)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.clip_text = false
