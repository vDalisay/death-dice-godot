extends GdUnitTestSuite
## Unit tests for RunModifier resource — passive modifiers (Joker system).


func test_all_factories_create_unique_types() -> void:
	var factories: Array[Callable] = RunModifier.all_factories()
	assert_int(factories.size()).is_equal(12)
	var seen_types: Array[int] = []
	for factory: Callable in factories:
		var mod: RunModifier = factory.call() as RunModifier
		assert_object(mod).is_not_null()
		assert_bool(mod.modifier_type in seen_types).is_false()
		seen_types.append(mod.modifier_type)


func test_gamblers_rush_properties() -> void:
	var mod: RunModifier = RunModifier.make_gamblers_rush()
	assert_str(mod.modifier_name).is_equal("Gambler's Rush")
	assert_int(mod.cost).is_greater(0)
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.GAMBLERS_RUSH)


func test_explosophile_properties() -> void:
	var mod: RunModifier = RunModifier.make_explosophile()
	assert_str(mod.modifier_name).is_equal("Explosophile")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.EXPLOSOPHILE)


func test_iron_bank_properties() -> void:
	var mod: RunModifier = RunModifier.make_iron_bank()
	assert_str(mod.modifier_name).is_equal("Iron Bank")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.IRON_BANK)


func test_glass_cannon_properties() -> void:
	var mod: RunModifier = RunModifier.make_glass_cannon()
	assert_str(mod.modifier_name).is_equal("Glass Cannon")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.GLASS_CANNON)


func test_shield_wall_properties() -> void:
	var mod: RunModifier = RunModifier.make_shield_wall()
	assert_str(mod.modifier_name).is_equal("Shield Wall")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.SHIELD_WALL)


func test_miser_properties() -> void:
	var mod: RunModifier = RunModifier.make_miser()
	assert_str(mod.modifier_name).is_equal("Miser")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.MISER)


func test_badge_glyph_helpers() -> void:
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.GAMBLERS_RUSH)).is_equal("$")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.IRON_BANK)).is_equal("Fe")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.DOUBLE_DOWN)).is_equal("⇅")


func test_badge_color_helpers_return_valid_colors() -> void:
	var color_a: Color = RunModifier.badge_color_for_type(RunModifier.ModifierType.SHIELD_WALL)
	var color_b: Color = RunModifier.badge_color_for_type(RunModifier.ModifierType.GLASS_CANNON)
	assert_float(color_a.a).is_equal(1.0)
	assert_float(color_b.a).is_equal(1.0)


# ---------------------------------------------------------------------------
# New modifier properties (Expansion Pack A)
# ---------------------------------------------------------------------------

func test_scavenger_properties() -> void:
	var mod: RunModifier = RunModifier.make_scavenger()
	assert_str(mod.modifier_name).is_equal("Scavenger")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.SCAVENGER)
	assert_int(mod.cost).is_equal(25)


func test_recycler_properties() -> void:
	var mod: RunModifier = RunModifier.make_recycler()
	assert_str(mod.modifier_name).is_equal("Recycler")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.RECYCLER)
	assert_int(mod.cost).is_equal(25)


func test_last_stand_properties() -> void:
	var mod: RunModifier = RunModifier.make_last_stand()
	assert_str(mod.modifier_name).is_equal("Last Stand")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.LAST_STAND)
	assert_int(mod.cost).is_equal(30)


func test_chain_lightning_properties() -> void:
	var mod: RunModifier = RunModifier.make_chain_lightning()
	assert_str(mod.modifier_name).is_equal("Chain Lightning")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.CHAIN_LIGHTNING)
	assert_int(mod.cost).is_equal(35)


func test_high_roller_properties() -> void:
	var mod: RunModifier = RunModifier.make_high_roller()
	assert_str(mod.modifier_name).is_equal("High Roller")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.HIGH_ROLLER)
	assert_int(mod.cost).is_equal(35)


func test_overcharge_properties() -> void:
	var mod: RunModifier = RunModifier.make_overcharge()
	assert_str(mod.modifier_name).is_equal("Overcharge")
	assert_int(mod.modifier_type).is_equal(RunModifier.ModifierType.OVERCHARGE)
	assert_int(mod.cost).is_equal(40)


func test_new_modifier_glyphs() -> void:
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.SCAVENGER)).is_equal("⚙")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.RECYCLER)).is_equal("♻")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.LAST_STAND)).is_equal("♥")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.CHAIN_LIGHTNING)).is_equal("⚡")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.HIGH_ROLLER)).is_equal("♦")
	assert_str(RunModifier.badge_glyph_for_type(RunModifier.ModifierType.OVERCHARGE)).is_equal("☢")


func test_new_modifier_colors_valid() -> void:
	for mod_type: int in [
		RunModifier.ModifierType.SCAVENGER,
		RunModifier.ModifierType.RECYCLER,
		RunModifier.ModifierType.LAST_STAND,
		RunModifier.ModifierType.CHAIN_LIGHTNING,
		RunModifier.ModifierType.HIGH_ROLLER,
		RunModifier.ModifierType.OVERCHARGE,
	]:
		var c: Color = RunModifier.badge_color_for_type(mod_type as RunModifier.ModifierType)
		assert_float(c.a).is_equal(1.0)
