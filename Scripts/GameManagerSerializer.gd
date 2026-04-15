class_name GameManagerSerializer
extends RefCounted
## Serializes and deserializes DiceData pools and RunModifier arrays for
## save / resume.  Pure data marshalling — no GameManager state dependency.

const DiceData := preload("res://Scripts/DiceData.gd")
const DiceFaceData := preload("res://Scripts/DiceFaceData.gd")
const RunModifier := preload("res://Scripts/RunModifier.gd")


# ── Dice Pool ─────────────────────────────────────────────────────────────

func serialize_dice_pool(pool: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for die: Variant in pool:
		serialized.append(serialize_die(die))
	return serialized


func deserialize_dice_pool(raw_data: Array) -> Array:
	var deserialized: Array = []
	for die_data: Variant in raw_data:
		if die_data is Dictionary:
			deserialized.append(deserialize_die(die_data as Dictionary))
	return deserialized


func serialize_die(die: Variant) -> Dictionary:
	var faces_data: Array[Dictionary] = []
	for face: Variant in die.faces:
		faces_data.append({
			"type": int(face.type),
			"value": face.value,
		})
	return {
		"dice_name": die.dice_name,
		"faces": faces_data,
		"custom_color": die.custom_color.to_html(true),
		"rarity": int(die.rarity),
		"category": int(die.category),
		"multiplies_stops": die.multiplies_stops,
		"is_cluster": die.is_cluster,
		"cluster_generation": die.cluster_generation,
		"max_cluster_depth": die.max_cluster_depth,
		"reroll_family_id": die.reroll_family_id,
		"reroll_tier": die.reroll_tier,
		"reroll_upgrade_thresholds": die.reroll_upgrade_thresholds.duplicate(),
		"reroll_affinity_locked": die.reroll_affinity_locked,
	}


func deserialize_die(data: Dictionary) -> Variant:
	var die := DiceData.new()
	die.dice_name = str(data.get("dice_name", "Standard D6"))
	die.custom_color = Color(str(data.get("custom_color", Color.TRANSPARENT.to_html(true))))
	die.rarity = int(data.get("rarity", int(DiceData.Rarity.GREY))) as DiceData.Rarity
	die.category = int(data.get("category", int(DiceData.DieCategory.NORMAL))) as DiceData.DieCategory
	die.multiplies_stops = bool(data.get("multiplies_stops", false))
	die.is_cluster = bool(data.get("is_cluster", false))
	die.cluster_generation = int(data.get("cluster_generation", 0))
	die.max_cluster_depth = int(data.get("max_cluster_depth", 0))
	die.reroll_family_id = str(data.get("reroll_family_id", ""))
	die.reroll_tier = int(data.get("reroll_tier", 0))
	die.reroll_upgrade_thresholds.clear()
	for threshold: Variant in data.get("reroll_upgrade_thresholds", []) as Array:
		die.reroll_upgrade_thresholds.append(int(threshold))
	die.reroll_affinity_locked = bool(data.get("reroll_affinity_locked", false))
	die.faces.clear()
	for face_data: Variant in data.get("faces", []) as Array:
		if not (face_data is Dictionary):
			continue
		var face := DiceFaceData.new()
		face.type = int((face_data as Dictionary).get("type", int(DiceFaceData.FaceType.BLANK))) as DiceFaceData.FaceType
		face.value = int((face_data as Dictionary).get("value", 0))
		die.faces.append(face)
	if die.faces.is_empty():
		return DiceData.make_standard_d6()
	return die


# ── Modifiers ─────────────────────────────────────────────────────────────

func serialize_modifiers(modifiers: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for modifier: Variant in modifiers:
		serialized.append({
			"type": int(modifier.modifier_type),
		})
	return serialized


func deserialize_modifiers(raw_data: Array) -> Array:
	var deserialized: Array = []
	for modifier_data: Variant in raw_data:
		if not (modifier_data is Dictionary):
			continue
		var modifier_type: int = int((modifier_data as Dictionary).get("type", -1))
		var modifier: Variant = make_modifier_from_type(modifier_type)
		if modifier != null:
			deserialized.append(modifier)
	return deserialized


func make_modifier_from_type(modifier_type: int) -> Variant:
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
		int(RunModifier.ModifierType.BLAST_SHIELD):
			return RunModifier.make_blast_shield()
		int(RunModifier.ModifierType.ANCHORED_HEARTS):
			return RunModifier.make_anchored_hearts()
		int(RunModifier.ModifierType.HEAVY_DICE):
			return RunModifier.make_heavy_dice()
		int(RunModifier.ModifierType.AFTERSHOCK):
			return RunModifier.make_aftershock()
		int(RunModifier.ModifierType.SYMPATHETIC_DETONATION):
			return RunModifier.make_sympathetic_detonation()
		int(RunModifier.ModifierType.SHRAPNEL):
			return RunModifier.make_shrapnel()
		int(RunModifier.ModifierType.GRAVITY_WELL):
			return RunModifier.make_gravity_well()
		int(RunModifier.ModifierType.RUBBER_DICE):
			return RunModifier.make_rubber_dice()
		int(RunModifier.ModifierType.SPARK_SCATTER):
			return RunModifier.make_spark_scatter()
		int(RunModifier.ModifierType.CLUSTER_RECURSION):
			return RunModifier.make_cluster_recursion()
		int(RunModifier.ModifierType.EMPOWER_DIE):
			return RunModifier.make_empower_die()
	return null
