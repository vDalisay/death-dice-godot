class_name RollPhase
extends Control
## Turn state machine for the Cubitos-style dice rolling phase.
## Owns dice logic. Delegates visuals to DiceArena and HUD.

const BASE_BUST_THRESHOLD: int = 4
const AUTO_ADVANCE_DELAY: float = 0.75
const MAX_SCORE_ANIM_DURATION: float = 2.0
const HOT_STREAK_TIER_1: int = 3
const HOT_STREAK_TIER_2: int = 5
const HOT_STREAK_MULT_1: float = 1.1
const HOT_STREAK_MULT_2: float = 1.2
const JACKPOT_MIN_DICE: int = 5
const JACKPOT_GOLD_BONUS: float = 0.25
const POST_ROLL_EFFECT_LOCK_DURATION: float = 0.2
const BANK_CASCADE_STEP_DELAY: float = 0.22
const SHAKE_ROLL: float = 2.0
const SHAKE_STOP: float = 3.0
const SHAKE_CURSED_STOP: float = 5.0
const SHAKE_BUST: float = 8.0
const SHAKE_BIG_BANK: float = 4.0
const SHAKE_DETONATE: float = 4.0
const CHAIN_SHAKE_BASE: float = 2.0
const CHAIN_SHAKE_STEP: float = 0.5
const CHAIN_SHAKE_DURATION: float = 0.1
const EXPLODE_DISPLACEMENT_RADIUS: float = 118.0
const AFTERSHOCK_RADIUS_BONUS: float = 24.0
const CLUSTER_CHILD_OFFSET: float = 54.0
const CATEGORY_TIER_STEP_DELAY: float = 0.15
const SCORE_ANIM_SPEEDUP_THRESHOLD: int = 6
const SCORE_ANIM_SPEEDUP_PER_DIE: float = 0.06
const SCORE_ANIM_BASE_INTERVAL_FLOOR: float = 0.05
const HIGH_RISK_ODDS_THRESHOLD: float = 0.55
const NEAR_DEATH_GOLD_BONUS: int = 8
const META_LEDGER_EXP_REWARD: int = 2
const META_HIGH_RISK_EXP_REWARD: int = 1
const META_NEAR_DEATH_SHARD_REWARD: int = 1
## Surface transition durations kept for backward compatibility with tests.
const SURFACE_ENTER_DURATION: float = 0.14
const SURFACE_EXIT_DURATION: float = 0.12
const STAGE_VARIANT_STATUS_COLOR: Color = Color(0.55, 0.9, 1.0)
const RUN_OVER_STATUS_COLOR: Color = Color(0.9, 0.2, 0.2)

const BUTTON_HOVER_SCALE: float = 1.03
const BUTTON_PRESS_SCALE: float = 0.96
const BUTTON_TWEEN_DURATION: float = 0.08
const INTRO_CARD_SLOT_SHAKE_DURATION: float = 0.09
const INTRO_CARD_RULE_SLOT_SHAKE: float = 1.1
const INTRO_CARD_TARGET_SLOT_SHAKE: float = 1.6
const RESUME_SURFACE_TURN: String = "turn"
const RESUME_SURFACE_STAGE_MAP: String = "stage_map"
const RESUME_SURFACE_SHOP: String = "shop"
const RESUME_SURFACE_EVENT: String = "event"
const RESUME_SURFACE_FORGE: String = "forge"
const RESUME_SURFACE_REST: String = "rest"

enum TurnState { IDLE, ACTIVE, BUST, BANKED }
enum RollBustOutcome { SAFE, IMMUNE_SAVE, INSURANCE_SAVE, EVENT_SAVE, BUST }
enum ContractContinuation { START_TURN, OPEN_STAGE_MAP }

@onready var _roll_content: MarginContainer = $MarginContainer
@onready var hud: HUD           = $MarginContainer/VBoxContainer/HUD
@onready var dice_arena: DiceArena = $MarginContainer/VBoxContainer/ArenaRow/ArenaViewportContainer/ArenaViewport/DiceArena
@onready var _arena_viewport_container: SubViewportContainer = $MarginContainer/VBoxContainer/ArenaRow/ArenaViewportContainer
@onready var roll_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RollButton
@onready var bank_button: Button = $MarginContainer/VBoxContainer/ButtonRow/BankButton
@onready var new_run_button: Button = $MarginContainer/VBoxContainer/ButtonRow/NewRunButton
@onready var career_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CareerButton
@onready var codex_button: Button = $MarginContainer/VBoxContainer/ButtonRow/CodexButton
@onready var shop_panel: ShopPanel = $ShopPanel
@onready var career_panel: CareerPanel = $CareerPanel
@onready var codex_panel: DiceCodexPanel = $DiceCodexPanel
@onready var highlights_panel: HighlightsPanel = $HighlightsPanel
@onready var forge_panel: ForgePanel = $ForgePanel
@onready var stage_map_panel: StageMapPanel = $StageMapPanel
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var pause_menu: Control = $PauseMenu
@onready var _contract_overlay_panel: PanelContainer = $MarginContainer/VBoxContainer/ArenaRow/ContractOverlay
@onready var _contract_overlay_title_label: Label = $MarginContainer/VBoxContainer/ArenaRow/ContractOverlay/MarginContainer/VBoxContainer/ContractTitleLabel
@onready var _contract_overlay_check_label: Label = $MarginContainer/VBoxContainer/ArenaRow/ContractOverlay/MarginContainer/VBoxContainer/ContractRow/CheckLabel
@onready var _contract_overlay_text_label: Label = $MarginContainer/VBoxContainer/ArenaRow/ContractOverlay/MarginContainer/VBoxContainer/ContractRow/ContractTextLabel
@onready var _risk_tower_overlay: PanelContainer = $MarginContainer/VBoxContainer/ArenaRow/RiskTowerOverlay
@onready var _risk_tower_title_label: Label = $MarginContainer/VBoxContainer/ArenaRow/RiskTowerOverlay/MarginContainer/VBoxContainer/RiskTitleLabel
@onready var _risk_tower_lights_column: VBoxContainer = $MarginContainer/VBoxContainer/ArenaRow/RiskTowerOverlay/MarginContainer/VBoxContainer/LightsColumn
@onready var _risk_tower_stop_dots_column: VBoxContainer = $MarginContainer/VBoxContainer/ArenaRow/RiskTowerOverlay/MarginContainer/VBoxContainer/StopDotsColumn
@onready var _risk_tower_percent_label: Label = $MarginContainer/VBoxContainer/ArenaRow/RiskTowerOverlay/MarginContainer/VBoxContainer/RiskPercentLabel

var turn_state: TurnState = TurnState.IDLE
var turn_number: int = 0

# Per-die state arrays (same length as GameManager.dice_pool).
var current_results: Array[DiceFaceData] = []
var dice_stopped: Array[bool] = []
var dice_keep: Array[bool] = []
var dice_keep_locked: Array[bool] = []
var _die_reroll_counts: Array[int] = []
var _was_displaced: Array[bool] = []
var _cluster_child_flags: Array[bool] = []
var _pending_displacement_resolves: Array[int] = []

## Running total of STOP faces rolled this turn. Only increases; resets on
## bank, bust, or new turn. Used for the accumulated bust check.
var accumulated_stop_count: int = 0
var accumulated_shield_count: int = 0
var _stage_starting_stop_pressure: int = 0

var _run_active: bool = true
var _loop_complete_pending: bool = false
var bank_streak: int = 0
var _reroll_count: int = 0
var _streak_display: Control = null
var _run_snapshot_recorded: bool = false
var _is_roll_animating: bool = false
var _roll_anim_nonce: int = 0
var _triggered_combo_ids: Dictionary = {}
var _screen_shake: Node = null
var _screen_overlay: Node = null
var _turn_score_service: RefCounted = null
var _bust_resolver: RefCounted = null
var _risk_estimator: RefCounted = null
var _roll_resolution_service: RefCounted = null
var _contract_progress_service: RefCounted = null
var _stage_flow: RefCounted = null
var _defer_stage_clear_overlay: bool = false
var _pending_stage_clear_overlay: bool = false
var _stage_had_bust: bool = false
var _turn_entered_high_risk: bool = false
var _resume_surface: String = RESUME_SURFACE_TURN
var _resume_payload: Dictionary = {}
var _active_event_overlay: ColorRect = null
var _active_rest_overlay: ColorRect = null
var _risk_tower: RiskTowerRenderer = null
var _contract_overlay_ctrl: ContractOverlayController = null
var _vfx: RollPhaseVFX = null
var _surface_ctrl: SurfaceTransitionController = null
var _pending_run_end_snapshot: RunSaveData = null
var _pending_run_end_prior_bests: Dictionary = {}
var _settings_opened_from_pause: bool = false
var _snapshot_service: RefCounted = null

const StreakDisplayScript: GDScript = preload("res://Scripts/StreakDisplay.gd")
const BustOverlayScene: PackedScene = preload("res://Scenes/BustOverlay.tscn")
const StageClearedScene: PackedScene = preload("res://Scenes/StageCleared.tscn")
const DiceRewardScene: PackedScene = preload("res://Scenes/DiceRewardOverlay.tscn")
const AchievementToastScene: PackedScene = preload("res://Scenes/AchievementToast.tscn")
const StageEventScene: PackedScene = preload("res://Scenes/StageEventOverlay.tscn")
const RestOverlayScene: PackedScene = preload("res://Scenes/RestOverlay.tscn")
const ArchetypePickerScene: PackedScene = preload("res://Scenes/ArchetypePicker.tscn")
const ContractSelectionPanelScene: PackedScene = preload("res://Scenes/ContractSelectionPanel.tscn")
const ScreenShakeScript: GDScript = preload("res://Scripts/ScreenShake.gd")
const ScreenOverlayScript: GDScript = preload("res://Scripts/ScreenOverlay.gd")
const TurnScoreServiceScript: GDScript = preload("res://Scripts/TurnScoreService.gd")
const BustFlowResolverScript: GDScript = preload("res://Scripts/BustFlowResolver.gd")
const BustRiskEstimatorScript: GDScript = preload("res://Scripts/BustRiskEstimator.gd")
const RollResolutionServiceScript: GDScript = preload("res://Scripts/RollResolutionService.gd")
const ContractProgressServiceScript: GDScript = preload("res://Scripts/ContractProgressService.gd")
const StageFlowCoordinatorScript: GDScript = preload("res://Scripts/StageFlowCoordinator.gd")
const FlowTransitionScript: GDScript = preload("res://Scripts/FlowTransition.gd")
const ClusterDieHelperScript: GDScript = preload("res://Scripts/ClusterDieHelper.gd")
const _UITheme := preload("res://Scripts/UITheme.gd")
const StageMapDataScript: GDScript = preload("res://Scripts/StageMapData.gd")
const LoopContractCatalogScript: GDScript = preload("res://Scripts/LoopContractCatalog.gd")
const LoopContractDataType: GDScript = preload("res://Scripts/LoopContractData.gd")
const RollPhaseSnapshotScript: GDScript = preload("res://Scripts/RollPhaseSnapshot.gd")
const RollPhaseSnapshotScript: GDScript = preload("res://Scripts/RollPhaseSnapshot.gd")
const MAIN_MENU_SCENE_PATH: String = "res://Scenes/MainMenu.tscn"

