class_name ShopPanel
extends PanelContainer
## Between-stage shop. The player spends gold to buy dice or upgrade faces.
## Redesigned as a modal card shop while preserving existing economy logic.

signal shop_closed()

const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")

const ITEM_FONT_SIZE: int = 18
const REFRESH_COST: int = 5
const MODAL_INTRO_DURATION: float = 0.22
const CARD_REVEAL_STAGGER: float = 0.06
const CARD_REVEAL_DURATION: float = 0.2
const AFFORDABLE_CARD_ALPHA: float = 1.0
const BLOCKED_CARD_ALPHA: float = 0.58
const PURCHASE_FLASH_DURATION: float = 0.18
const MODAL_HEIGHT_RATIO: float = 0.9
const MODAL_MIN_HEIGHT: float = 560.0
const MODAL_MIN_HEIGHT_FLOOR: float = 360.0

const DICE_SLOTS: int = 4
const MODIFIER_SLOTS: int = 2
const DOUBLE_DOWN_MIN_GOLD: int = 10
const CHASER_MIN_LOOP: int = 2
const CHASER_MIN_LUCK: int = 2

var _DoubleDownScene: PackedScene = preload("res://Scenes/DoubleDownOverlay.tscn")
var _ShopItemCardScene: PackedScene = preload("res://Scenes/ShopItemCard.tscn")
const INSURANCE_BET_MIN_GOLD: int = 10
const HEAT_BET_MIN_GOLD: int = 15
const EVEN_ODD_BET_MIN_GOLD: int = 5

var _InsuranceBetScene: PackedScene = preload("res://Scenes/InsuranceBetOverlay.tscn")
var _HeatBetScene: PackedScene = preload("res://Scenes/HeatBetOverlay.tscn")
var _EvenOddBetScene: PackedScene = preload("res://Scenes/EvenOddBetOverlay.tscn")

@onready var _backdrop: ColorRect = $Backdrop
@onready var _modal: PanelContainer = $CenterContainer/Modal
@onready var _gold_badge: PanelContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/GoldBadge
@onready var _title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var _gold_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/HeaderRow/GoldBadge/GoldLabel
@onready var _main_content_scroll: ScrollContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll
@onready var _offer_summary_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/OfferSummaryLabel
@onready var _dice_section: VBoxContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/DiceSection
@onready var _dice_section_header: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/DiceSection/DiceSectionHeader
@onready var _dice_grid: GridContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/DiceSection/DiceGrid
@onready var _modifiers_section: VBoxContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/ModifiersSection
@onready var _modifiers_section_header: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/ModifiersSection/ModifiersSectionHeader
@onready var _modifiers_grid: GridContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/ModifiersSection/ModifiersGrid
@onready var _bets_section: VBoxContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/BetsSection
@onready var _bets_section_header: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/BetsSection/BetsSectionHeader
@onready var _bets_grid: GridContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/OfferColumn/BetsSection/BetsGrid
@onready var _details_panel: PanelContainer = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel
@onready var _details_eyebrow_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsEyebrowLabel
@onready var _details_title_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsTitleLabel
@onready var _details_keyword_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsKeywordLabel
@onready var _details_description_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsDescriptionLabel
@onready var _details_state_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/MainContentScroll/MainContent/DetailsPanel/MarginContainer/DetailsContent/DetailsStateLabel
@onready var _pool_label: Label = $CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/PoolLabel
@onready var _refresh_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/RefreshButton
@onready var _continue_button: Button = $CenterContainer/Modal/MarginContainer/VBoxContainer/FooterRow/ContinueButton

var _dice_items: Array[ShopItemData] = []
var _modifier_items: Array[ShopItemData] = []
var _bet_items: Array[ShopItemData] = []
var _all_items: Array[ShopItemData] = []
var _buy_buttons: Array[Button] = []
var _price_labels: Array[Label] = []
var _card_panels: Array[PanelContainer] = []
var _selected_item: ShopItemData = null
var _selected_card_index: int = -1
var _double_down_overlay: DoubleDownOverlay = null
var _dd_used_this_shop: bool = false
var _insurance_overlay: Node = null
var _heat_overlay: Node = null
var _even_odd_overlay: Node = null
var _ib_used_this_shop: bool = false
var _hb_used_this_shop: bool = false
var _eo_used_this_shop: bool = false
var _transition_tween: Tween = null
var _is_closing: bool = false
var _current_stage_cleared: int = 0
var _current_is_loop_complete: bool = false


func _exit_tree() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.custom_step(99.0)
		_transition_tween = null