func _ready() -> void:
	_turn_score_service = TurnScoreServiceScript.new()
	_bust_resolver = BustFlowResolverScript.new()
	_risk_estimator = BustRiskEstimatorScript.new()
	_roll_resolution_service = RollResolutionServiceScript.new()
	_contract_progress_service = ContractProgressServiceScript.new()
	_stage_flow = StageFlowCoordinatorScript.new()
	_snapshot_service = RollPhaseSnapshotScript.new()
	theme = _UITheme.build_theme()
	roll_button.pressed.connect(_on_roll_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	career_button.pressed.connect(_on_career_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	dice_arena.die_clicked.connect(_on_die_toggled)
	dice_arena.die_shift_clicked.connect(_on_die_shift_toggled)
	dice_arena.all_dice_settled.connect(_on_all_dice_settled)
	dice_arena.die_collision_rerolled.connect(_on_die_collision_rerolled)
	shop_panel.shop_closed.connect(_on_shop_closed)
	career_panel.closed.connect(_on_career_closed)
	codex_panel.closed.connect(_on_codex_closed)
	settings_panel.closed.connect(_on_settings_closed)
	pause_menu.connect("resume_requested", _on_pause_resume_requested)
	pause_menu.connect("settings_requested", _on_pause_settings_requested)
	pause_menu.connect("quit_requested", _on_pause_quit_requested)
	highlights_panel.closed.connect(_on_highlights_closed)
	forge_panel.forge_closed.connect(_on_forge_closed)
	stage_map_panel.node_selected.connect(_on_map_node_selected)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.stage_cleared.connect(_on_stage_cleared)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	new_run_button.visible = false
	career_button.visible = false
	codex_button.visible = false
	_set_post_run_buttons_visible(false)
	_streak_display = StreakDisplayScript.new()
	hud.attach_streak_display(_streak_display)
	hud.intro_card_slotted.connect(_on_intro_card_slotted)
	_screen_shake = ScreenShakeScript.new()
	add_child(_screen_shake)
	_screen_shake.setup(_roll_content)
	_screen_overlay = ScreenOverlayScript.new()
	add_child(_screen_overlay)
	_risk_tower = RiskTowerRenderer.new()
	add_child(_risk_tower)
	_risk_tower.setup(
		_risk_tower_overlay, _risk_tower_title_label,
		_risk_tower_lights_column, _risk_tower_stop_dots_column,
		_risk_tower_percent_label, hud, _roll_content,
	)
	_contract_overlay_ctrl = ContractOverlayController.new()
	add_child(_contract_overlay_ctrl)
	_contract_overlay_ctrl.setup(
		_contract_overlay_panel, _contract_overlay_title_label,
		_contract_overlay_check_label, _contract_overlay_text_label,
		_contract_progress_service, _roll_content,
	)
	_vfx = RollPhaseVFX.new()
	add_child(_vfx)
	_vfx.setup(self, _screen_shake, _screen_overlay)
	_surface_ctrl = SurfaceTransitionController.new()
	add_child(_surface_ctrl)
	_surface_ctrl.setup(self, _roll_content, shop_panel, forge_panel, stage_map_panel, _screen_shake)
	_add_button_micro_tween(roll_button)
	_add_button_micro_tween(bank_button)
	_add_button_micro_tween(new_run_button)
	_add_button_micro_tween(career_button)
	_add_button_micro_tween(codex_button)
	if LocalizationManager != null:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	GameManager.loop_contract_changed.connect(_on_loop_contract_overlay_changed)
	GameManager.loop_contract_progress_changed.connect(_on_loop_contract_overlay_progress_changed)
	_refresh_contract_overlay()
	if GameManager.skip_archetype_picker:
		_begin_loop_contract_flow(ContractContinuation.START_TURN)
	elif SaveManager.has_active_run_snapshot():
		_show_archetype_picker(true)
	elif SaveManager.run_history.is_empty():
		# First run ever defaults to Caution in Classic mode.
		_start_new_fresh_run(int(GameManager.RunMode.CLASSIC), int(GameManager.Archetype.CAUTION), false, "")
	else:
		_show_archetype_picker(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_picker_open() or pause_menu.visible or settings_panel.visible:
		return
	get_viewport().set_input_as_handled()
	_open_pause_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_persist_active_run_snapshot()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_persist_active_run_snapshot()


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _start_new_turn() -> void:
	turn_state = TurnState.IDLE
	turn_number += 1
	_resume_surface = RESUME_SURFACE_TURN
	_resume_payload.clear()
	accumulated_stop_count = 0
	if turn_number == 1 and _stage_starting_stop_pressure > 0:
		accumulated_stop_count = _stage_starting_stop_pressure
	accumulated_shield_count = 0
	_turn_entered_high_risk = false
	GameManager.set_held_stop_count(0)
	GameManager.begin_special_stage_turn()
	hud.reset_score_feedback_visuals(true)
	_reroll_count = 0
	_triggered_combo_ids.clear()
	hud.set_active_combos([])
	GameManager.consume_cluster_children_for_new_hand()
	var count: int = GameManager.dice_pool.size()
	current_results.resize(count)
	current_results.fill(null)
	_die_reroll_counts.resize(count)
	_die_reroll_counts.fill(0)
	_was_displaced.resize(count)
	_was_displaced.fill(false)
	_cluster_child_flags.resize(count)
	_cluster_child_flags.fill(false)
	dice_stopped.resize(count)
	dice_stopped.fill(false)
	dice_keep.resize(count)
	dice_keep.fill(false)
	dice_keep_locked.resize(count)
	dice_keep_locked.fill(false)
	dice_arena.reset()
	if turn_number == 1 and _stage_starting_stop_pressure > 0:
		_push_feed_status("PRESSURE UP! Stage starts with %d stop." % _stage_starting_stop_pressure, Color(1.0, 0.62, 0.2))
	_sync_ui()
	_persist_active_run_snapshot()

# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	if not _run_active:
		return
	if _is_roll_animating:
		return
	match turn_state:
		TurnState.IDLE:
			_roll_all_dice()
		TurnState.ACTIVE:
			_reroll_selected_dice()
		TurnState.BUST:
			_start_new_turn()
			_roll_all_dice()

func _on_bank_pressed() -> void:
	if turn_state != TurnState.ACTIVE:
		return
	turn_state = TurnState.BANKED
	bank_streak += 1
	_update_streak_display()
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var heart_relief: int = _apply_banked_heart_relief()
	var bank_threshold: int = _get_bust_threshold()
	var bank_effective_stops: int = _get_effective_stop_count()
	GameManager.set_held_stop_count(_count_intentionally_held_stops())
	var is_near_death_bank: bool = bank_threshold > 1 and bank_effective_stops == bank_threshold - 1
	var meta_exp_reward: int = 0
	var meta_shard_reward: int = 0
	var archetype_rewards: Dictionary = {
		"gold": 0,
		"exp": 0,
		"stop_shards": 0,
		"heal": 0,
	}
	if is_near_death_bank:
		GameManager.register_near_death_bank(bank_effective_stops, bank_threshold)
		GameManager.add_gold(NEAR_DEATH_GOLD_BONUS)
		if SaveManager.has_permanent_upgrade("shard_magnet"):
			meta_shard_reward += META_NEAR_DEATH_SHARD_REWARD
	archetype_rewards = GameManager.get_archetype_bank_rewards(bank_effective_stops, is_near_death_bank)
	if int(archetype_rewards.get("gold", 0)) > 0:
		GameManager.add_gold(int(archetype_rewards.get("gold", 0)))
	if int(archetype_rewards.get("exp", 0)) > 0:
		GameManager.add_run_exp(int(archetype_rewards.get("exp", 0)))
	if int(archetype_rewards.get("stop_shards", 0)) > 0:
		GameManager.add_run_stop_shards(int(archetype_rewards.get("stop_shards", 0)))
	if int(archetype_rewards.get("heal", 0)) > 0:
		GameManager.heal_hands(int(archetype_rewards.get("heal", 0)))
	if SaveManager.has_permanent_upgrade("reroll_ledger") and _reroll_count >= 2:
		meta_exp_reward += META_LEDGER_EXP_REWARD
	if SaveManager.has_permanent_upgrade("close_call_study") and _turn_entered_high_risk:
		meta_exp_reward += META_HIGH_RISK_EXP_REWARD
	if meta_exp_reward > 0:
		GameManager.add_run_exp(meta_exp_reward)
	if meta_shard_reward > 0:
		GameManager.add_run_stop_shards(meta_shard_reward)
	var base_banked: int = _calculate_turn_score()
	# Iron Bank: +50% score if no rerolls.
	if GameManager.has_modifier(RunModifier.ModifierType.IRON_BANK) and _reroll_count == 0:
		base_banked = int(base_banked * 1.5)
	# Cascade combo bonus: active combos award bonus points with escalation.
	var combo_bonus: int = _calculate_combo_bonus()
	base_banked += combo_bonus
	# Hot Streak multiplier: 3+ consecutive banks = x1.1, 5+ = x1.2.
	var streak_mult: float = _get_streak_multiplier()
	# Momentum multiplier: grows +5% per reroll this stage.
	var momentum_mult: float = _get_momentum_multiplier()
	var banked: int = int(base_banked * streak_mult * momentum_mult)
	var special_preview: Dictionary = GameManager.get_special_stage_bank_preview(effective_stops, _reroll_count)
	banked += int(special_preview.get("bonus_score", 0))
	var old_total: int = GameManager.total_score
	var will_clear_stage: bool = old_total + banked >= GameManager.stage_target_score
	var special_clear_rewards: Dictionary = GameManager.get_special_stage_clear_rewards(effective_stops, will_clear_stage)
	var special_score_bonus: int = int(special_preview.get("bonus_score", 0)) + int(special_clear_rewards.get("bonus_score", 0))
	_defer_stage_clear_overlay = will_clear_stage
	_pending_stage_clear_overlay = false
	GameManager.add_score(banked)
	GameManager.spend_hand_on_bank(will_clear_stage)
	_defer_stage_clear_overlay = false
	var special_gold: int = int(special_preview.get("bonus_gold", 0)) + int(special_clear_rewards.get("bonus_gold", 0))
	if special_gold > 0:
		GameManager.add_gold(special_gold)
	var special_luck: int = int(special_preview.get("bonus_luck", 0)) + int(special_clear_rewards.get("bonus_luck", 0))
	if special_luck > 0:
		GameManager.add_luck(special_luck)
	_publish_bank_score_feed(combo_bonus, streak_mult, momentum_mult, special_score_bonus, banked)
	if special_gold > 0:
		hud.push_event_effect("SPECIAL PAYOUT +%dg" % special_gold, _UITheme.SCORE_GOLD)
	if special_luck > 0:
		hud.push_event_effect("SPECIAL LUCK +%d" % special_luck, _UITheme.SUCCESS_GREEN)
	# Reset momentum after banking (cashes out the bonus).
	GameManager.reset_momentum()
	# Accumulate LUCK face values for dice reward rarity.
	_accumulate_luck()
	# Side-bets resolve on bank.
	var heat_payout: int = GameManager.resolve_heat_bet(accumulated_stop_count)
	if heat_payout > 0:
		_push_feed_status("HEAT BET HIT! +%dg" % heat_payout, Color(1.0, 0.8, 0.2))

	var even_count: int = 0
	var odd_count: int = 0
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		if not (dice_keep[i] or dice_keep_locked[i]):
			continue
		var parity_face: DiceFaceData = current_results[i]
		if parity_face == null or parity_face.type != DiceFaceData.FaceType.NUMBER:
			continue
		if parity_face.value % 2 == 0:
			even_count += 1
		else:
			odd_count += 1
	var had_even_odd_bet: bool = GameManager.even_odd_bet_wager > 0
	var eo_result: int = GameManager.resolve_even_odd_bet(even_count, odd_count)
	if eo_result > 0:
		_push_feed_status("EVEN/ODD WIN! +%dg" % eo_result, Color(0.95, 0.85, 0.2))
	elif eo_result < 0:
		_push_feed_status("EVEN/ODD LOST", Color(1.0, 0.4, 0.4))
	elif had_even_odd_bet and even_count == odd_count and (even_count + odd_count) > 0:
		_push_feed_status("EVEN/ODD PUSH (tie)", Color(0.6, 0.9, 1.0))
	# Gambler's Rush: +1g per survived stop.
	if GameManager.has_modifier(RunModifier.ModifierType.GAMBLERS_RUSH) and accumulated_stop_count > 0:
		var rush_gold: int = accumulated_stop_count
		GameManager.add_gold(rush_gold)
	# Scavenger: +1g per kept (non-stopped) die.
	if GameManager.has_modifier(RunModifier.ModifierType.SCAVENGER):
		var kept_count: int = 0
		for i: int in GameManager.dice_pool.size():
			if not dice_stopped[i] and (dice_keep[i] or dice_keep_locked[i]):
				kept_count += 1
		if kept_count > 0:
			GameManager.add_gold(kept_count)
	# Jackpot check: first roll only (no rerolls), 5+ dice, 0 stops.
	var is_jackpot: bool = _reroll_count == 0 and GameManager.dice_pool.size() >= JACKPOT_MIN_DICE and accumulated_stop_count == 0
	AchievementManager.on_bank(banked, _reroll_count, accumulated_stop_count, GameManager.dice_pool.size(), bank_streak)
	if is_jackpot:
		var jackpot_gold: int = maxi(1, int(banked * JACKPOT_GOLD_BONUS))
		GameManager.add_gold(jackpot_gold)
		SFXManager.play_jackpot()
		if _screen_overlay and _screen_overlay.has_method("flash_jackpot"):
			_screen_overlay.flash_jackpot()
		_spawn_jackpot_confetti()
		_push_feed_status("JACKPOT! +%dg bonus!" % jackpot_gold, Color(1.0, 0.85, 0.0))
	var mult: int = _get_turn_multiplier()
	var status_parts: Array[String] = []
	var contract_status: String = ""
	var evolution_status: String = ""
	var mult_text: String = " (x%d!)" % mult if mult > 1 else ""
	var contract_context: Dictionary = {
		"effective_stops": bank_effective_stops,
		"threshold": bank_threshold,
		"reroll_count": _reroll_count,
		"even_count": even_count,
		"odd_count": odd_count,
		"shield_count": accumulated_shield_count,
		"raw_stops": accumulated_stop_count,
		"entered_high_risk": _turn_entered_high_risk,
	}
	contract_status = _update_active_contract_on_bank(contract_context)
	evolution_status = _apply_reroll_evolutions()
	if heart_relief > 0:
		status_parts.append("HEARTS -%d STOP" % heart_relief)
	if is_near_death_bank:
		status_parts.append("NEAR DEATH +%dg" % NEAR_DEATH_GOLD_BONUS)
	if int(archetype_rewards.get("gold", 0)) > 0:
		status_parts.append("ARCHETYPE +%dg" % int(archetype_rewards.get("gold", 0)))
	if int(archetype_rewards.get("exp", 0)) > 0:
		status_parts.append("CAPSTONE +%d EXP" % int(archetype_rewards.get("exp", 0)))
	if int(archetype_rewards.get("stop_shards", 0)) > 0:
		status_parts.append("CAPSTONE +%d SHARD" % int(archetype_rewards.get("stop_shards", 0)))
	if int(archetype_rewards.get("heal", 0)) > 0:
		status_parts.append("LAST CALL +%d HAND" % int(archetype_rewards.get("heal", 0)))
	if meta_exp_reward > 0:
		status_parts.append("LAB +%d EXP" % meta_exp_reward)
	if meta_shard_reward > 0:
		status_parts.append("LAB +%d SHARD" % meta_shard_reward)
	for special_part: String in special_preview.get("status_parts", []) as Array[String]:
		status_parts.append(special_part)
	for special_part: String in special_clear_rewards.get("status_parts", []) as Array[String]:
		status_parts.append(special_part)
	for special_part: String in special_preview.get("status_parts", []) as Array[String]:
		status_parts.append(special_part)
	for special_part: String in special_clear_rewards.get("status_parts", []) as Array[String]:
		status_parts.append(special_part)
	if streak_mult > 1.0:
		status_parts.append("ON FIRE x%.1f" % streak_mult)
	if momentum_mult > 1.0:
		status_parts.append("MOMENTUM x%.2f" % momentum_mult)
	if contract_status != "":
		status_parts.append(contract_status)
	if evolution_status != "":
		status_parts.append(evolution_status)
	status_parts.append("Banked %d points%s!  Total: %d" % [banked, mult_text, GameManager.total_score])
	if not is_jackpot:
		_push_feed_status(" | ".join(status_parts), Color(0.3, 0.9, 0.3))
	SFXManager.play_bank()
	# Personal best turn score check.
	if GameManager.register_turn_score(banked):
		_push_feed_status("NEW BEST TURN! %d pts" % banked, Color(1.0, 0.85, 0.0))
		SFXManager.play_personal_best()
	if banked >= 50:
		_shake_screen(SHAKE_BIG_BANK, 0.2)
	_play_multiply_face_vfx()
	# Per-die score count-up followed by cascade checkpoints.
	var anim_duration: float = _play_bank_cascade_animation(old_total, GameManager.total_score, mult, streak_mult)
	_sync_buttons()
	if _has_pending_run_end_sequence():
		_schedule_pending_run_end_sequence(anim_duration)
	elif will_clear_stage or _pending_stage_clear_overlay:
		_schedule_deferred_stage_clear(anim_duration)
	else:
		# Auto-advance to next turn after counting animation finishes.
		_schedule_auto_advance(anim_duration)

func _on_die_toggled(die_index: int, is_kept: bool) -> void:
	if turn_state != TurnState.ACTIVE:
		if turn_state != TurnState.BUST:
			return
	if turn_state == TurnState.BUST and not _run_active:
		return
	if dice_keep_locked[die_index]:
		return
	if dice_stopped[die_index]:
		dice_keep[die_index] = is_kept
		_sync_all_dice()
		_sync_ui()
		return
	dice_keep[die_index] = is_kept
	_sync_ui()


func _on_die_shift_toggled(die_index: int, is_kept: bool) -> void:
	if turn_state != TurnState.ACTIVE:
		if turn_state != TurnState.BUST:
			return
	if turn_state == TurnState.BUST and not _run_active:
		return
	var clicked_face: DiceFaceData = current_results[die_index]
	if clicked_face == null:
		return
	var target_type: DiceFaceData.FaceType = clicked_face.type
	var target_value: int = clicked_face.value
	for i: int in current_results.size():
		if current_results[i] == null:
			continue
		if current_results[i].type != target_type or current_results[i].value != target_value:
			continue
		if dice_keep_locked[i]:
			continue
		if dice_stopped[i]:
			dice_keep[i] = is_kept
			var stopped_die: PhysicsDie = dice_arena.get_die(i)
			if stopped_die:
				stopped_die.is_stopped = true
				stopped_die.is_kept = is_kept
			continue
		dice_keep[i] = is_kept
		var toggle_die: PhysicsDie = dice_arena.get_die(i)
		if toggle_die:
			toggle_die.is_kept = is_kept
	_sync_all_dice()
	_sync_ui()

# ---------------------------------------------------------------------------
# Rolling logic
# ---------------------------------------------------------------------------

func _roll_all_dice() -> void:
	_begin_roll_animation_lock()
	_shake_screen(SHAKE_ROLL, 0.15)
	# Throw all dice into the arena — faces are rolled inside throw_dice
	dice_arena.throw_dice(_typed_dice_pool())
	# Results will be processed when all_dice_settled signal fires

func _reroll_selected_dice() -> void:
	_reroll_count += 1
	var special_reroll_status: String = GameManager.apply_special_stage_reroll_bonus(_reroll_count)
	if special_reroll_status != "":
		_push_feed_status(special_reroll_status, GameManager.get_active_special_stage_color())
	# Lock all currently-kept dice permanently before rerolling.
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] and not dice_keep_locked[i]:
			dice_keep_locked[i] = true
			dice_arena.lock_die(i)
			var locked_die: PhysicsDie = dice_arena.get_die(i)
			if locked_die:
				locked_die.play_keep_lock_snap()

	var rerolled: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		if dice_keep[i] or dice_keep_locked[i]:
			continue
		# Stopped dice are rerolled too (Cubitos-style: pick them up and retry)
		if dice_stopped[i]:
			dice_stopped[i] = false
		_die_reroll_counts[i] += 1
		rerolled.append(i)
	if rerolled.is_empty():
		# No dice to reroll — all are kept/locked, so auto-bank.
		_on_bank_pressed()
		return
	# Increment momentum on each reroll.
	GameManager.add_momentum()
	# Recycler: +1g per die rerolled.
	if GameManager.has_modifier(RunModifier.ModifierType.RECYCLER):
		GameManager.add_gold(rerolled.size())
	_begin_roll_animation_lock()
	dice_arena.reroll_dice(rerolled, _typed_dice_pool())
	# Results will be processed when all_dice_settled signal fires


## Called when all dice in the arena have stopped moving.
func _on_all_dice_settled() -> void:
	# Read final faces from the arena (only for non-locked dice; locked keep their result)
	var arena_results: Array[DiceFaceData] = dice_arena.get_results()
	for i: int in arena_results.size():
		if not dice_keep_locked[i]:
			current_results[i] = arena_results[i]
	# Determine which indices to process (all non-locked dice)
	var rolled_indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		if not dice_keep_locked[i]:
			rolled_indices.append(i)
	if rolled_indices.is_empty():
		rolled_indices = _all_dice_indices()
	_process_roll_results(_sort_indices_by_category_and_position(rolled_indices))


## Called when a collision reroll happens during the rolling phase (cosmetic only).
func _on_die_collision_rerolled(die_index: int, new_face: DiceFaceData) -> void:
	# Update our tracking — cosmetic only, stops are NOT accumulated
	current_results[die_index] = new_face


func _resolve_roll_tier(indices: Array[int], chain_reroll: Array[int]) -> void:
	for i: int in indices:
		var face: DiceFaceData = current_results[i]
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.STOP, DiceFaceData.FaceType.CURSED_STOP:
				dice_stopped[i] = true
				dice_keep[i] = false
			DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.LUCK:
				dice_keep[i] = true
				dice_keep_locked[i] = true
			DiceFaceData.FaceType.EXPLODE:
				# EXPLODE: score its value AND chain-reroll this die
				dice_keep[i] = true
				dice_keep_locked[i] = true
				chain_reroll.append(i)
			_:
				if not dice_keep_locked[i]:
					dice_keep[i] = false

	for i: int in indices:
		var die: PhysicsDie = dice_arena.get_die(i)
		if die:
			die.show_face(current_results[i])
			_sync_arena_die_state(i)
			var face: DiceFaceData = current_results[i]
			if face and (face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP):
				die.play_stop_impact(face.type == DiceFaceData.FaceType.CURSED_STOP)
				if face.type == DiceFaceData.FaceType.CURSED_STOP:
					SFXManager.play_cursed_stop()
				else:
					SFXManager.play_stop_face()
			if face and (face.type == DiceFaceData.FaceType.AUTO_KEEP or face.type == DiceFaceData.FaceType.SHIELD \
					or face.type == DiceFaceData.FaceType.MULTIPLY \
					or face.type == DiceFaceData.FaceType.INSURANCE or face.type == DiceFaceData.FaceType.EXPLODE \
					or face.type == DiceFaceData.FaceType.LUCK):
				die.pop()


func _process_roll_results(rolled_indices: Array[int]) -> void:
	if not rolled_indices.is_empty():
		_begin_roll_animation_lock()
	# Track which dice need chain re-rolls (EXPLODE faces)
	var chain_reroll: Array[int] = []
	var ordered_indices: Array[int] = _sort_indices_by_category_and_position(rolled_indices)
	var tier_order: Array[int] = []
	var tier_map: Dictionary = {}
	for index: int in ordered_indices:
		var die_data: DiceData = GameManager.dice_pool[index] if index >= 0 and index < GameManager.dice_pool.size() else null
		var category: int = int(die_data.category) if die_data != null else int(DiceData.DieCategory.NORMAL)
		if not tier_map.has(category):
			tier_map[category] = []
			tier_order.append(category)
		var tier_indices: Array[int] = _copy_int_array(tier_map[category])
		tier_indices.append(index)
		tier_map[category] = tier_indices

	for tier_idx: int in tier_order.size():
		var tier: int = tier_order[tier_idx]
		var tier_indices: Array[int] = _copy_int_array(tier_map[tier])
		_resolve_roll_tier(tier_indices, chain_reroll)
		if tier_idx < tier_order.size() - 1:
			await get_tree().create_timer(CATEGORY_TIER_STEP_DELAY).timeout

	rolled_indices = ordered_indices
	var roll_stop_count: int = _count_stops_in(rolled_indices)

	# Recompute effective stops using proximity multipliers rather than a flat STOP count.
	_maybe_spawn_cluster_children(rolled_indices)
	accumulated_stop_count += roll_stop_count
	_register_rolled_shields(rolled_indices)
	var shield_count: int = _count_shields()
	var effective_stops: int = _bust_resolver.effective_stops(accumulated_stop_count, shield_count)
	var threshold: int = _get_bust_threshold()
	var is_immune: bool = _bust_resolver.is_immune_turn(turn_number, GameManager.current_stage, int(GameManager.chosen_archetype))
	var insurance_index: int = _find_insurance_face_index()
	var bust_outcome: int = _get_roll_resolution_service().resolve_bust_outcome(
		effective_stops,
		threshold,
		is_immune,
		insurance_index,
		GameManager.event_free_bust
	)
	match bust_outcome:
		RollBustOutcome.SAFE, RollBustOutcome.IMMUNE_SAVE:
			turn_state = TurnState.ACTIVE
		RollBustOutcome.INSURANCE_SAVE:
			_consume_insurance_face(insurance_index)
			turn_state = TurnState.BANKED
			bank_streak = 0
			_update_streak_display()
			_push_feed_status("INSURANCE TRIGGERED! Bust canceled; turn score forfeited.", Color(0.4, 0.8, 1.0))
			SFXManager.play_close_call()
			_sync_buttons()
			_schedule_auto_advance()
		RollBustOutcome.EVENT_SAVE:
			if GameManager.consume_event_free_bust():
				turn_state = TurnState.BANKED
				bank_streak = 0
				_update_streak_display()
				_push_feed_status("GUARDIAN ANGEL! Bust absorbed — turn score forfeited.", Color(0.4, 0.8, 1.0))
				SFXManager.play_close_call()
				_sync_buttons()
				_schedule_auto_advance()
			else:
				_apply_bust_outcome(effective_stops)
		RollBustOutcome.BUST:
			_apply_bust_outcome(effective_stops)

	# Sync non-rolled dice visuals.
	for i: int in GameManager.dice_pool.size():
		if i not in rolled_indices:
			_sync_arena_die_state(i)
	GameManager.set_held_stop_count(_count_intentionally_held_stops())
	_sync_ui()

	# Status messages based on roll outcome.
	if turn_state == TurnState.BUST:
		pass  # Bust overlay handles messaging.
	elif is_immune and effective_stops >= threshold:
		_push_feed_status("CLOSE CALL! Turn %d — no bust this time." % turn_number, Color(1.0, 0.6, 0.0))
	elif effective_stops == threshold - 1 and threshold > 1 and turn_number > 1:
		_push_feed_status("CLOSE CALL! One more stop and you bust!", Color(1.0, 0.6, 0.0))
		SFXManager.play_close_call()
	elif effective_stops == 0 and rolled_indices.size() > 0:
		_push_feed_status("CLEAN ROLL! No stops!", Color(0.3, 1.0, 0.3))
		SFXManager.play_clean_roll()

	if roll_stop_count > 0:
		# Keep STOP feedback die-local (impact pop/sfx) to avoid perturbing HUD/layout.
		pass
	var shielded: int = _get_roll_resolution_service().absorbed_stop_count(roll_stop_count, shield_count)
	if shielded > 0:
		_push_feed_status("Shields absorbed %d stop(s)!" % shielded, Color(0.3, 0.7, 1.0))
		for i: int in GameManager.dice_pool.size():
			var shield_face: DiceFaceData = current_results[i]
			if shield_face != null and shield_face.type == DiceFaceData.FaceType.SHIELD:
				var shield_die: PhysicsDie = dice_arena.get_die(i)
				if shield_die:
					shield_die.play_shield_absorb()
		SFXManager.play_shield_absorb()

	# Handle EXPLODE chain re-rolls (free extra rolls, not counted toward bust)
	if turn_state == TurnState.ACTIVE and not chain_reroll.is_empty():
		await _process_explode_chains(chain_reroll)
		return

	_check_roll_combos()
	_release_roll_animation_lock(POST_ROLL_EFFECT_LOCK_DURATION)

	if turn_state == TurnState.ACTIVE and _all_dice_resolved():
		_on_bank_pressed()

# ---------------------------------------------------------------------------
# Score / helpers
# ---------------------------------------------------------------------------

func _all_dice_resolved() -> bool:
	for i: int in GameManager.dice_pool.size():
		if not dice_stopped[i] and not dice_keep[i]:
			return false
	return true


func _get_effective_stop_count() -> int:
	return _bust_resolver.effective_stops(accumulated_stop_count, _count_shields())


func _count_intentionally_held_stops() -> int:
	var total: int = 0
	for i: int in GameManager.dice_pool.size():
		if not dice_stopped[i]:
			continue
		if dice_keep[i] or dice_keep_locked[i]:
			total += 1
	return total

func _calculate_turn_score() -> int:
	return _turn_score_service.calculate_turn_score(
		current_results,
		dice_stopped,
		_get_die_positions(),
		_get_multiplies_stops_flags(),
		_was_displaced,
		GameManager.has_modifier(RunModifier.ModifierType.SHRAPNEL),
		GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON),
		GameManager.has_modifier(RunModifier.ModifierType.HIGH_ROLLER),
		GameManager.has_modifier(RunModifier.ModifierType.OVERCHARGE),
		GameManager.has_modifier(RunModifier.ModifierType.CHAIN_LIGHTNING)
	)


func _apply_reroll_evolutions() -> String:
	var evolved_names: Array[String] = []
	for i: int in GameManager.dice_pool.size():
		if i >= _die_reroll_counts.size():
			continue
		var die: DiceData = GameManager.dice_pool[i]
		if die == null or not die.is_reroll_evolving():
			continue
		if die.apply_reroll_progress(_die_reroll_counts[i]):
			SaveManager.discover_die(die.dice_name)
			evolved_names.append(die.get_display_name())
	if evolved_names.is_empty():
		return ""
	_sync_all_dice()
	return "EVOLVED %s" % ", ".join(evolved_names)


func _get_roll_resolution_service() -> RefCounted:
	if _roll_resolution_service == null:
		_roll_resolution_service = RollResolutionServiceScript.new()
	return _roll_resolution_service

func _count_stops() -> int:
	var count: int = 0
	for stopped: bool in dice_stopped:
		if stopped:
			count += 1
	return count


func _stop_value_for_face(face: DiceFaceData) -> int:
	if face == null:
		return 0
	if face.type == DiceFaceData.FaceType.CURSED_STOP:
		return 2
	if face.type == DiceFaceData.FaceType.STOP:
		return 1
	return 0


func _all_dice_indices() -> Array[int]:
	var indices: Array[int] = []
	for i: int in GameManager.dice_pool.size():
		indices.append(i)
	return indices

## Count stops only among the specified dice indices (per-roll bust check).
## CURSED_STOP counts as 2 stops.
func _count_stops_in(indices: Array[int]) -> int:
	var effective_stop_counts: Array[int] = _turn_score_service.calculate_effective_stop_counts(
		current_results,
		dice_stopped,
		_get_die_positions(),
		_get_multiplies_stops_flags()
	)
	var total: int = 0
	for index: int in indices:
		if index < 0 or index >= effective_stop_counts.size():
			continue
		total += effective_stop_counts[index]
	return total

func _count_shields() -> int:
	return accumulated_shield_count


func _resolve_face_outcome(index: int, face: DiceFaceData, chain_targets: Array[int], allow_explode_chain: bool) -> void:
	if index < 0 or index >= GameManager.dice_pool.size() or face == null:
		return
	current_results[index] = face
	dice_stopped[index] = false
	dice_keep[index] = false
	dice_keep_locked[index] = false
	match face.type:
		DiceFaceData.FaceType.STOP, DiceFaceData.FaceType.CURSED_STOP:
			dice_stopped[index] = true
			accumulated_stop_count += _stop_value_for_face(face)
		DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.EXPLODE, DiceFaceData.FaceType.LUCK:
			dice_keep[index] = true
			dice_keep_locked[index] = true
			if allow_explode_chain and face.type == DiceFaceData.FaceType.EXPLODE:
				chain_targets.append(index)
	var die: PhysicsDie = dice_arena.get_die(index)
	if die == null:
		return
	die.tumble(face)
	if face.type == DiceFaceData.FaceType.STOP or face.type == DiceFaceData.FaceType.CURSED_STOP:
		die.play_stop_impact(face.type == DiceFaceData.FaceType.CURSED_STOP)
	elif face.type == DiceFaceData.FaceType.EXPLODE:
		die.play_explode_charge()
		die.show_chain_label(1)
	elif face.type in [DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.MULTIPLY, DiceFaceData.FaceType.INSURANCE, DiceFaceData.FaceType.LUCK]:
		die.pop()
	_sync_arena_die_state(index)


func _is_displacement_immune(index: int) -> bool:
	if index < 0 or index >= current_results.size():
		return true
	var face: DiceFaceData = current_results[index]
	if face == null:
		return false
	if GameManager.has_modifier(RunModifier.ModifierType.BLAST_SHIELD) and face.type == DiceFaceData.FaceType.SHIELD:
		return true
	if GameManager.has_modifier(RunModifier.ModifierType.ANCHORED_HEARTS) and face.type == DiceFaceData.FaceType.HEART:
		return true
	return false


func _is_displacement_dampened(index: int) -> bool:
	if index < 0 or index >= current_results.size():
		return false
	if not GameManager.has_modifier(RunModifier.ModifierType.HEAVY_DICE):
		return false
	return dice_keep[index] or dice_keep_locked[index]


func _apply_explode_displacement(source_index: int, touched_indices: Array[int], radius_bonus: float = 0.0) -> Array[int]:
	var immune_indices: Array[int] = []
	var dampened_indices: Array[int] = []
	for index: int in current_results.size():
		if _is_displacement_immune(index):
			immune_indices.append(index)
		elif _is_displacement_dampened(index):
			dampened_indices.append(index)
	var hit_indices: Array[int] = dice_arena.detonate_around(
		source_index,
		EXPLODE_DISPLACEMENT_RADIUS + radius_bonus,
		[],
		immune_indices,
		dampened_indices
	)
	for hit_index: int in hit_indices:
		if not touched_indices.has(hit_index):
			touched_indices.append(hit_index)
		_was_displaced[hit_index] = true
		if not _pending_displacement_resolves.has(hit_index):
			_pending_displacement_resolves.append(hit_index)
	return hit_indices


func _resolve_pending_displacements(chain_targets: Array[int]) -> void:
	if _pending_displacement_resolves.is_empty():
		return
	while not _pending_displacement_resolves.is_empty():
		var hit_index: int = _pending_displacement_resolves.pop_front()
		await get_tree().create_timer(PhysicsDie.DETONATE_STAGGER_DELAY).timeout
		if hit_index < 0 or hit_index >= GameManager.dice_pool.size():
			continue
		var hit_die_data: DiceData = GameManager.dice_pool[hit_index]
		if hit_die_data == null:
			continue
		var reroll_delta: int = 1
		if GameManager.has_modifier(RunModifier.ModifierType.SPARK_SCATTER) and hit_die_data.is_reroll_evolving():
			reroll_delta += 1
		_die_reroll_counts[hit_index] += reroll_delta
		_reroll_count += 1
		if GameManager.has_modifier(RunModifier.ModifierType.RECYCLER):
			GameManager.add_gold(1)
		hit_die_data.apply_reroll_progress(_die_reroll_counts[hit_index])
		var new_face: DiceFaceData = hit_die_data.roll()
		var allow_sympathetic: bool = GameManager.has_modifier(RunModifier.ModifierType.SYMPATHETIC_DETONATION)
		_resolve_face_outcome(hit_index, new_face, chain_targets, allow_sympathetic)


func _play_detonation_cinematic() -> void:
	_shake_screen(SHAKE_DETONATE, 0.15)
	var prior_time_scale: float = Engine.time_scale
	Engine.time_scale = 0.8
	await get_tree().create_timer(PhysicsDie.DETONATE_RING_DURATION).timeout
	Engine.time_scale = prior_time_scale


func _maybe_spawn_cluster_children(indices: Array[int]) -> void:
	var pending: Array[int] = _copy_int_array(indices)
	while not pending.is_empty():
		var index: int = pending.pop_front()
		if index < 0 or index >= GameManager.dice_pool.size() or index >= current_results.size():
			continue
		if _cluster_child_flags[index]:
			continue
		var die_data: DiceData = GameManager.dice_pool[index]
		var face: DiceFaceData = current_results[index]
		if die_data == null or face == null or not die_data.is_cluster or face.type != DiceFaceData.FaceType.NUMBER:
			continue
		var max_depth: int = die_data.max_cluster_depth + GameManager.cluster_bonus_depth
		if die_data.cluster_generation >= max_depth:
			continue
		var child_count: int = maxi(0, face.value)
		if child_count <= 0:
			continue
		var child_dice: Array[DiceData] = []
		for _slot: int in child_count:
			child_dice.append(ClusterDieHelperScript.build_child_die(die_data, face.value))
		for child_die: DiceData in child_dice:
			GameManager.add_dice(child_die)
			current_results.append(null)
			dice_stopped.append(false)
			dice_keep.append(true)
			dice_keep_locked.append(true)
			_die_reroll_counts.append(0)
			_was_displaced.append(false)
			_cluster_child_flags.append(false)
		var spawned_indices: Array[int] = dice_arena.spawn_cluster_children(index, child_count, child_dice)
		_cluster_child_flags[index] = true
		for child_index: int in spawned_indices:
			var child_die_node: PhysicsDie = dice_arena.get_die(child_index)
			if child_die_node != null and child_index < current_results.size():
				current_results[child_index] = child_die_node.current_face
			pending.append(child_index)


func _recompute_free_effect_totals() -> void:
	accumulated_shield_count = 0
	var shield_multiplier: int = 2 if GameManager.has_modifier(RunModifier.ModifierType.SHIELD_WALL) else 1
	for i: int in GameManager.dice_pool.size():
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.SHIELD and not dice_stopped[i]:
			accumulated_shield_count += face.value * shield_multiplier


func _resolve_bust_after_free_effects() -> bool:
	var shield_count: int = _count_shields()
	var effective_stops: int = _bust_resolver.effective_stops(accumulated_stop_count, shield_count)
	var threshold: int = _get_bust_threshold()
	var is_immune: bool = _bust_resolver.is_immune_turn(turn_number, GameManager.current_stage, int(GameManager.chosen_archetype))
	var insurance_index: int = _find_insurance_face_index()
	var bust_outcome: int = _get_roll_resolution_service().resolve_bust_outcome(
		effective_stops,
		threshold,
		is_immune,
		insurance_index,
		GameManager.event_free_bust
	)
	match bust_outcome:
		RollBustOutcome.SAFE, RollBustOutcome.IMMUNE_SAVE:
			turn_state = TurnState.ACTIVE
			return false
		RollBustOutcome.INSURANCE_SAVE:
			_consume_insurance_face(insurance_index)
			_sync_arena_die_state(insurance_index)
			turn_state = TurnState.BANKED
			bank_streak = 0
			_update_streak_display()
			_push_feed_status("INSURANCE TRIGGERED! Bust canceled; turn score forfeited.", Color(0.4, 0.8, 1.0))
			SFXManager.play_close_call()
			_sync_buttons()
			_schedule_auto_advance()
			return true
		RollBustOutcome.EVENT_SAVE:
			if GameManager.consume_event_free_bust():
				turn_state = TurnState.BANKED
				bank_streak = 0
				_update_streak_display()
				_push_feed_status("GUARDIAN ANGEL! Bust absorbed — turn score forfeited.", Color(0.4, 0.8, 1.0))
				SFXManager.play_close_call()
				_sync_buttons()
				_schedule_auto_advance()
				return true
			_apply_bust_outcome(effective_stops)
			return true
		RollBustOutcome.BUST:
			_apply_bust_outcome(effective_stops)
			return true
	return false


func _register_rolled_shields(indices: Array[int], play_feedback: bool = true) -> int:
	var multiplier: int = 2 if GameManager.has_modifier(RunModifier.ModifierType.SHIELD_WALL) else 1
	var total: int = 0
	for i: int in indices:
		if i < 0 or i >= current_results.size():
			continue
		var face: DiceFaceData = current_results[i]
		if face == null or face.type != DiceFaceData.FaceType.SHIELD:
			continue
		total += face.value * multiplier
		if play_feedback:
			var shield_die: PhysicsDie = dice_arena.get_die(i)
			if shield_die:
				shield_die.play_shield_charge_pulse()
			SFXManager.play_shield_absorb()
	accumulated_shield_count += total
	return total


func _accumulate_luck() -> void:
	var luck_total: int = 0
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.LUCK:
			luck_total += maxi(1, face.value)
	if luck_total > 0:
		GameManager.add_luck(luck_total)


func _count_banked_hearts() -> int:
	var total: int = 0
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		if not (dice_keep[i] or dice_keep_locked[i]):
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.HEART:
			total += maxi(1, face.value)
	return total


func _apply_banked_heart_relief() -> int:
	var relief: int = _count_banked_hearts()
	if relief <= 0 or accumulated_stop_count <= 0:
		return 0
	accumulated_stop_count = maxi(0, accumulated_stop_count - relief)
	return relief


func _find_insurance_face_index() -> int:
	for i: int in GameManager.dice_pool.size():
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.INSURANCE:
			return i
	return -1


func _consume_insurance_face(die_index: int) -> void:
	var face: DiceFaceData = current_results[die_index]
	if face == null:
		return
	var die: PhysicsDie = dice_arena.get_die(die_index)
	if die:
		die.play_insurance_trigger()
	SFXManager.play_insurance_trigger()
	face.type = DiceFaceData.FaceType.BLANK
	face.value = 0
	dice_keep[die_index] = true
	dice_keep_locked[die_index] = true


func _apply_bust_outcome(effective_stops: int) -> void:
	turn_state = TurnState.BUST
	_stage_had_bust = true
	bank_streak = 0
	_update_streak_display()
	hud.reset_score_feedback_visuals(true)
	GameManager.set_held_stop_count(0)
	_update_active_contract_on_bust()
	GameManager.spend_hand_on_bust()
	var insurance_payout: int = GameManager.resolve_insurance_bet()
	AchievementManager.on_bust()
	SFXManager.play_bust()
	if _has_pending_run_end_sequence():
		_show_pending_run_end_sequence(effective_stops)
	else:
		_show_bust_overlay(effective_stops)
	if insurance_payout > 0:
		_push_feed_status("Insurance paid out: +%dg" % insurance_payout, Color(0.25, 0.95, 0.6))
	_sync_buttons()

func _get_turn_multiplier() -> int:
	var multiplier: int = 1
	for i: int in GameManager.dice_pool.size():
		if dice_stopped[i]:
			continue
		var face: DiceFaceData = current_results[i]
		if face != null and face.type == DiceFaceData.FaceType.MULTIPLY:
			multiplier *= face.value
	return multiplier

## EXPLODE chain: re-roll each exploding die. If it lands EXPLODE again, chain.
## Chains are free rolls (not counted toward bust). Capped to prevent infinite loops.
func _process_explode_chains(exploding_indices: Array[int]) -> void:
	var chain_depth: int = 0
	var to_reroll: Array[int] = _copy_int_array(exploding_indices)
	var touched_indices: Array[int] = _copy_int_array(exploding_indices)
	while not to_reroll.is_empty() and chain_depth < DiceData.MAX_CHAIN_ROLLS:
		chain_depth += 1
		var next_chain: Array[int] = []
		for i: int in to_reroll:
			var die: PhysicsDie = dice_arena.get_die(i)
			dice_keep[i] = false
			dice_keep_locked[i] = false
			dice_stopped[i] = false
			var face: DiceFaceData = GameManager.dice_pool[i].roll()
			if die:
				_shake_screen(CHAIN_SHAKE_BASE + float(chain_depth) * CHAIN_SHAKE_STEP, CHAIN_SHAKE_DURATION)
				die.show_chain_label(chain_depth)
			_resolve_face_outcome(i, face, next_chain, true)
			var displaced_primary: Array[int] = _apply_explode_displacement(i, touched_indices)
			if not displaced_primary.is_empty():
				await _play_detonation_cinematic()
			if GameManager.has_modifier(RunModifier.ModifierType.AFTERSHOCK):
				var displaced_aftershock: Array[int] = _apply_explode_displacement(i, touched_indices, AFTERSHOCK_RADIUS_BONUS)
				if not displaced_aftershock.is_empty():
					await _play_detonation_cinematic()
			await _resolve_pending_displacements(next_chain)
		to_reroll = next_chain

	# Explosophile: after chains end, reroll 1 extra un-resolved die for free.
	if chain_depth > 0 and GameManager.has_modifier(RunModifier.ModifierType.EXPLOSOPHILE):
		var candidates: Array[int] = []
		for i: int in GameManager.dice_pool.size():
			if not dice_keep[i] and not dice_keep_locked[i] and not dice_stopped[i]:
				candidates.append(i)
		if not candidates.is_empty():
			var extra_index: int = GameManager.rng_pick_index("roll", candidates.size())
			if extra_index < 0:
				extra_index = 0
			var extra_i: int = candidates[extra_index]
			var extra_face: DiceFaceData = GameManager.dice_pool[extra_i].roll()
			var extra_chain: Array[int] = []
			_resolve_face_outcome(extra_i, extra_face, extra_chain, true)
			var displaced_extra: Array[int] = _apply_explode_displacement(extra_i, touched_indices)
			if not displaced_extra.is_empty():
				await _play_detonation_cinematic()
			await _resolve_pending_displacements(extra_chain)
			if not touched_indices.has(extra_i):
				touched_indices.append(extra_i)

	_maybe_spawn_cluster_children(touched_indices)
	_recompute_free_effect_totals()

	_sync_all_dice()
	_sync_ui()
	if _resolve_bust_after_free_effects():
		_release_roll_animation_lock(POST_ROLL_EFFECT_LOCK_DURATION)
		return

	if chain_depth > 0:
		SFXManager.play_explode(chain_depth)
		_push_feed_status("CHAIN x%d!" % chain_depth, Color(1.0, 0.5, 0.0))

	_check_roll_combos()
	_release_roll_animation_lock(POST_ROLL_EFFECT_LOCK_DURATION)

	if turn_state == TurnState.ACTIVE and _all_dice_resolved():
		_on_bank_pressed()

func _check_roll_combos() -> void:
	if turn_state != TurnState.ACTIVE:
		return
	var combos: Array[RollCombo] = RollComboRegistry.get_triggered_combos(current_results, dice_stopped)
	for combo: RollCombo in combos:
		if combo == null or combo.combo_id.is_empty() or _triggered_combo_ids.has(combo.combo_id):
			continue
		_triggered_combo_ids[combo.combo_id] = true
		hud.flash_combo(combo.display_name, combo.flash_color, combo.combo_id)
	_update_combo_hud()


func _update_combo_hud() -> void:
	var active_combos: Array[RollCombo] = []
	var all_combos: Array[RollCombo] = RollComboRegistry.get_all_combos()
	for combo: RollCombo in all_combos:
		if combo != null and not combo.combo_id.is_empty() and _triggered_combo_ids.has(combo.combo_id):
			active_combos.append(combo)
	hud.set_active_combos(active_combos)


func _calculate_combo_bonus() -> int:
	var active_combos: Array[RollCombo] = []
	var all_combos: Array[RollCombo] = RollComboRegistry.get_all_combos()
	for combo: RollCombo in all_combos:
		if combo != null and not combo.combo_id.is_empty() and _triggered_combo_ids.has(combo.combo_id):
			active_combos.append(combo)
	return RollComboRegistry.calculate_combo_bonus(active_combos)


func _get_bust_threshold() -> int:
	return _bust_resolver.get_bust_threshold(
		BASE_BUST_THRESHOLD,
		turn_number,
		GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON),
		GameManager.has_modifier(RunModifier.ModifierType.LAST_STAND),
		GameManager.hands
	)


func _get_streak_multiplier() -> float:
	if bank_streak >= HOT_STREAK_TIER_2:
		return HOT_STREAK_MULT_2
	elif bank_streak >= HOT_STREAK_TIER_1:
		return HOT_STREAK_MULT_1
	return 1.0


## Momentum multiplier: +5% per reroll this stage.
const MOMENTUM_STEP: float = 0.05

func _get_momentum_multiplier() -> float:
	if GameManager.momentum <= 0:
		return 1.0
	return 1.0 + float(GameManager.momentum) * MOMENTUM_STEP


func _update_streak_display() -> void:
	if _streak_display != null:
		_streak_display.update_streak(bank_streak, _get_streak_multiplier())


func _get_bust_risk_text(effective_stops: int, threshold: int) -> String:
	if effective_stops == 0:
		return "Bust risk: LOW"
	elif effective_stops >= threshold - 1:
		return "Bust risk: HIGH"
	else:
		return "Bust risk: MEDIUM"


func _estimate_next_reroll_bust_chance(effective_stops: int, threshold: int) -> float:
	if _risk_estimator == null:
		_risk_estimator = BustRiskEstimatorScript.new()
	return _risk_estimator.estimate_next_reroll_bust_chance(
		effective_stops,
		threshold,
		_typed_dice_pool(),
		dice_keep,
		dice_keep_locked
	)