func _ready() -> void:
	_apply_theme_styling()
	_continue_button.pressed.connect(_on_continue_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	GameManager.gold_changed.connect(_on_gold_changed)
	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_apply_responsive_layout()
	_refresh_localized_labels()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()


# ---------------------------------------------------------------------------
# Public API — called by RollPhase
# ---------------------------------------------------------------------------

func open(stage_just_cleared: int, is_loop_complete: bool = false) -> void:
	GameManager.on_shop_entered()
	_current_stage_cleared = stage_just_cleared
	_current_is_loop_complete = is_loop_complete
	_continue_button.disabled = false
	_dd_used_this_shop = false
	_ib_used_this_shop = false
	_hb_used_this_shop = false
	_eo_used_this_shop = false
	_apply_header_text()
	_generate_items()
	_refresh_display()
	_main_content_scroll.scroll_vertical = 0
	visible = true
	_is_closing = false
	call_deferred("_play_open_intro")


func open_from_resume(snapshot: Dictionary) -> void:
	_continue_button.disabled = false
	_dd_used_this_shop = bool(snapshot.get("dd_used_this_shop", false))
	_ib_used_this_shop = bool(snapshot.get("ib_used_this_shop", false))
	_hb_used_this_shop = bool(snapshot.get("hb_used_this_shop", false))
	_eo_used_this_shop = bool(snapshot.get("eo_used_this_shop", false))
	_current_stage_cleared = int(snapshot.get("stage_just_cleared", GameManager.current_stage))
	_current_is_loop_complete = bool(snapshot.get("is_loop_complete", false))
	_dice_items = _deserialize_item_array(snapshot.get("dice_items", []) as Array)
	_modifier_items = _deserialize_item_array(snapshot.get("modifier_items", []) as Array)
	_build_item_cards()
	_apply_header_text()
	_refresh_display()
	var selected_index: int = int(snapshot.get("selected_card_index", -1))
	if selected_index >= 0 and selected_index < _all_items.size():
		_select_item(selected_index)
	_main_content_scroll.scroll_vertical = 0
	visible = true
	_is_closing = false
	call_deferred("_play_open_intro")


func build_resume_snapshot() -> Dictionary:
	return {
		"stage_just_cleared": _current_stage_cleared,
		"is_loop_complete": _current_is_loop_complete,
		"dd_used_this_shop": _dd_used_this_shop,
		"ib_used_this_shop": _ib_used_this_shop,
		"hb_used_this_shop": _hb_used_this_shop,
		"eo_used_this_shop": _eo_used_this_shop,
		"selected_card_index": _selected_card_index,
		"dice_items": _serialize_item_array(_dice_items),
		"modifier_items": _serialize_item_array(_modifier_items),
	}


# ---------------------------------------------------------------------------
# Visual styling
# ---------------------------------------------------------------------------

func _apply_theme_styling() -> void:
	# Root should be transparent while backdrop + modal do the visual work.
	add_theme_stylebox_override("panel", _UITheme.make_panel_stylebox(Color(0, 0, 0, 0), 0))
	_backdrop.color = Color(_UITheme.STAGE_FAMILY_BACKDROP_COLOR, _UITheme.STAGE_FAMILY_BACKDROP_ALPHA)

	_modal.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("board", _UITheme.CORNER_RADIUS_MODAL, 2)
	)
	_gold_badge.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, _UITheme.STAGE_MAP_GLOW_REROUTE, 2)
	)

	_title_label.add_theme_font_override("font", _UITheme.font_display())
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)

	_gold_label.add_theme_font_override("font", _UITheme.font_stats())
	_gold_label.add_theme_font_size_override("font_size", 24)
	_gold_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	_offer_summary_label.add_theme_font_override("font", _UITheme.font_body())
	_offer_summary_label.add_theme_font_size_override("font_size", 14)
	_offer_summary_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_CONTEXT_COLOR)

	for header: Label in [_dice_section_header, _modifiers_section_header, _bets_section_header]:
		header.add_theme_font_override("font", _UITheme.font_mono())
		header.add_theme_font_size_override("font_size", 15)
		header.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_ACCENT_TEXT)

	_details_panel.add_theme_stylebox_override(
		"panel",
		_UITheme.make_stage_family_panel_style("inspector", _UITheme.CORNER_RADIUS_CARD, 1)
	)
	_details_eyebrow_label.add_theme_font_override("font", _UITheme.font_display())
	_details_eyebrow_label.add_theme_font_size_override("font_size", 12)
	_details_eyebrow_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_ACCENT_TEXT)
	_details_title_label.add_theme_font_override("font", _UITheme.font_display())
	_details_title_label.add_theme_font_size_override("font_size", 14)
	_details_title_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_TITLE_COLOR)
	_details_keyword_label.add_theme_font_override("font", _UITheme.font_mono())
	_details_keyword_label.add_theme_font_size_override("font_size", 18)
	_details_keyword_label.add_theme_color_override("font_color", _UITheme.STAGE_MAP_GLOW_CURRENT_ROW)
	_details_description_label.add_theme_font_override("font", _UITheme.font_body())
	_details_description_label.add_theme_font_size_override("font_size", 14)
	_details_description_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_BODY_TEXT)
	_details_state_label.add_theme_font_override("font", _UITheme.font_body())
	_details_state_label.add_theme_font_size_override("font_size", 13)
	_details_state_label.add_theme_color_override("font_color", _UITheme.STAGE_FAMILY_MUTED_TEXT)

	_pool_label.add_theme_font_override("font", _UITheme.font_body())
	_pool_label.add_theme_font_size_override("font_size", 18)
	_pool_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	_refresh_button.text = tr("SHOP_REFRESH_FMT").format({
		"gold": _UITheme.GLYPH_GOLD,
		"cost": REFRESH_COST,
	})
	_refresh_button.add_theme_font_override("font", _UITheme.font_display())
	_refresh_button.add_theme_font_size_override("font_size", 12)
	_continue_button.add_theme_font_override("font", _UITheme.font_display())
	_continue_button.add_theme_font_size_override("font_size", 12)


func _refresh_localized_labels() -> void:
	_details_eyebrow_label.text = tr("SHOP_DETAILS_LABEL")
	_refresh_button.text = tr("SHOP_REFRESH_FMT").format({
		"gold": _UITheme.GLYPH_GOLD,
		"cost": REFRESH_COST,
	})
	_apply_header_text()
	if visible:
		_refresh_display()


func _apply_header_text() -> void:
	if _current_is_loop_complete:
		_title_label.text = tr("SHOP_LOOP_COMPLETE_FMT").format({"value": GameManager.current_loop - 1})
		_continue_button.text = tr("SHOP_START_LOOP_FMT").format({"value": GameManager.current_loop})
		return
	_title_label.text = tr("SHOP_STAGE_COMPLETE_FMT").format({"value": _current_stage_cleared})
	_continue_button.text = tr("SHOP_CONTINUE_STAGE_FMT").format({"value": _current_stage_cleared + 1})


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_localized_labels()


func _apply_responsive_layout() -> void:
	if _modal == null:
		return
	var viewport_height: float = get_viewport_rect().size.y
	var target_height: float = maxf(MODAL_MIN_HEIGHT, viewport_height * MODAL_HEIGHT_RATIO)
	target_height = minf(target_height, viewport_height - 24.0)
	if target_height < MODAL_MIN_HEIGHT_FLOOR:
		target_height = maxf(MODAL_MIN_HEIGHT_FLOOR, viewport_height - 12.0)
	_modal.custom_minimum_size = Vector2(_modal.custom_minimum_size.x, target_height)
	var compact_layout: bool = viewport_height < 860.0
	var offer_columns: int = 3 if compact_layout else 4
	_dice_grid.columns = offer_columns
	_modifiers_grid.columns = offer_columns
	_bets_grid.columns = offer_columns
	_details_panel.custom_minimum_size.x = 280.0 if compact_layout else 320.0


# ---------------------------------------------------------------------------
# Item generation
# ---------------------------------------------------------------------------

func _generate_items() -> void:
	_dice_items.clear()
	_modifier_items.clear()
	_bet_items.clear()

	var dice_pool: Array[ShopItemData] = _build_dice_offer_pool()

	GameManager.rng_shuffle_in_place("shop", dice_pool)
	var pick_count: int = mini(DICE_SLOTS, dice_pool.size())
	for i: int in pick_count:
		_dice_items.append(dice_pool[i])

	if not GameManager.dice_pool.is_empty():
		_dice_items.append(ShopItemData.make_upgrade_die())
	if _any_die_has_cursed_stop():
		_dice_items.append(ShopItemData.make_cleanse_curse())
	if GameManager.gold >= DOUBLE_DOWN_MIN_GOLD and not _dd_used_this_shop:
		_bet_items.append(ShopItemData.make_double_down())
	if GameManager.gold >= INSURANCE_BET_MIN_GOLD and not _ib_used_this_shop:
		_bet_items.append(ShopItemData.make_insurance_bet())
	if GameManager.gold >= HEAT_BET_MIN_GOLD and not _hb_used_this_shop:
		_bet_items.append(ShopItemData.make_heat_bet())
	if GameManager.gold >= EVEN_ODD_BET_MIN_GOLD and not _eo_used_this_shop:
		_bet_items.append(ShopItemData.make_even_odd_bet())

	if GameManager.can_add_modifier():
		var mod_factories: Array[Callable] = RunModifier.all_factories()
		var available_mods: Array[Callable] = []
		for factory: Callable in mod_factories:
			var sample: RunModifier = factory.call() as RunModifier
			if not GameManager.has_modifier(sample.modifier_type):
				available_mods.append(factory)
		GameManager.rng_shuffle_in_place("shop", available_mods)
		var mod_count: int = mini(MODIFIER_SLOTS, available_mods.size())
		for i: int in mod_count:
			var mod: RunModifier = available_mods[i].call() as RunModifier
			_modifier_items.append(ShopItemData.make_buy_modifier(mod))

	_build_item_cards()


func _build_dice_offer_pool() -> Array[ShopItemData]:
	var dice_pool: Array[ShopItemData] = [
		ShopItemData.make_buy_simple_die(),
		ShopItemData.make_buy_standard_die(),
		ShopItemData.make_buy_blank_canvas_die(),
		ShopItemData.make_buy_lucky_die(),
		ShopItemData.make_buy_heart_die(),
		ShopItemData.make_buy_pink_die(),
		ShopItemData.make_buy_fortune_die(),
	]
	if GameManager.current_loop >= CHASER_MIN_LOOP or GameManager.prestige_shop_tier_active:
		dice_pool.append(ShopItemData.make_buy_runner_die())
		dice_pool.append(ShopItemData.make_buy_golden_die())
		dice_pool.append(ShopItemData.make_buy_insurance_die())
		dice_pool.append(ShopItemData.make_buy_heavy_die())
		dice_pool.append(ShopItemData.make_buy_explosive_die())
	if _can_offer_spark_chaser_die():
		dice_pool.append(ShopItemData.make_buy_spark_chaser_die())
	return dice_pool


func _can_offer_spark_chaser_die() -> bool:
	var loop_gate: bool = GameManager.current_loop >= CHASER_MIN_LOOP or GameManager.prestige_shop_tier_active
	return loop_gate and GameManager.luck >= CHASER_MIN_LUCK