func _estimate_bust_odds(effective_stops: int, threshold: int) -> float:
	if _risk_estimator == null:
		_risk_estimator = BustRiskEstimatorScript.new()
	return _risk_estimator.estimate_bust_odds(
		effective_stops,
		threshold,
		_reroll_count,
		_typed_dice_pool(),
		dice_keep,
		dice_keep_locked
	)


func _typed_dice_pool() -> Array[DiceData]:
	var pool: Array[DiceData] = []
	pool.assign(GameManager.dice_pool)
	return pool


func _build_risk_details(
	effective_stops: int,
	shield_count: int,
	threshold: int,
	bust_odds: float,
	reroll_ev: float
) -> String:
	if _risk_estimator == null:
		_risk_estimator = BustRiskEstimatorScript.new()
	var rerollable_count: int = _get_rerollable_count()
	var next_roll_chance: float = _estimate_next_reroll_bust_chance(effective_stops, threshold)
	var details: String = _risk_estimator.build_risk_details(
		effective_stops,
		shield_count,
		threshold,
		next_roll_chance,
		bust_odds,
		rerollable_count,
		_reroll_count
	)
	details += "\nHeld stops: %d | Near-death banks this stage: %d | Reroll EV: %s%.1f" % [
		GameManager.held_stop_count,
		GameManager.near_death_banks_this_stage,
		"+" if reroll_ev >= 0.0 else "",
		reroll_ev,
	]
	return details