func _build_item_cards() -> void:
	_clear_container(_dice_grid)
	_clear_container(_modifiers_grid)
	_clear_container(_bets_grid)
	_all_items.clear()
	_buy_buttons.clear()
	_price_labels.clear()
	_card_panels.clear()
	_selected_item = null
	_selected_card_index = -1
	_dice_section.visible = not _dice_items.is_empty()
	_modifiers_section.visible = not _modifier_items.is_empty()
	_bets_section.visible = not _bet_items.is_empty()

	for item: ShopItemData in _dice_items:
		var card: PanelContainer = _make_item_card(item)
		_dice_grid.add_child(card)
		_all_items.append(item)

	for item: ShopItemData in _modifier_items:
		var card: PanelContainer = _make_item_card(item)
		_modifiers_grid.add_child(card)
		_all_items.append(item)

	for item: ShopItemData in _bet_items:
		var card: PanelContainer = _make_item_card(item)
		_bets_grid.add_child(card)
		_all_items.append(item)

	if not _all_items.is_empty():
		_select_item(0)
	else:
		_clear_details()


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _make_item_card(item: ShopItemData) -> PanelContainer:
	var card: PanelContainer = _ShopItemCardScene.instantiate() as PanelContainer
	var accent_bar: ColorRect = card.get_node("VBoxContainer/AccentBar") as ColorRect
	var name_label: Label = card.get_node("VBoxContainer/MarginContainer/Content/NameLabel") as Label
	var keyword_label: Label = card.get_node("VBoxContainer/MarginContainer/Content/KeywordLabel") as Label
	var price_label: Label = card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/PriceLabel") as Label
	var buy_button: Button = card.get_node("VBoxContainer/MarginContainer/Content/FooterRow/BuyButton") as Button

	var accent_color: Color = _item_accent_color(item)
	accent_bar.color = accent_color
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, accent_color, 2)
	)

	name_label.text = item.item_name
	name_label.add_theme_font_override("font", _UITheme.font_display())
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", _UITheme.BRIGHT_TEXT)

	keyword_label.text = _item_keyword_summary(item)
	keyword_label.add_theme_font_override("font", _UITheme.font_mono())
	keyword_label.add_theme_font_size_override("font_size", 17)
	keyword_label.add_theme_color_override("font_color", accent_color)

	if item.item_type == ShopItemData.ItemType.DOUBLE_DOWN:
		buy_button.text = tr("SHOP_PLAY_ACTION")
	elif item.item_type == ShopItemData.ItemType.INSURANCE_BET or \
		item.item_type == ShopItemData.ItemType.HEAT_BET or \
		item.item_type == ShopItemData.ItemType.EVEN_ODD_BET:
		buy_button.text = tr("SHOP_PLAY_ACTION")
	else:
		buy_button.text = tr("SHOP_BUY_ACTION")
	buy_button.custom_minimum_size = Vector2(120, 44)
	buy_button.add_theme_font_override("font", _UITheme.font_display())
	buy_button.add_theme_font_size_override("font_size", 11)
	buy_button.pressed.connect(_on_buy_pressed.bind(item))

	if item.cost > 0:
		price_label.text = "%s %d" % [_UITheme.GLYPH_GOLD, item.cost]
	else:
		price_label.text = tr("SHOP_FREE")
	price_label.add_theme_font_override("font", _UITheme.font_stats())
	price_label.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	price_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)

	var item_index: int = _card_panels.size()
	card.mouse_entered.connect(_select_item.bind(item_index))
	buy_button.focus_entered.connect(_select_item.bind(item_index))

	_buy_buttons.append(buy_button)
	_price_labels.append(price_label)
	_card_panels.append(card)
	return card


func _item_description(item: ShopItemData) -> String:
	if item.item_type == ShopItemData.ItemType.UPGRADE_DIE:
		return _get_upgrade_preview()
	if item.item_type == ShopItemData.ItemType.DOUBLE_DOWN:
		return _dd_desc_text()
	return item.description


func _item_keyword_summary(item: ShopItemData) -> String:
	match item.item_type:
		ShopItemData.ItemType.BUY_MODIFIER:
			return tr("SHOP_KEYWORD_MOD_PASSIVE")
		ShopItemData.ItemType.UPGRADE_DIE:
			return tr("SHOP_KEYWORD_FORGE_UPGRADE")
		ShopItemData.ItemType.CLEANSE_CURSE:
			return tr("SHOP_KEYWORD_CLEANSE_CURSE")
		ShopItemData.ItemType.DOUBLE_DOWN, ShopItemData.ItemType.INSURANCE_BET, ShopItemData.ItemType.HEAT_BET, ShopItemData.ItemType.EVEN_ODD_BET:
			return tr("SHOP_KEYWORD_BET_PLAY")
		_:
			return tr("SHOP_KEYWORD_DIE_BUY")


func _item_state_text(item: ShopItemData) -> String:
	var notes: Array[String] = []
	if GameManager.gold < item.cost:
		notes.append(tr("SHOP_NEED_GOLD_FMT").format({
			"gold": _UITheme.GLYPH_GOLD,
			"value": item.cost - GameManager.gold,
		}))
	if item.item_type == ShopItemData.ItemType.BUY_MODIFIER:
		if not GameManager.can_add_modifier():
			notes.append(tr("SHOP_MODIFIER_RACK_FULL"))
		elif item.modifier != null and GameManager.has_modifier(item.modifier.modifier_type):
			notes.append(tr("SHOP_ALREADY_OWNED"))
	if item.item_type == ShopItemData.ItemType.DOUBLE_DOWN:
		notes.append(tr("SHOP_DOUBLE_DOWN_NOTE"))
	if item.item_type == ShopItemData.ItemType.INSURANCE_BET:
		notes.append(tr("SHOP_INSURANCE_NOTE"))
	if item.item_type == ShopItemData.ItemType.HEAT_BET:
		notes.append(tr("SHOP_HEAT_NOTE"))
	if item.item_type == ShopItemData.ItemType.EVEN_ODD_BET:
		notes.append(tr("SHOP_PARITY_NOTE"))
	if notes.is_empty():
		return tr("SHOP_READY_TO_PURCHASE")
	return " ".join(notes)


func _select_item(index: int) -> void:
	if index < 0 or index >= _all_items.size():
		return
	_selected_item = _all_items[index]
	_selected_card_index = index
	_refresh_selected_card_state()
	_refresh_details()