func _estimate_reroll_ev(effective_stops: int, threshold: int) -> float:
	var next_roll_chance: float = _estimate_next_reroll_bust_chance(effective_stops, threshold)
	var expected_gain: float = 0.0
	for i: int in GameManager.dice_pool.size():
		if i >= dice_keep.size() or i >= dice_keep_locked.size():
			continue
		if dice_keep[i] or dice_keep_locked[i]:
			continue
		var die_data: DiceData = GameManager.dice_pool[i]
		if die_data == null or die_data.faces.is_empty():
			continue
		expected_gain += _estimate_die_expected_value(die_data)
	var survival_chance: float = 1.0 - next_roll_chance
	return expected_gain * survival_chance - float(_calculate_turn_score()) * next_roll_chance


func _estimate_die_expected_value(die_data: DiceData) -> float:
	if die_data == null or die_data.faces.is_empty():
		return 0.0
	var total_value: float = 0.0
	for face: DiceFaceData in die_data.faces:
		if face == null:
			continue
		match face.type:
			DiceFaceData.FaceType.NUMBER, DiceFaceData.FaceType.AUTO_KEEP, DiceFaceData.FaceType.EXPLODE:
				total_value += float(face.value)
			DiceFaceData.FaceType.MULTIPLY:
				total_value += float(maxi(1, face.value))
			DiceFaceData.FaceType.SHIELD, DiceFaceData.FaceType.LUCK, DiceFaceData.FaceType.HEART:
				total_value += float(maxi(1, face.value)) * 0.6
	return total_value / float(die_data.faces.size())

## Sync the i-th PhysicsDie's visual flags to match RollPhase tracking state.
func _sync_arena_die_state(index: int) -> void:
	var die: PhysicsDie = dice_arena.get_die(index)
	if die == null:
		return
	die.is_stopped = dice_stopped[index]
	die.is_kept = dice_keep[index]
	die.is_keep_locked = dice_keep_locked[index]
	die.show_face(current_results[index])
	die._apply_visual()

# ---------------------------------------------------------------------------
# UI sync
# ---------------------------------------------------------------------------

func _sync_all_dice() -> void:
	for i: int in GameManager.dice_pool.size():
		_sync_arena_die_state(i)

func _sync_ui() -> void:
	var shield_count: int = _count_shields()
	var effective_stops: int = maxi(0, accumulated_stop_count - shield_count)
	var threshold: int = _get_bust_threshold()
	var bust_odds: float = _estimate_bust_odds(effective_stops, threshold)
	var reroll_ev: float = _estimate_reroll_ev(effective_stops, threshold)
	if turn_state == TurnState.ACTIVE and _is_high_risk_turn(effective_stops, threshold, bust_odds):
		_turn_entered_high_risk = true
	var risk_details: String = _build_risk_details(effective_stops, shield_count, threshold, bust_odds, reroll_ev)
	var turn_score: int = _calculate_turn_score()
	hud.update_turn(turn_score, effective_stops, threshold, shield_count, _reroll_count, bust_odds, risk_details, reroll_ev)
	hud.refresh_stage_rule_header()
	_refresh_risk_tower(bust_odds, effective_stops, risk_details)
	_sync_buttons()
	_refresh_contract_overlay()

	match turn_state:
		TurnState.IDLE:
			var idle_status: Dictionary = _get_idle_status_context()
			hud.set_pinned_status(
				str(idle_status.get("message", "Press 'Roll All' to begin your turn!")),
				idle_status.get("color", Color.WHITE) as Color
			)
		TurnState.ACTIVE:
			pass
		TurnState.BUST:
			pass
		TurnState.BANKED:
			pass  # Already set in _on_bank_pressed


func _get_idle_status_context() -> Dictionary:
	if GameManager.has_active_special_stage():
		return {
			"message": "SPECIAL STAGE: %s" % GameManager.get_active_special_stage_summary(),
			"color": GameManager.get_active_special_stage_color(),
			"has_stage_context": true,
		}
	if GameManager.has_current_stage_variant():
		return {
			"message": GameManager.get_current_stage_variant_hover_text(),
			"color": STAGE_VARIANT_STATUS_COLOR,
			"has_stage_context": true,
		}
	return {
		"message": "Press 'Roll All' to begin your turn!",
		"color": Color.WHITE,
		"has_stage_context": false,
	}


func _apply_contract_overlay_theme() -> void:
	pass  # Handled by ContractOverlayController.setup()


func _build_risk_tower_lights() -> void:
	pass  # Handled by RiskTowerRenderer.setup()


func _build_risk_tower_stop_dots() -> void:
	pass  # Handled by RiskTowerRenderer.setup()


func _apply_risk_tower_theme() -> void:
	pass  # Handled by RiskTowerRenderer.setup()


func _refresh_risk_tower(bust_odds: float, effective_stops: int, risk_details: String) -> void:
	if _risk_tower != null:
		_risk_tower.refresh(bust_odds, effective_stops, risk_details)


func _on_risk_tower_mouse_entered() -> void:
	pass  # Handled by RiskTowerRenderer


func _on_risk_tower_mouse_exited() -> void:
	pass  # Handled by RiskTowerRenderer


func _refresh_contract_overlay() -> void:
	if _contract_overlay_ctrl != null:
		_contract_overlay_ctrl.refresh()


func _on_loop_contract_overlay_changed(_active_contract_id: String) -> void:
	_refresh_contract_overlay()


func _on_loop_contract_overlay_progress_changed(_progress: Dictionary) -> void:
	_refresh_contract_overlay()

func _on_run_ended() -> void:
	# Capture prior bests BEFORE recording (so highlights compare against pre-run values).
	var prior_bests: Dictionary = {
		"highscore": SaveManager.get_mode_highscore(int(GameManager.run_mode)),
		"best_stages": SaveManager.total_stages_cleared,
		"best_loop": SaveManager.get_mode_best_loop(int(GameManager.run_mode)),
		"best_turn": SaveManager.career_best_turn_score,
	}
	var snapshot: RunSaveData = SaveManager.make_run_snapshot()
	_record_run_snapshot_if_needed(snapshot)
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	if turn_state == TurnState.BANKED or turn_state == TurnState.BUST:
		_pending_run_end_snapshot = snapshot
		_pending_run_end_prior_bests = prior_bests.duplicate(true)
		return
	_begin_run_end_sequence(snapshot, prior_bests)


func _has_pending_run_end_sequence() -> bool:
	return _pending_run_end_snapshot != null


func _schedule_pending_run_end_sequence(after_delay: float, effective_stops: int = -1) -> void:
	if not _has_pending_run_end_sequence():
		return
	get_tree().create_timer(maxf(after_delay, 0.0)).timeout.connect(_show_pending_run_end_sequence.bind(effective_stops), CONNECT_ONE_SHOT)


func _show_pending_run_end_sequence(effective_stops: int = -1) -> void:
	if not _has_pending_run_end_sequence():
		return
	var snapshot: RunSaveData = _pending_run_end_snapshot
	var prior_bests: Dictionary = _pending_run_end_prior_bests.duplicate(true)
	_pending_run_end_snapshot = null
	_pending_run_end_prior_bests.clear()
	if effective_stops >= 0:
		_show_bust_overlay(effective_stops, _present_run_end_highlights.bind(snapshot, prior_bests))
		return
	_begin_run_end_sequence(snapshot, prior_bests)


func _begin_run_end_sequence(snapshot: RunSaveData, prior_bests: Dictionary) -> void:
	if snapshot == null:
		return
	_show_game_over_overlay(_present_run_end_highlights.bind(snapshot, prior_bests))


func _show_game_over_overlay(on_finished: Callable = Callable()) -> void:
	var overlay: ColorRect = _spawn_run_end_overlay(false, on_finished)
	overlay.call("play", 1)
	_push_feed_status("RUN OVER — out of hands!", RUN_OVER_STATUS_COLOR)


func _spawn_run_end_overlay(should_flash_bust: bool, on_finished: Callable = Callable()) -> ColorRect:
	_shake_screen(SHAKE_BUST, 0.4)
	if should_flash_bust and _screen_overlay and _screen_overlay.has_method("flash_bust"):
		_screen_overlay.flash_bust()
	var overlay: ColorRect = BustOverlayScene.instantiate() as ColorRect
	add_child(overlay)
	if on_finished.is_valid():
		overlay.connect("finished", on_finished, CONNECT_ONE_SHOT)
	return overlay


func _present_run_end_highlights(snapshot: RunSaveData, prior_bests: Dictionary) -> void:
	if snapshot == null:
		return
	highlights_panel.show_highlights(snapshot, prior_bests)

func _on_highlights_closed() -> void:
	_set_post_run_buttons_visible(true)


func _set_post_run_buttons_visible(should_show: bool) -> void:
	var disable_buttons: bool = not should_show
	new_run_button.disabled = disable_buttons
	career_button.disabled = disable_buttons
	codex_button.disabled = disable_buttons
	_transition_surface(new_run_button, should_show)
	_transition_surface(career_button, should_show)
	_transition_surface(codex_button, should_show)


func _set_roll_surface_visible(should_show: bool, show_streak: bool = false) -> void:
	if _surface_ctrl != null:
		_surface_ctrl.set_roll_surface_visible(should_show, show_streak, _streak_display)
	else:
		if should_show and _screen_shake != null:
			_screen_shake.force_restore()
		_transition_surface(_roll_content, should_show)


func _transition_surface(surface: CanvasItem, should_show: bool) -> void:
	if _surface_ctrl != null:
		_surface_ctrl.transition_surface(surface, should_show)
		return
	if surface == null:
		return
	if should_show:
		surface.visible = true
		surface.modulate.a = 1.0
	else:
		surface.visible = false

func _on_stage_cleared() -> void:
	if _defer_stage_clear_overlay:
		_pending_stage_clear_overlay = true
		return
	_perform_stage_clear()


func _perform_stage_clear() -> void:
	AchievementManager.on_stage_cleared()
	var contract_status: String = _update_active_contract_on_stage_clear()
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	var bonus: int = GameManager.consume_next_stage_clear_gold_bonus(GameManager.get_stage_clear_bonus())
	var surplus: int = GameManager.total_score - GameManager.stage_target_score
	GameManager.add_gold(bonus)
	GameManager.purge_cluster_children_after_stage()
	SFXManager.play_stage_clear()
	var is_loop: bool = GameManager.is_final_stage()
	GameManager.reset_stage_hands()
	if contract_status != "":
		_push_feed_status(contract_status, Color(1.0, 0.88, 0.3))
	if is_loop:
		_push_feed_status(
			"LOOP %d COMPLETE! Entering Loop %d..." % [GameManager.current_loop, GameManager.current_loop + 1],
			Color(1.0, 0.85, 0.0))
	_show_stage_clear_overlay(bonus, surplus, is_loop)


func _schedule_deferred_stage_clear(after_delay: float) -> void:
	_pending_stage_clear_overlay = true
	get_tree().create_timer(maxf(after_delay, 0.0)).timeout.connect(_trigger_pending_stage_clear, CONNECT_ONE_SHOT)


func _trigger_pending_stage_clear() -> void:
	if not _pending_stage_clear_overlay:
		return
	if hud != null and hud.is_score_presentation_busy():
		# Keep stage clear in sync with the final score meter state.
		get_tree().create_timer(0.05).timeout.connect(_trigger_pending_stage_clear, CONNECT_ONE_SHOT)
		return
	_pending_stage_clear_overlay = false
	_perform_stage_clear()

func _open_shop(is_loop_complete: bool = false) -> void:
	_loop_complete_pending = is_loop_complete
	_resume_surface = RESUME_SURFACE_SHOP
	_resume_payload = {
		"stage": GameManager.current_stage,
		"is_loop_complete": is_loop_complete,
	}
	_set_roll_surface_visible(false)
	shop_panel.open(GameManager.current_stage, is_loop_complete)
	_persist_active_run_snapshot()

func _on_shop_closed() -> void:
	_transition_surface(shop_panel, false)
	# Return to the path map for the next node.
	_open_stage_map()

func _on_new_run_pressed() -> void:
	_record_run_snapshot_if_needed()
	if _screen_shake != null:
		_screen_shake.force_restore()
	_set_post_run_buttons_visible(false)
	_transition_surface(shop_panel, false)
	_set_roll_surface_visible(true, false)
	_show_archetype_picker(SaveManager.has_active_run_snapshot())


func _on_career_pressed() -> void:
	career_panel.open_panel()


func _on_career_closed() -> void:
	pass


func _on_codex_pressed() -> void:
	codex_panel.open_panel()


func _on_codex_closed() -> void:
	pass


func _on_settings_closed() -> void:
	if get_tree().paused and _settings_opened_from_pause:
		_settings_opened_from_pause = false
		pause_menu.call("open_panel")
	_sync_buttons()


func _on_locale_changed(_new_locale: String) -> void:
	_sync_buttons()
	pause_menu.call("refresh_text")


func _on_achievement_unlocked(_key: String, title: String) -> void:
	var toast: PanelContainer = AchievementToastScene.instantiate() as PanelContainer
	add_child(toast)
	toast.call("show_unlock", title)
	SFXManager.play_achievement_unlock()
	_push_feed_status("Achievement Unlocked: %s" % title, Color(1.0, 0.85, 0.0))

func _sync_buttons() -> void:
	if not _run_active:
		roll_button.disabled = true
		bank_button.disabled = true
		return
	match turn_state:
		TurnState.IDLE:
			roll_button.text     = tr("ROLL_ALL")
			roll_button.disabled = _is_roll_animating
			bank_button.disabled = true
		TurnState.ACTIVE:
			roll_button.text     = tr("REROLL_FMT").format({"value": _get_rerollable_count()})
			roll_button.disabled = _is_roll_animating
			bank_button.disabled = _is_roll_animating
		TurnState.BUST:
			roll_button.text     = tr("ROLL_ALL")
			roll_button.disabled = _is_roll_animating
			bank_button.disabled = true
		TurnState.BANKED:
			roll_button.text     = tr("ROLL_ALL")
			roll_button.disabled = true
			bank_button.disabled = true


func _open_pause_menu() -> void:
	if get_tree().paused:
		return
	_settings_opened_from_pause = false
	get_tree().paused = true
	pause_menu.call("open_panel")


func _resume_from_pause() -> void:
	_settings_opened_from_pause = false
	pause_menu.call("close_panel")
	if settings_panel.visible:
		settings_panel.close_panel()
	get_tree().paused = false
	_sync_buttons()


func _on_pause_resume_requested() -> void:
	_resume_from_pause()


func _on_pause_settings_requested() -> void:
	_settings_opened_from_pause = true
	pause_menu.call("close_panel")
	settings_panel.open_panel()


func _on_pause_quit_requested() -> void:
	_settings_opened_from_pause = false
	pause_menu.call("close_panel")
	if settings_panel.visible:
		settings_panel.close_panel()
	get_tree().paused = false
	_persist_active_run_snapshot()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _begin_roll_animation_lock() -> void:
	_is_roll_animating = true
	_roll_anim_nonce += 1
	_sync_buttons()


func _release_roll_animation_lock(delay: float = 0.0) -> void:
	var nonce: int = _roll_anim_nonce
	if delay <= 0.0:
		if nonce != _roll_anim_nonce:
			return
		_is_roll_animating = false
		_sync_buttons()
		return
	get_tree().create_timer(delay).timeout.connect(_complete_roll_animation_lock.bind(nonce))


func _complete_roll_animation_lock(nonce: int) -> void:
	if nonce != _roll_anim_nonce:
		return
	_is_roll_animating = false
	_sync_buttons()


func _get_rerollable_count() -> int:
	var count: int = 0
	for i: int in GameManager.dice_pool.size():
		if not dice_keep[i] and not dice_keep_locked[i]:
			count += 1
	return count

# ---------------------------------------------------------------------------
# Auto-advance & per-die score animation
# ---------------------------------------------------------------------------

func _schedule_auto_advance(after_delay: float = 0.0) -> void:
	if not _run_active:
		return
	var total_delay: float = after_delay + AUTO_ADVANCE_DELAY
	get_tree().create_timer(total_delay).timeout.connect(_auto_advance_turn)


func _auto_advance_turn() -> void:
	if not _run_active:
		return
	if turn_state == TurnState.BANKED or turn_state == TurnState.BUST:
		_start_new_turn()


## Play left-to-right per-die score popups, then the total score tween.
func _play_score_count_animation(old_total: int, new_total: int) -> float:
	var pool_size: int = GameManager.dice_pool.size()
	var per_die: Array[int] = _get_per_die_scores()
	hud.begin_score_feedback(old_total, new_total, _reroll_count > 0)

	# Compute which dice have a non-zero contribution.
	var scoring_indices: Array[int] = []
	for i: int in pool_size:
		if per_die[i] > 0:
			scoring_indices.append(i)
	scoring_indices = _sort_indices_by_category_and_position(scoring_indices)

	if scoring_indices.is_empty():
		hud.animate_score_count(old_total, new_total)
		hud.finish_score_feedback()
		hud.show_floating_gold(new_total - old_total)
		return 0.0

	# Time per die: start at base interval, accelerate after ACCEL_START_TIME.
	const ACCEL_START_TIME: float = 2.0
	const ACCEL_PERIOD: float = 2.0
	var base_interval: float = _score_tick_base_interval(scoring_indices.size(), pool_size)
	var tween: Tween = create_tween()
	var running: int = old_total
	var elapsed: float = 0.0
	var last_interval: float = base_interval
	for idx: int in scoring_indices.size():
		var die_i: int = scoring_indices[idx]
		var die_score: int = per_die[die_i]
		var tick_step: int = idx
		var new_running: int = running + die_score
		var _old: int = running
		var _new: int = new_running
		# Accelerate: double speed every ACCEL_PERIOD seconds after ACCEL_START_TIME.
		var interval: float = base_interval
		if elapsed > ACCEL_START_TIME:
			var accel_elapsed: float = elapsed - ACCEL_START_TIME
			var doublings: float = accel_elapsed / ACCEL_PERIOD
			interval = base_interval / pow(2.0, doublings)
			interval = maxf(interval, 0.01)  # Floor to prevent zero-delay.
		elapsed += interval
		last_interval = interval
		tween.tween_callback(
			_play_score_tick_animation.bind(die_i, die_score, tick_step, _old, _new)
		).set_delay(interval)
		running = new_running
	# After all per-die popups, show floating gold.
	tween.tween_callback(_show_floating_gold_delta.bind(new_total - old_total)).set_delay(last_interval)
	tween.tween_callback(hud.finish_score_feedback).set_delay(last_interval)
	return elapsed + last_interval


func _score_tick_base_interval(scoring_die_count: int, pool_size: int) -> float:
	var safe_scoring_count: int = maxi(scoring_die_count, 1)
	var base_interval: float = minf(0.15, MAX_SCORE_ANIM_DURATION / float(safe_scoring_count))
	var extra_dice: int = maxi(pool_size - SCORE_ANIM_SPEEDUP_THRESHOLD, 0)
	var speed_scale: float = maxf(0.55, 1.0 - float(extra_dice) * SCORE_ANIM_SPEEDUP_PER_DIE)
	return maxf(SCORE_ANIM_BASE_INTERVAL_FLOOR, base_interval * speed_scale)


func _play_score_tick_animation(die_index: int, die_score: int, tick_step: int, old_total: int, new_total: int) -> void:
	var score_die: PhysicsDie = dice_arena.get_die(die_index)
	var score_face: DiceFaceData = current_results[die_index]
	if score_die:
		var popup_color: Color = PhysicsDie.face_type_color(score_face.type) if score_face else _UITheme.SCORE_GOLD
		score_die.pop()
		hud.animate_score_transfer(score_die.global_position, die_score, old_total, new_total, popup_color)
	else:
		hud.animate_score_transfer(_get_multiplier_vfx_anchor_global_position(), die_score, old_total, new_total)
	SFXManager.play_score_tick(tick_step)


func _show_floating_gold_delta(amount: int) -> void:
	hud.show_floating_gold(amount)


## Structured bank cascade checkpoints layered on top of per-die tally.
func _play_bank_cascade_animation(old_total: int, new_total: int, multiplier: int, streak_multiplier: float) -> float:
	var anim_duration: float = _play_score_count_animation(old_total, new_total)
	var checkpoint_tween: Tween = create_tween()
	if anim_duration > 0.0:
		checkpoint_tween.tween_interval(anim_duration)
	if _triggered_combo_ids.size() > 0:
		checkpoint_tween.tween_callback(
			_show_hud_status.bind("COMBO BONUS!", _UITheme.ROSE_ACCENT)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	if multiplier > 1:
		checkpoint_tween.tween_callback(
			_show_multiplier_status.bind(multiplier)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	if streak_multiplier > 1.0:
		checkpoint_tween.tween_callback(
			_show_hot_streak_status.bind(streak_multiplier)
		).set_delay(BANK_CASCADE_STEP_DELAY)
	checkpoint_tween.tween_callback(
		_show_total_locked_status.bind(new_total)
	).set_delay(BANK_CASCADE_STEP_DELAY)
	return _get_bank_cascade_total_duration(anim_duration, multiplier, streak_multiplier)


func _get_bank_cascade_total_duration(base_duration: float, multiplier: int, streak_multiplier: float) -> float:
	var step_count: int = 1
	if _triggered_combo_ids.size() > 0:
		step_count += 1
	if multiplier > 1:
		step_count += 1
	if streak_multiplier > 1.0:
		step_count += 1
	return base_duration + float(step_count) * BANK_CASCADE_STEP_DELAY


func _show_hud_status(message: String, color: Color) -> void:
	_push_feed_status(message, color)


func _show_multiplier_status(multiplier: int) -> void:
	_push_feed_status("MULTIPLIER x%d!" % multiplier, _UITheme.SCORE_GOLD)
	SFXManager.play_score_tick()


func _show_hot_streak_status(streak_multiplier: float) -> void:
	_push_feed_status("HOT STREAK x%.1f!" % streak_multiplier, _UITheme.EXPLOSION_ORANGE)


func _show_total_locked_status(new_total: int) -> void:
	_push_feed_status("TOTAL LOCKED: %d" % new_total, _UITheme.SUCCESS_GREEN)


func _push_feed_status(message: String, color: Color) -> void:
	var trimmed_message: String = message.strip_edges()
	if trimmed_message.is_empty():
		return
	hud.push_event_effect(trimmed_message, color)


func _publish_bank_score_feed(
	combo_bonus: int,
	streak_multiplier: float,
	momentum_multiplier: float,
	special_score_bonus: int,
	banked_score: int
) -> void:
	if combo_bonus > 0:
		hud.push_score_causality_tag("Combo", "+%d" % combo_bonus, _UITheme.ROSE_ACCENT)
	if streak_multiplier > 1.0:
		hud.push_score_causality_tag("Streak", "x%.1f" % streak_multiplier, _UITheme.EXPLOSION_ORANGE)
	if momentum_multiplier > 1.0:
		hud.push_score_causality_tag("Momentum", "x%.2f" % momentum_multiplier, _UITheme.ACTION_CYAN)
	if special_score_bonus > 0:
		hud.push_score_causality_tag("Rule Bonus", "+%d" % special_score_bonus, _UITheme.STATUS_HIGHLIGHT)
	hud.push_score_causality_tag("Banked", "+%d" % banked_score, _UITheme.SUCCESS_GREEN)


func _play_multiply_face_vfx() -> void:
	if _vfx == null:
		return
	var anchor: Vector2 = _get_multiplier_vfx_anchor_global_position()
	_vfx.play_multiply_face_vfx(GameManager.dice_pool, current_results, dice_stopped, anchor)


func _get_multiplier_vfx_anchor_global_position() -> Vector2:
	if hud != null and hud.has_method("get_progress_visual_rect"):
		var progress_rect: Rect2 = hud.get_progress_visual_rect()
		return Vector2(progress_rect.position.x - RollPhaseVFX.MULTIPLIER_BURST_BAR_OFFSET, progress_rect.position.y + progress_rect.size.y * 0.5)
	if hud != null and hud.progress_bar != null:
		return hud.progress_bar.global_position + Vector2(-RollPhaseVFX.MULTIPLIER_BURST_BAR_OFFSET, hud.progress_bar.size.y * 0.5)
	var arena_origin: Vector2 = _arena_viewport_container.global_position
	var arena_size: Vector2 = _arena_viewport_container.size
	return arena_origin + Vector2(RollPhaseVFX.MULTIPLIER_BURST_BAR_OFFSET, arena_size.y * 0.5)


func _spawn_multiplier_burst(burst_position: Vector2, multiplier: int, is_stop_multiplier: bool) -> void:
	if _vfx != null:
		_vfx._spawn_multiplier_burst(burst_position, multiplier, is_stop_multiplier)


## Compute effective per-die score contributions after proximity multipliers.
func _get_per_die_scores() -> Array[int]:
	return _turn_score_service.calculate_per_die_scores(
		current_results,
		dice_stopped,
		_get_die_positions(),
		_get_multiplies_stops_flags(),
		_was_displaced,
		GameManager.has_modifier(RunModifier.ModifierType.SHRAPNEL),
		GameManager.has_modifier(RunModifier.ModifierType.GLASS_CANNON),
		GameManager.has_modifier(RunModifier.ModifierType.HIGH_ROLLER),
		GameManager.has_modifier(RunModifier.ModifierType.OVERCHARGE)
	)


func _get_die_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	positions.resize(GameManager.dice_pool.size())
	for i: int in GameManager.dice_pool.size():
		var die: PhysicsDie = dice_arena.get_die(i)
		positions[i] = die.global_position if die != null else Vector2(float(i) * PhysicsDie.DIE_SIZE, 0.0)
	return positions


func _get_multiplies_stops_flags() -> Array[bool]:
	var flags: Array[bool] = []
	flags.resize(GameManager.dice_pool.size())
	for i: int in GameManager.dice_pool.size():
		var die_data: DiceData = GameManager.dice_pool[i]
		flags[i] = die_data != null and die_data.multiplies_stops
	return flags


func _sort_indices_by_category_and_position(indices: Array[int]) -> Array[int]:
	var sorted_indices: Array[int] = _copy_int_array(indices)
	sorted_indices.sort_custom(func(a: int, b: int) -> bool:
		var die_a_data: DiceData = GameManager.dice_pool[a] if a >= 0 and a < GameManager.dice_pool.size() else null
		var die_b_data: DiceData = GameManager.dice_pool[b] if b >= 0 and b < GameManager.dice_pool.size() else null
		var a_category: int = int(die_a_data.category) if die_a_data != null else int(DiceData.DieCategory.NORMAL)
		var b_category: int = int(die_b_data.category) if die_b_data != null else int(DiceData.DieCategory.NORMAL)
		if a_category != b_category:
			return a_category < b_category
		var die_a: PhysicsDie = dice_arena.get_die(a)
		var die_b: PhysicsDie = dice_arena.get_die(b)
		var a_x: float = die_a.global_position.x if die_a != null else float(a)
		var b_x: float = die_b.global_position.x if die_b != null else float(b)
		return a_x < b_x
	)
	return sorted_indices


func _copy_int_array(values: Variant) -> Array[int]:
	var typed_values: Array[int] = []
	if values is Array:
		for value: Variant in values:
			typed_values.append(int(value))
	return typed_values

# ---------------------------------------------------------------------------
# Juice overlays
# ---------------------------------------------------------------------------

func _spawn_jackpot_confetti() -> void:
	if _vfx != null:
		_vfx.spawn_jackpot_confetti()


func _queue_free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


func _show_bust_overlay(effective_stops: int, on_finished: Callable = Callable()) -> void:
	var overlay: ColorRect = _spawn_run_end_overlay(true, on_finished)
	overlay.call("play", 1)
	hud.show_status("BUST! %d stops — turn score lost!" % effective_stops, Color(0.9, 0.2, 0.2))


func _shake_screen(intensity: float, duration: float) -> void:
	if _vfx != null:
		_vfx.shake_screen(intensity, duration)


func _on_intro_card_slotted(card_kind: String) -> void:
	var intensity: float = INTRO_CARD_RULE_SLOT_SHAKE
	if card_kind == "target":
		intensity = INTRO_CARD_TARGET_SLOT_SHAKE
	_shake_screen(intensity, INTRO_CARD_SLOT_SHAKE_DURATION)
	SFXManager.play_ui_slot(card_kind == "target")


func _add_button_micro_tween(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func() -> void:
		if btn.disabled:
			return
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(BUTTON_HOVER_SCALE, BUTTON_HOVER_SCALE), BUTTON_TWEEN_DURATION).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, BUTTON_TWEEN_DURATION).set_ease(Tween.EASE_IN)
	)
	btn.button_down.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2(BUTTON_PRESS_SCALE, BUTTON_PRESS_SCALE), BUTTON_TWEEN_DURATION * 0.6).set_ease(Tween.EASE_OUT)
	)
	btn.button_up.connect(func() -> void:
		var t: Tween = btn.create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, BUTTON_TWEEN_DURATION).set_ease(Tween.EASE_IN)
	)