func _refresh_selected_card_state() -> void:
	for i: int in _card_panels.size():
		var item: ShopItemData = _all_items[i]
		var blocked: bool = _buy_buttons[i].disabled
		var border_color: Color = _item_accent_color(item) if i == _selected_card_index else (_item_accent_color(item) if not blocked else _UITheme.MUTED_TEXT)
		var border_width: int = 3 if i == _selected_card_index else 2
		_card_panels[i].add_theme_stylebox_override(
			"panel",
			_UITheme.make_panel_stylebox(_UITheme.ELEVATED, _UITheme.CORNER_RADIUS_CARD, border_color, border_width)
		)


func _refresh_details() -> void:
	if _selected_item == null:
		_clear_details()
		return
	_details_title_label.text = _selected_item.item_name
	_details_keyword_label.text = _item_keyword_summary(_selected_item)
	_details_description_label.text = _item_description(_selected_item)
	_details_state_label.text = _item_state_text(_selected_item)


func _clear_details() -> void:
	_details_title_label.text = tr("SHOP_SELECT_OFFER")
	_details_keyword_label.text = ""
	_details_description_label.text = ""
	_details_state_label.text = ""


func _item_accent_color(item: ShopItemData) -> Color:
	match item.item_type:
		ShopItemData.ItemType.BUY_MODIFIER:
			return _UITheme.NEON_PURPLE
		ShopItemData.ItemType.DOUBLE_DOWN:
			return _UITheme.EXPLOSION_ORANGE
		ShopItemData.ItemType.INSURANCE_BET:
			return _UITheme.EXPLOSION_ORANGE
		ShopItemData.ItemType.HEAT_BET:
			return _UITheme.EXPLOSION_ORANGE
		ShopItemData.ItemType.EVEN_ODD_BET:
			return _UITheme.EXPLOSION_ORANGE
		ShopItemData.ItemType.UPGRADE_DIE:
			return _UITheme.ACTION_CYAN
		ShopItemData.ItemType.CLEANSE_CURSE:
			return _UITheme.DANGER_RED
	return _UITheme.SCORE_GOLD


# ---------------------------------------------------------------------------
# Purchase handling
# ---------------------------------------------------------------------------

func _on_buy_pressed(item: ShopItemData) -> void:
	var is_overlay_bet: bool = item.item_type == ShopItemData.ItemType.DOUBLE_DOWN \
		or item.item_type == ShopItemData.ItemType.INSURANCE_BET \
		or item.item_type == ShopItemData.ItemType.HEAT_BET \
		or item.item_type == ShopItemData.ItemType.EVEN_ODD_BET
	if not is_overlay_bet:
		if not GameManager.spend_gold(item.cost):
			return
	if item.cost > 0 and not is_overlay_bet:
		GameManager.track_shop_spend(item.cost)
	SFXManager.play_shop_purchase()
	_play_purchase_feedback(_item_accent_color(item))

	match item.item_type:
		ShopItemData.ItemType.BUY_STANDARD_DIE:
			GameManager.add_dice(DiceData.make_standard_d6())
		ShopItemData.ItemType.BUY_LUCKY_DIE:
			GameManager.add_dice(DiceData.make_lucky_d6())
		ShopItemData.ItemType.BUY_GAMBLER_DIE:
			GameManager.add_dice(DiceData.make_gambler_d6())
		ShopItemData.ItemType.BUY_GOLDEN_DIE:
			GameManager.add_dice(DiceData.make_golden_d6())
		ShopItemData.ItemType.BUY_INSURANCE_DIE:
			GameManager.add_dice(DiceData.make_insurance_d6())
		ShopItemData.ItemType.BUY_HEAVY_DIE:
			GameManager.add_dice(DiceData.make_heavy_d6())
		ShopItemData.ItemType.BUY_EXPLOSIVE_DIE:
			GameManager.add_dice(DiceData.make_explosive_d6())
		ShopItemData.ItemType.BUY_BLANK_CANVAS_DIE:
			GameManager.add_dice(DiceData.make_blank_canvas_d6())
		ShopItemData.ItemType.BUY_PINK_DIE:
			GameManager.add_dice(DiceData.make_pink_d6())
		ShopItemData.ItemType.BUY_SIMPLE_DIE:
			GameManager.add_dice(DiceData.make_simple_d6())
		ShopItemData.ItemType.BUY_FORTUNE_DIE:
			GameManager.add_dice(DiceData.make_fortune_d6())
		ShopItemData.ItemType.BUY_HEART_DIE:
			GameManager.add_dice(DiceData.make_heart_d6())
		ShopItemData.ItemType.BUY_SPARK_CHASER_DIE:
			GameManager.add_dice(DiceData.make_reroll_chaser_d6())
		ShopItemData.ItemType.UPGRADE_DIE:
			_upgrade_random_die()
		ShopItemData.ItemType.BUY_MODIFIER:
			if item.modifier != null:
				GameManager.add_modifier(item.modifier)
		ShopItemData.ItemType.CLEANSE_CURSE:
			_cleanse_random_cursed_die()
		ShopItemData.ItemType.DOUBLE_DOWN:
			_open_double_down()
			return
		ShopItemData.ItemType.INSURANCE_BET:
			_open_insurance_bet()
			return
		ShopItemData.ItemType.HEAT_BET:
			_open_heat_bet()
			return
		ShopItemData.ItemType.EVEN_ODD_BET:
			_open_even_odd_bet()
			return

	_refresh_display()