func _show_stage_clear_overlay(bonus_gold: int, surplus: int, is_loop: bool) -> void:
	var overlay: ColorRect = StageClearedScene.instantiate() as ColorRect
	add_child(overlay)
	overlay.call("setup", bonus_gold, surplus, is_loop)
	overlay.connect("proceed_requested", _on_stage_clear_overlay_proceed.bind(overlay))


func _on_stage_clear_overlay_proceed(overlay: ColorRect) -> void:
	_queue_free_if_valid(overlay)
	_show_dice_reward()


func _show_dice_reward() -> void:
	var reward_overlay: ColorRect = DiceRewardScene.instantiate() as ColorRect
	add_child(reward_overlay)
	reward_overlay.call("open", GameManager.luck)
	reward_overlay.connect("reward_chosen", _on_reward_chosen)


func _on_reward_chosen(die: DiceData) -> void:
	GameManager.add_dice(die)
	_open_stage_map()


func _maybe_open_forge(is_loop: bool) -> void:
	if GameManager.dice_pool.size() >= ForgePanel.MIN_DICE_FOR_FORGE and GameManager.rng_randf("misc") < ForgePanel.FORGE_CHANCE:
		_loop_complete_pending = is_loop
		_resume_surface = RESUME_SURFACE_FORGE
		_resume_payload.clear()
		_set_roll_surface_visible(false)
		forge_panel.open()
		_persist_active_run_snapshot()
	else:
		_open_shop(is_loop)


func _on_forge_closed() -> void:
	_transition_surface(forge_panel, false)
	# After forge, return to the path map for next row.
	_open_stage_map()


func _show_stage_event() -> void:
	_resume_surface = RESUME_SURFACE_EVENT
	_resume_payload.clear()
	var event_overlay: ColorRect = StageEventScene.instantiate() as ColorRect
	_active_event_overlay = event_overlay
	add_child(event_overlay)
	event_overlay.call("open")
	event_overlay.connect("event_resolved", _on_stage_event_resolved.bind(event_overlay))
	_persist_active_run_snapshot()


func _on_stage_event_resolved(summary: String, status_color: Color, event_overlay: ColorRect) -> void:
	if _active_event_overlay == event_overlay:
		_active_event_overlay = null
	_queue_free_if_valid(event_overlay)
	if summary != "":
		_push_feed_status(summary, status_color)
	_open_stage_map()


# ---------------------------------------------------------------------------
# Path map
# ---------------------------------------------------------------------------

const REST_HEAL_LIVES: int = 1
const REST_GOLD_BONUS: int = 10

func _open_stage_map() -> void:
	GameManager.reset_luck()
	_resume_surface = RESUME_SURFACE_STAGE_MAP
	_resume_payload.clear()
	if GameManager.stage_map == null:
		GameManager.generate_stage_map()
	# Check if we've completed all rows (loop complete).
	if GameManager.current_row >= StageMapDataScript.ROWS_PER_LOOP:
		_complete_loop()
		return
	_set_roll_surface_visible(false)
	stage_map_panel.open(
		GameManager.stage_map,
		GameManager.current_row,
		GameManager.previous_col,
		GameManager.prestige_reroute_uses
	)
	_persist_active_run_snapshot()


func _on_map_node_selected(row: int, col: int, node: MapNodeData, used_reroute: bool) -> void:
	if used_reroute:
		GameManager.use_reroute_token()
		_push_feed_status("REROUTE SPENT! Path broken for this pick.", Color(1.0, 0.72, 0.35))
	var selected_node: MapNodeData = node
	if selected_node == null and GameManager.stage_map != null:
		selected_node = GameManager.stage_map.get_node_at(row, col)
	_stage_flow.advance_row(col)
	_transition_surface(stage_map_panel, false)
	var node_type: MapNodeData.NodeType = MapNodeData.NodeType.NORMAL_STAGE
	if node != null:
		node_type = node.type
	match node_type:
		MapNodeData.NodeType.NORMAL_STAGE:
			_start_stage_from_map(selected_node)
		MapNodeData.SPECIAL_STAGE_TYPE:
			_start_stage_from_map(selected_node, selected_node.special_rule_id if selected_node != null else "")
		MapNodeData.NodeType.SHOP:
			_open_shop_from_map()
		MapNodeData.NodeType.FORGE:
			_open_forge_from_map()
		MapNodeData.NodeType.REST:
			_execute_rest_node()
		MapNodeData.NodeType.RANDOM_EVENT:
			_show_stage_event()


func _start_stage_from_map(stage_node: MapNodeData = null, special_rule_id: String = "") -> void:
	_stage_flow.begin_stage_from_map(stage_node)
	_reset_stage_contract_trackers()
	_stage_starting_stop_pressure = GameManager.consume_next_stage_starting_stop_pressure()
	if special_rule_id != "":
		GameManager.enter_special_stage(special_rule_id)
	hud.refresh_stage_rule_header()
	var stage_status: Dictionary = _get_idle_status_context()
	hud.set_pinned_status(
		str(stage_status.get("message", "Press 'Roll All' to begin your turn!")),
		stage_status.get("color", Color.WHITE) as Color
	)
	hud.play_stage_intro_cards()
	_set_roll_surface_visible(true, false)
	_update_streak_display()
	_run_active = true
	turn_number = 0
	bank_streak = 0
	_update_streak_display()
	_start_new_turn()


func _open_shop_from_map() -> void:
	_loop_complete_pending = false
	_resume_surface = RESUME_SURFACE_SHOP
	_resume_payload = {
		"stage": GameManager.current_stage,
		"is_loop_complete": false,
	}
	_set_roll_surface_visible(false)
	shop_panel.open(GameManager.current_stage, false)
	_persist_active_run_snapshot()


func _open_forge_from_map() -> void:
	if GameManager.dice_pool.size() >= ForgePanel.MIN_DICE_FOR_FORGE:
		_resume_surface = RESUME_SURFACE_FORGE
		_resume_payload.clear()
		_set_roll_surface_visible(false)
		forge_panel.open()
		_persist_active_run_snapshot()
	else:
		# Not enough dice for forge — open map for next node.
		_push_feed_status("Not enough dice to forge (need %d)." % ForgePanel.MIN_DICE_FOR_FORGE, Color(1.0, 0.6, 0.0))
		_open_stage_map()


func _execute_rest_node() -> void:
	var lives_before: int = GameManager.lives
	_stage_flow.apply_rest_rewards(REST_HEAL_LIVES, REST_GOLD_BONUS)
	var lives_after: int = GameManager.lives
	_push_feed_status("Rested! +%d hand, +%dg" % [REST_HEAL_LIVES, REST_GOLD_BONUS], Color(0.3, 1.0, 0.3))
	SFXManager.play_stage_clear()
	_show_rest_overlay(lives_before, lives_after)


func _show_rest_overlay(lives_before: int, lives_after: int) -> void:
	_resume_surface = RESUME_SURFACE_REST
	_resume_payload = {
		"heal_lives": REST_HEAL_LIVES,
		"gold_bonus": REST_GOLD_BONUS,
		"lives_before": lives_before,
		"lives_after": lives_after,
	}
	var overlay: ColorRect = RestOverlayScene.instantiate() as ColorRect
	_active_rest_overlay = overlay
	add_child(overlay)
	overlay.call("open", REST_HEAL_LIVES, REST_GOLD_BONUS, lives_before, lives_after)
	overlay.connect("continue_requested", _on_rest_overlay_continue.bind(overlay))
	_persist_active_run_snapshot()


func _on_rest_overlay_continue(overlay: ColorRect) -> void:
	if _active_rest_overlay == overlay:
		_active_rest_overlay = null
	_queue_free_if_valid(overlay)
	_open_stage_map()


func _complete_loop() -> void:
	_stage_flow.complete_loop()
	_reset_stage_contract_trackers()
	AchievementManager.on_loop_advanced(GameManager.current_loop)
	_maybe_apply_curse()
	_push_feed_status(
		"LOOP %d COMPLETE! Entering Loop %d..." % [GameManager.current_loop - 1, GameManager.current_loop],
		Color(1.0, 0.85, 0.0))
	_begin_loop_contract_flow(ContractContinuation.OPEN_STAGE_MAP)


# ---------------------------------------------------------------------------
# Curse event
# ---------------------------------------------------------------------------

const CURSE_CHANCE: float = 0.2

func _maybe_apply_curse() -> void:
	if GameManager.rng_randf("misc") >= CURSE_CHANCE:
		return
	if GameManager.dice_pool.is_empty():
		return
	# Pick a random die and replace one non-CURSED_STOP face with CURSED_STOP.
	var die_index: int = GameManager.rng_pick_index("misc", GameManager.dice_pool.size())
	if die_index < 0:
		return
	var die: DiceData = GameManager.dice_pool[die_index]
	var candidates: Array[int] = []
	for i: int in die.faces.size():
		if die.faces[i].type != DiceFaceData.FaceType.CURSED_STOP:
			candidates.append(i)
	if candidates.is_empty():
		return
	var target_index: int = GameManager.rng_pick_index("misc", candidates.size())
	if target_index < 0:
		return
	var target: int = candidates[target_index]
	die.faces[target].type = DiceFaceData.FaceType.CURSED_STOP
	die.faces[target].value = 0
	_push_feed_status("CURSED! %s gained a ☠STOP face!" % die.dice_name, Color(0.6, 0.0, 0.6))

# ---------------------------------------------------------------------------
# Archetype picker
# ---------------------------------------------------------------------------

func _show_archetype_picker(can_continue: bool = false) -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	var picker: ColorRect = ArchetypePickerScene.instantiate() as ColorRect
	add_child(picker)
	picker.call("open", int(GameManager.run_mode), can_continue)
	picker.connect("selection_confirmed", _on_archetype_selected)


func _on_archetype_selected(run_mode: int, archetype: int, seeded: bool, seed_text: String, continue_run: bool) -> void:
	if continue_run:
		_resume_active_run()
		return
	_start_new_fresh_run(run_mode, archetype, seeded, seed_text)


func _start_new_fresh_run(run_mode: int, archetype: int, seeded: bool, seed_text: String) -> void:
	GameManager.begin_new_run(run_mode, archetype as GameManager.Archetype, seeded, seed_text)
	SaveManager.clear_active_run_snapshot()
	_run_snapshot_recorded = false
	_run_active = true
	_begin_loop_contract_flow(ContractContinuation.START_TURN)


func _resume_active_run() -> void:
	var snapshot: Resource = SaveManager.get_active_run_snapshot()
	if snapshot == null:
		_start_new_fresh_run(int(GameManager.run_mode), int(GameManager.chosen_archetype), false, "")
		return
	GameManager.restore_run_identity(
		snapshot.run_seed_text,
		snapshot.is_seeded_run,
		snapshot.seed_version,
		snapshot.rng_stream_states
	)
	GameManager.apply_active_run_state(snapshot.game_manager_state)
	_restore_roll_phase_state(snapshot.roll_phase_state)
	_run_snapshot_recorded = false
	SaveManager.clear_active_run_snapshot()
	_resume_surface = snapshot.resume_surface
	_resume_payload = snapshot.resume_payload.duplicate(true)
	_restore_resume_surface()


func _begin_loop_contract_flow(continuation: int) -> void:
	var offer_count: int = 4 if SaveManager.has_permanent_upgrade("contract_scout") else 3
	var offers: Array[LoopContractDataType] = LoopContractCatalogScript.get_random_offers_for_loop(GameManager.current_loop, offer_count)
	if offers.is_empty():
		_continue_after_contract_selection(continuation)
		return
	var offered_ids: Array[String] = []
	for offer: LoopContractDataType in offers:
		offered_ids.append(offer.contract_id)
	GameManager.set_offered_loop_contract_ids(offered_ids)
	if GameManager.skip_archetype_picker:
		_apply_selected_loop_contract(offers[0].contract_id, continuation)
		return
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	var panel: ColorRect = ContractSelectionPanelScene.instantiate() as ColorRect
	add_child(panel)
	panel.call("open", GameManager.current_loop, offers)
	panel.connect("contract_selected", _on_loop_contract_selected.bind(continuation))


func _on_loop_contract_selected(contract_id: String, continuation: int) -> void:
	_apply_selected_loop_contract(contract_id, continuation)


func _apply_selected_loop_contract(contract_id: String, continuation: int) -> void:
	GameManager.activate_loop_contract(contract_id)
	var contract: LoopContractDataType = LoopContractCatalogScript.get_by_id(contract_id)
	if contract != null:
		_push_feed_status("Loop Contract: %s" % contract.display_name, Color(0.35, 0.92, 1.0))
	_continue_after_contract_selection(continuation)


func _continue_after_contract_selection(continuation: int) -> void:
	_run_active = true
	if continuation == ContractContinuation.START_TURN:
		turn_number = 0
		bank_streak = 0
		_reset_stage_contract_trackers()
		_update_streak_display()
		_start_new_turn()
	else:
		_open_stage_map()


func _reset_stage_contract_trackers() -> void:
	_stage_had_bust = false
	_turn_entered_high_risk = false


func _is_high_risk_turn(effective_stops: int, threshold: int, bust_odds: float) -> bool:
	return effective_stops >= threshold - 1 or bust_odds >= HIGH_RISK_ODDS_THRESHOLD


func _update_active_contract_on_bank(context: Dictionary) -> String:
	var contract_id: String = GameManager.active_loop_contract_id
	if contract_id.is_empty() or _contract_progress_service == null:
		return ""
	var old_progress: Dictionary = GameManager.active_loop_contract_progress.duplicate(true)
	var new_progress: Dictionary = _contract_progress_service.on_bank(contract_id, old_progress, context)
	return _commit_active_contract_progress(contract_id, old_progress, new_progress)


func _update_active_contract_on_bust() -> void:
	var contract_id: String = GameManager.active_loop_contract_id
	if contract_id.is_empty() or _contract_progress_service == null:
		return
	var progress: Dictionary = _contract_progress_service.on_bust(
		contract_id,
		GameManager.active_loop_contract_progress,
		{"stage_had_bust": _stage_had_bust}
	)
	if not progress.is_empty():
		GameManager.update_loop_contract_progress(progress)


func _update_active_contract_on_stage_clear() -> String:
	var contract_id: String = GameManager.active_loop_contract_id
	if contract_id.is_empty() or _contract_progress_service == null:
		return ""
	var old_progress: Dictionary = GameManager.active_loop_contract_progress.duplicate(true)
	var new_progress: Dictionary = _contract_progress_service.on_stage_clear(
		contract_id,
		old_progress,
		{"stage_had_bust": _stage_had_bust}
	)
	return _commit_active_contract_progress(contract_id, old_progress, new_progress)


func _commit_active_contract_progress(contract_id: String, old_progress: Dictionary, new_progress: Dictionary) -> String:
	if new_progress.is_empty():
		return ""
	GameManager.update_loop_contract_progress(new_progress)
	var was_completed: bool = bool(old_progress.get("completed", false))
	var is_completed: bool = bool(new_progress.get("completed", false))
	if was_completed or not is_completed:
		return ""
	var contract: LoopContractDataType = LoopContractCatalogScript.get_by_id(contract_id)
	if contract == null:
		return ""
	_apply_contract_reward(contract)
	return "CONTRACT COMPLETE: %s" % contract.display_name


func _apply_contract_reward(contract: LoopContractDataType) -> void:
	if contract.reward_gold > 0:
		GameManager.add_gold(contract.reward_gold)
	if contract.reward_exp > 0:
		GameManager.add_run_exp(contract.reward_exp)
	if contract.reward_stop_shards > 0:
		GameManager.add_run_stop_shards(contract.reward_stop_shards)


func _persist_active_run_snapshot() -> void:
	if _run_snapshot_recorded:
		SaveManager.clear_active_run_snapshot()
		return
	if _is_picker_open() or GameManager.dice_pool.is_empty() or GameManager.lives <= 0:
		return
	var resume_payload: Dictionary = _build_resume_payload_snapshot()
	var roll_phase_state: Dictionary = _build_roll_phase_state()
	var snapshot: Resource = SaveManager.build_active_run_snapshot(_resume_surface, resume_payload, roll_phase_state)
	SaveManager.save_active_run_snapshot(snapshot)


func _is_picker_open() -> bool:
	for child: Node in get_children():
		if child is ArchetypePicker:
			return true
	return false


func _build_resume_payload_snapshot() -> Dictionary:
	var payload: Dictionary = _resume_payload.duplicate(true)
	match _resume_surface:
		RESUME_SURFACE_SHOP:
			if shop_panel.visible and shop_panel.has_method("build_resume_snapshot"):
				payload["shop_state"] = shop_panel.call("build_resume_snapshot") as Dictionary
		RESUME_SURFACE_EVENT:
			if _active_event_overlay != null and is_instance_valid(_active_event_overlay) and _active_event_overlay.has_method("build_resume_snapshot"):
				payload["event_state"] = _active_event_overlay.call("build_resume_snapshot") as Dictionary
	return payload


func _build_roll_phase_state() -> Dictionary:
	if _resume_surface == RESUME_SURFACE_TURN:
		return _build_turn_checkpoint_roll_phase_state()
	return _snapshot_service.build_roll_phase_state({
		"turn_state": int(turn_state),
		"turn_number": turn_number,
		"accumulated_stop_count": accumulated_stop_count,
		"accumulated_shield_count": accumulated_shield_count,
		"run_active": _run_active,
		"loop_complete_pending": _loop_complete_pending,
		"bank_streak": bank_streak,
		"reroll_count": _reroll_count,
		"run_snapshot_recorded": _run_snapshot_recorded,
		"triggered_combo_ids": _triggered_combo_ids,
		"stage_had_bust": _stage_had_bust,
		"turn_entered_high_risk": _turn_entered_high_risk,
		"current_results": current_results,
		"dice_stopped": dice_stopped,
		"dice_keep": dice_keep,
		"dice_keep_locked": dice_keep_locked,
		"die_reroll_counts": _die_reroll_counts,
		"was_displaced": _was_displaced,
		"cluster_child_flags": _cluster_child_flags,
	})


func _build_turn_checkpoint_roll_phase_state() -> Dictionary:
	return _snapshot_service.build_turn_checkpoint_state({
		"dice_count": GameManager.dice_pool.size(),
		"turn_number": turn_number,
		"loop_complete_pending": _loop_complete_pending,
		"bank_streak": bank_streak,
		"run_snapshot_recorded": _run_snapshot_recorded,
		"stage_had_bust": _stage_had_bust,
	})


func _restore_roll_phase_state(data: Dictionary) -> void:
	var expected_count: int = GameManager.dice_pool.size()
	var restored: Dictionary = _snapshot_service.restore_roll_phase_state(data, expected_count)

	turn_state = int(restored.get("turn_state", int(TurnState.IDLE))) as TurnState
	turn_number = int(restored.get("turn_number", 0))
	accumulated_stop_count = int(restored.get("accumulated_stop_count", 0))
	accumulated_shield_count = int(restored.get("accumulated_shield_count", 0))
	_run_active = bool(restored.get("run_active", true))
	_loop_complete_pending = bool(restored.get("loop_complete_pending", false))
	bank_streak = int(restored.get("bank_streak", 0))
	_reroll_count = int(restored.get("reroll_count", 0))
	_run_snapshot_recorded = bool(restored.get("run_snapshot_recorded", false))
	_triggered_combo_ids = restored.get("triggered_combo_ids", {}) as Dictionary
	_stage_had_bust = bool(restored.get("stage_had_bust", false))
	_turn_entered_high_risk = bool(restored.get("turn_entered_high_risk", false))
	current_results = restored.get("current_results", []) as Array[DiceFaceData]
	dice_stopped = restored.get("dice_stopped", []) as Array[bool]
	dice_keep = restored.get("dice_keep", []) as Array[bool]
	dice_keep_locked = restored.get("dice_keep_locked", []) as Array[bool]
	_die_reroll_counts = restored.get("die_reroll_counts", []) as Array[int]
	_was_displaced = restored.get("was_displaced", []) as Array[bool]
	_cluster_child_flags = restored.get("cluster_child_flags", []) as Array[bool]

	_is_roll_animating = false
	_roll_anim_nonce += 1
	_update_combo_hud()
	_update_streak_display()
	GameManager.set_held_stop_count(_count_intentionally_held_stops())


func _serialize_face_array(faces: Array[DiceFaceData]) -> Array:
	return _snapshot_service.serialize_face_array(faces)


func _deserialize_face_array(data: Array) -> Array[DiceFaceData]:
	return _snapshot_service.deserialize_face_array(data)


func _restore_resume_surface() -> void:
	match _resume_surface:
		RESUME_SURFACE_SHOP:
			_restore_shop_surface()
		RESUME_SURFACE_EVENT:
			_restore_event_surface()
		RESUME_SURFACE_FORGE:
			_restore_forge_surface()
		RESUME_SURFACE_REST:
			_restore_rest_surface()
		RESUME_SURFACE_STAGE_MAP:
			_restore_stage_map_surface()
		_:
			_restore_turn_surface()


func _restore_turn_surface() -> void:
	_run_active = true
	_set_roll_surface_visible(true, true)
	_transition_surface(shop_panel, false)
	_transition_surface(forge_panel, false)
	_transition_surface(stage_map_panel, false)
	_apply_turn_checkpoint_after_resume()
	dice_arena.reset()
	_sync_all_dice()
	_sync_ui()
	_sync_buttons()


func _apply_turn_checkpoint_after_resume() -> void:
	turn_state = TurnState.IDLE
	accumulated_stop_count = 0
	accumulated_shield_count = 0
	_stage_starting_stop_pressure = 0
	_reroll_count = 0
	_turn_entered_high_risk = false
	_triggered_combo_ids.clear()
	hud.set_active_combos([])
	_is_roll_animating = false
	_roll_anim_nonce += 1
	var dice_count: int = GameManager.dice_pool.size()
	current_results.resize(dice_count)
	current_results.fill(null)
	dice_stopped.resize(dice_count)
	dice_stopped.fill(false)
	dice_keep.resize(dice_count)
	dice_keep.fill(false)
	dice_keep_locked.resize(dice_count)
	dice_keep_locked.fill(false)
	_die_reroll_counts.resize(dice_count)
	_die_reroll_counts.fill(0)
	_was_displaced.resize(dice_count)
	_was_displaced.fill(false)
	_cluster_child_flags.resize(dice_count)
	_cluster_child_flags.fill(false)
	GameManager.set_held_stop_count(0)


func _restore_stage_map_surface() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	_set_roll_surface_visible(false)
	if GameManager.stage_map == null:
		GameManager.generate_stage_map()
	stage_map_panel.open(
		GameManager.stage_map,
		GameManager.current_row,
		GameManager.previous_col,
		GameManager.prestige_reroute_uses
	)


func _restore_shop_surface() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	_set_roll_surface_visible(false)
	_transition_surface(stage_map_panel, false)
	_transition_surface(forge_panel, false)
	var shop_state: Dictionary = _resume_payload.get("shop_state", {}) as Dictionary
	if not shop_state.is_empty() and shop_panel.has_method("open_from_resume"):
		shop_panel.call("open_from_resume", shop_state)
		return
	var stage_value: int = int(_resume_payload.get("stage", GameManager.current_stage))
	var is_loop_complete: bool = bool(_resume_payload.get("is_loop_complete", false))
	shop_panel.open(stage_value, is_loop_complete)


func _restore_event_surface() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	_set_roll_surface_visible(false)
	_transition_surface(stage_map_panel, false)
	_transition_surface(forge_panel, false)
	var event_overlay: ColorRect = StageEventScene.instantiate() as ColorRect
	_active_event_overlay = event_overlay
	add_child(event_overlay)
	var event_state: Dictionary = _resume_payload.get("event_state", {}) as Dictionary
	if event_state.is_empty():
		event_overlay.call("open")
	else:
		event_overlay.call("open_from_resume", event_state)
	event_overlay.connect("event_resolved", _on_stage_event_resolved.bind(event_overlay))


func _restore_forge_surface() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	_set_roll_surface_visible(false)
	_transition_surface(stage_map_panel, false)
	_transition_surface(shop_panel, false)
	forge_panel.open()


func _restore_rest_surface() -> void:
	_run_active = false
	roll_button.disabled = true
	bank_button.disabled = true
	_set_roll_surface_visible(false)
	_transition_surface(stage_map_panel, false)
	_transition_surface(shop_panel, false)
	_transition_surface(forge_panel, false)
	var overlay: ColorRect = RestOverlayScene.instantiate() as ColorRect
	_active_rest_overlay = overlay
	add_child(overlay)
	overlay.call(
		"open",
		int(_resume_payload.get("heal_lives", REST_HEAL_LIVES)),
		int(_resume_payload.get("gold_bonus", REST_GOLD_BONUS)),
		int(_resume_payload.get("lives_before", GameManager.lives)),
		int(_resume_payload.get("lives_after", GameManager.lives))
	)
	overlay.connect("continue_requested", _on_rest_overlay_continue.bind(overlay))


func _record_run_snapshot_if_needed(snapshot: RunSaveData = null) -> void:
	if _run_snapshot_recorded:
		return
	if snapshot == null:
		snapshot = SaveManager.make_run_snapshot()
	SaveManager.record_run(snapshot)
	SaveManager.clear_active_run_snapshot()
	AchievementManager.on_run_recorded(snapshot)
	_run_snapshot_recorded = true