func _upgrade_random_die() -> void:
	if GameManager.dice_pool.is_empty():
		return
	var die_index: int = GameManager.rng_pick_index("shop", GameManager.dice_pool.size())
	if die_index < 0:
		return
	var die: DiceData = GameManager.dice_pool[die_index]
	die.upgrade_weakest_face()


# ---------------------------------------------------------------------------
# UI updates
# ---------------------------------------------------------------------------

func _on_continue_pressed() -> void:
	if _is_closing:
		return
	_is_closing = true
	_continue_button.disabled = true
	_refresh_button.disabled = true
	GameManager.on_shop_exited()
	await _play_close_transition()
	visible = false
	shop_closed.emit()


func _on_gold_changed(_new_gold: int) -> void:
	if visible:
		_refresh_display()


func _refresh_display() -> void:
	_gold_label.text = "%s %d" % [_UITheme.GLYPH_GOLD, GameManager.gold]
	_offer_summary_label.text = tr("SHOP_OFFER_HINT")
	_dice_section_header.text = tr("SHOP_AVAILABLE_DICE_FMT").format({"value": _dice_items.size()})
	_modifiers_section_header.text = tr("SHOP_PASSIVE_UPGRADES_FMT").format({"value": _modifier_items.size()})
	_bets_section_header.text = tr("SHOP_SIDE_BETS_FMT").format({"value": _bet_items.size()})
	var mod_text: String = ""
	if not GameManager.active_modifiers.is_empty():
		var names: Array[String] = []
		for m: RunModifier in GameManager.active_modifiers:
			names.append(m.modifier_name)
		mod_text = tr("SHOP_POOL_MODS_FMT").format({"mods": ", ".join(names)})
	_pool_label.text = tr("SHOP_POOL_FMT").format({
		"dice_count": GameManager.dice_pool.size(),
		"mods_suffix": mod_text,
	})
	_refresh_buy_buttons()
	_refresh_details()


func _refresh_buy_buttons() -> void:
	for i: int in _buy_buttons.size():
		var item: ShopItemData = _all_items[i]
		var too_expensive: bool = GameManager.gold < item.cost
		var mod_full: bool = item.item_type == ShopItemData.ItemType.BUY_MODIFIER and not GameManager.can_add_modifier()
		var already_owned: bool = item.item_type == ShopItemData.ItemType.BUY_MODIFIER and item.modifier != null and GameManager.has_modifier(item.modifier.modifier_type)
		var blocked: bool = too_expensive or mod_full or already_owned
		_buy_buttons[i].disabled = blocked
		_price_labels[i].add_theme_color_override("font_color", _UITheme.DANGER_RED if too_expensive else _UITheme.SCORE_GOLD)
		_apply_card_affordance(i, blocked, _item_accent_color(item))

	_refresh_button.disabled = GameManager.gold < REFRESH_COST


func _on_refresh_pressed() -> void:
	if not GameManager.spend_gold(REFRESH_COST):
		return
	SFXManager.play_shop_refresh()
	_generate_items()
	_refresh_display()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _get_upgrade_preview() -> String:
	if GameManager.dice_pool.is_empty():
		return tr("SHOP_NO_DICE_TO_UPGRADE")
	var previews: Array[String] = []
	for die: DiceData in GameManager.dice_pool:
		var worst_index: int = -1
		var worst_power: int = 999
		for i: int in die.faces.size():
			var power: int = die._face_power(die.faces[i])
			if power < worst_power:
				if die.faces[i].type == DiceFaceData.FaceType.STOP and die._count_stop_faces() <= 1:
					continue
				worst_power = power
				worst_index = i
		if worst_index >= 0:
			var face_text: String = die.faces[worst_index].get_display_text()
			var preview: String = "%s [%s]" % [die.dice_name, face_text]
			if preview not in previews:
				previews.append(preview)
	if previews.is_empty():
		return tr("SHOP_NO_UPGRADEABLE_FACES")
	return tr("SHOP_UPGRADE_PREVIEW_FMT").format({"candidates": ", ".join(previews)})


func _any_die_has_cursed_stop() -> bool:
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.CURSED_STOP:
				return true
	return false


func _cleanse_random_cursed_die() -> void:
	var cursed_dice: Array[DiceData] = []
	for die: DiceData in GameManager.dice_pool:
		for face: DiceFaceData in die.faces:
			if face.type == DiceFaceData.FaceType.CURSED_STOP:
				cursed_dice.append(die)
				break
	if cursed_dice.is_empty():
		return
	var die_index: int = GameManager.rng_pick_index("shop", cursed_dice.size())
	if die_index < 0:
		return
	var die: DiceData = cursed_dice[die_index]
	for face: DiceFaceData in die.faces:
		if face.type == DiceFaceData.FaceType.CURSED_STOP:
			face.type = DiceFaceData.FaceType.STOP
			break


func _dd_desc_text() -> String:
	return tr("SHOP_DD_DESC_FMT").format({
		"gold": _UITheme.GLYPH_GOLD,
		"value": GameManager.gold,
		"reward": GameManager.gold * 2,
	})


func _open_double_down() -> void:
	if _double_down_overlay != null and is_instance_valid(_double_down_overlay):
		_double_down_overlay.queue_free()
	_double_down_overlay = _DoubleDownScene.instantiate() as DoubleDownOverlay
	add_child(_double_down_overlay)
	_double_down_overlay.resolved.connect(_on_double_down_resolved)
	_double_down_overlay.open(GameManager.gold)


func _on_double_down_resolved() -> void:
	_dd_used_this_shop = true
	if _double_down_overlay != null and is_instance_valid(_double_down_overlay):
		_double_down_overlay.queue_free()
		_double_down_overlay = null
	_generate_items()
	_refresh_display()


func _play_open_intro() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_enter(self, _modal, MODAL_INTRO_DURATION, _backdrop)
	for index: int in _card_panels.size():
		var card: PanelContainer = _card_panels[index]
		card.modulate.a = 0.0
		card.scale = Vector2(0.96, 0.96)
		_transition_tween.tween_callback(Callable(self, "_reveal_card_by_index").bind(index)).set_delay(CARD_REVEAL_STAGGER * index)


func _reveal_card(card: PanelContainer) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(card, "modulate:a", 1.0, CARD_REVEAL_DURATION)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, CARD_REVEAL_DURATION).set_ease(Tween.EASE_OUT)


func _reveal_card_by_index(index: int) -> void:
	if index < 0 or index >= _card_panels.size():
		return
	var card: PanelContainer = _card_panels[index]
	if not is_instance_valid(card):
		return
	_reveal_card(card)


func _apply_card_affordance(index: int, blocked: bool, accent_color: Color) -> void:
	if index < 0 or index >= _card_panels.size():
		return
	var card: PanelContainer = _card_panels[index]
	card.self_modulate = Color(1.0, 1.0, 1.0, AFFORDABLE_CARD_ALPHA) if not blocked else Color(0.82, 0.82, 0.82, BLOCKED_CARD_ALPHA)
	card.add_theme_stylebox_override(
		"panel",
		_UITheme.make_panel_stylebox(
			_UITheme.ELEVATED,
			_UITheme.CORNER_RADIUS_CARD,
			accent_color if not blocked else _UITheme.MUTED_TEXT,
			2
		)
	)
	if index == _selected_card_index:
		_refresh_selected_card_state()


func _play_purchase_feedback(accent_color: Color) -> void:
	var modal_tween: Tween = create_tween()
	modal_tween.tween_property(_modal, "modulate", Color(1.05, 1.05, 1.05, 1.0), PURCHASE_FLASH_DURATION * 0.5)
	modal_tween.tween_property(_modal, "modulate", Color.WHITE, PURCHASE_FLASH_DURATION * 0.5)
	var badge_tween: Tween = create_tween()
	badge_tween.tween_property(_gold_badge, "scale", Vector2(1.08, 1.08), PURCHASE_FLASH_DURATION * 0.45).set_ease(Tween.EASE_OUT)
	badge_tween.tween_property(_gold_badge, "scale", Vector2.ONE, PURCHASE_FLASH_DURATION * 0.55).set_ease(Tween.EASE_IN)
	_gold_label.add_theme_color_override("font_color", accent_color)
	get_tree().create_timer(PURCHASE_FLASH_DURATION).timeout.connect(_restore_gold_label_color, CONNECT_ONE_SHOT)


func _play_close_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = FlowTransitionScript.play_exit(self, _modal, 0.16, _backdrop)
	await _transition_tween.finished


func _restore_gold_label_color() -> void:
	if _gold_label != null and is_instance_valid(_gold_label):
		_gold_label.add_theme_color_override("font_color", _UITheme.SCORE_GOLD)


func _open_insurance_bet() -> void:
	if _insurance_overlay != null and is_instance_valid(_insurance_overlay):
		_insurance_overlay.queue_free()
	var gold_before: int = GameManager.gold
	_insurance_overlay = _InsuranceBetScene.instantiate()
	add_child(_insurance_overlay)
	_insurance_overlay.connect("resolved", Callable(self, "_on_insurance_bet_resolved").bind(gold_before))
	_insurance_overlay.call("open")


func _on_insurance_bet_resolved(gold_before: int) -> void:
	if _insurance_overlay != null and is_instance_valid(_insurance_overlay):
		_insurance_overlay.queue_free()
		_insurance_overlay = null
	if GameManager.gold < gold_before:
		GameManager.track_shop_spend(gold_before - GameManager.gold)
		_ib_used_this_shop = true
	_generate_items()
	_refresh_display()


func _open_heat_bet() -> void:
	if _heat_overlay != null and is_instance_valid(_heat_overlay):
		_heat_overlay.queue_free()
	var gold_before: int = GameManager.gold
	_heat_overlay = _HeatBetScene.instantiate()
	add_child(_heat_overlay)
	_heat_overlay.connect("resolved", Callable(self, "_on_heat_bet_resolved").bind(gold_before))
	_heat_overlay.call("open")


func _on_heat_bet_resolved(gold_before: int) -> void:
	if _heat_overlay != null and is_instance_valid(_heat_overlay):
		_heat_overlay.queue_free()
		_heat_overlay = null
	if GameManager.gold < gold_before:
		GameManager.track_shop_spend(gold_before - GameManager.gold)
		_hb_used_this_shop = true
	_generate_items()
	_refresh_display()


func _open_even_odd_bet() -> void:
	if _even_odd_overlay != null and is_instance_valid(_even_odd_overlay):
		_even_odd_overlay.queue_free()
	var gold_before: int = GameManager.gold
	_even_odd_overlay = _EvenOddBetScene.instantiate()
	add_child(_even_odd_overlay)
	_even_odd_overlay.connect("resolved", Callable(self, "_on_even_odd_bet_resolved").bind(gold_before))
	_even_odd_overlay.call("open")


func _on_even_odd_bet_resolved(gold_before: int) -> void:
	if _even_odd_overlay != null and is_instance_valid(_even_odd_overlay):
		_even_odd_overlay.queue_free()
		_even_odd_overlay = null
	if GameManager.gold < gold_before:
		GameManager.track_shop_spend(gold_before - GameManager.gold)
		_eo_used_this_shop = true
	_generate_items()
	_refresh_display()


func _serialize_item_array(items: Array[ShopItemData]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for item: ShopItemData in items:
		serialized.append(_serialize_item(item))
	return serialized


func _deserialize_item_array(items: Array) -> Array[ShopItemData]:
	var deserialized: Array[ShopItemData] = []
	for item_data: Variant in items:
		if not (item_data is Dictionary):
			continue
		var item: ShopItemData = _deserialize_item(item_data as Dictionary)
		if item != null:
			deserialized.append(item)
	return deserialized


func _serialize_item(item: ShopItemData) -> Dictionary:
	var modifier_type: int = -1
	if item.modifier != null:
		modifier_type = int(item.modifier.modifier_type)
	return {
		"item_type": int(item.item_type),
		"item_name": item.item_name,
		"description": item.description,
		"cost": item.cost,
		"modifier_type": modifier_type,
	}


func _deserialize_item(data: Dictionary) -> ShopItemData:
	var item_type: int = int(data.get("item_type", -1))
	if item_type < 0:
		return null
	var item: ShopItemData = _make_item_from_type(item_type)
	if item == null:
		return null
	item.item_name = str(data.get("item_name", item.item_name))
	item.description = str(data.get("description", item.description))
	item.cost = int(data.get("cost", item.cost))
	if item.item_type == ShopItemData.ItemType.BUY_MODIFIER:
		var mod_type: int = int(data.get("modifier_type", -1))
		item.modifier = _make_modifier_from_type(mod_type)
	return item


func _make_item_from_type(item_type: int) -> ShopItemData:
	match item_type:
		int(ShopItemData.ItemType.BUY_STANDARD_DIE):
			return ShopItemData.make_buy_standard_die()
		int(ShopItemData.ItemType.BUY_LUCKY_DIE):
			return ShopItemData.make_buy_lucky_die()
		int(ShopItemData.ItemType.BUY_GAMBLER_DIE):
			return ShopItemData.make_buy_runner_die()
		int(ShopItemData.ItemType.BUY_GOLDEN_DIE):
			return ShopItemData.make_buy_golden_die()
		int(ShopItemData.ItemType.BUY_INSURANCE_DIE):
			return ShopItemData.make_buy_insurance_die()
		int(ShopItemData.ItemType.BUY_HEAVY_DIE):
			return ShopItemData.make_buy_heavy_die()
		int(ShopItemData.ItemType.BUY_EXPLOSIVE_DIE):
			return ShopItemData.make_buy_explosive_die()
		int(ShopItemData.ItemType.BUY_BLANK_CANVAS_DIE):
			return ShopItemData.make_buy_blank_canvas_die()
		int(ShopItemData.ItemType.BUY_PINK_DIE):
			return ShopItemData.make_buy_pink_die()
		int(ShopItemData.ItemType.BUY_SIMPLE_DIE):
			return ShopItemData.make_buy_simple_die()
		int(ShopItemData.ItemType.UPGRADE_DIE):
			return ShopItemData.make_upgrade_die()
		int(ShopItemData.ItemType.BUY_MODIFIER):
			return ShopItemData.make_buy_modifier(RunModifier.make_gamblers_rush())
		int(ShopItemData.ItemType.CLEANSE_CURSE):
			return ShopItemData.make_cleanse_curse()
		int(ShopItemData.ItemType.DOUBLE_DOWN):
			return ShopItemData.make_double_down()
		int(ShopItemData.ItemType.BUY_FORTUNE_DIE):
			return ShopItemData.make_buy_fortune_die()
		int(ShopItemData.ItemType.BUY_HEART_DIE):
			return ShopItemData.make_buy_heart_die()
		int(ShopItemData.ItemType.INSURANCE_BET):
			return ShopItemData.make_insurance_bet()
		int(ShopItemData.ItemType.HEAT_BET):
			return ShopItemData.make_heat_bet()
		int(ShopItemData.ItemType.EVEN_ODD_BET):
			return ShopItemData.make_even_odd_bet()
		int(ShopItemData.ItemType.BUY_SPARK_CHASER_DIE):
			return ShopItemData.make_buy_spark_chaser_die()
	return null


func _make_modifier_from_type(modifier_type: int) -> RunModifier:
	match modifier_type:
		int(RunModifier.ModifierType.GAMBLERS_RUSH):
			return RunModifier.make_gamblers_rush()
		int(RunModifier.ModifierType.EXPLOSOPHILE):
			return RunModifier.make_explosophile()
		int(RunModifier.ModifierType.IRON_BANK):
			return RunModifier.make_iron_bank()
		int(RunModifier.ModifierType.GLASS_CANNON):
			return RunModifier.make_glass_cannon()
		int(RunModifier.ModifierType.SHIELD_WALL):
			return RunModifier.make_shield_wall()
		int(RunModifier.ModifierType.MISER):
			return RunModifier.make_miser()
		int(RunModifier.ModifierType.DOUBLE_DOWN):
			return RunModifier.make_double_down()
		int(RunModifier.ModifierType.SCAVENGER):
			return RunModifier.make_scavenger()
		int(RunModifier.ModifierType.RECYCLER):
			return RunModifier.make_recycler()
		int(RunModifier.ModifierType.LAST_STAND):
			return RunModifier.make_last_stand()
		int(RunModifier.ModifierType.CHAIN_LIGHTNING):
			return RunModifier.make_chain_lightning()
		int(RunModifier.ModifierType.HIGH_ROLLER):
			return RunModifier.make_high_roller()
		int(RunModifier.ModifierType.OVERCHARGE):
			return RunModifier.make_overcharge()
	return RunModifier.make_gamblers_rush()
