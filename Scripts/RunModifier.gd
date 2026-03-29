class_name RunModifier
extends Resource
## Passive modifier (Joker-equivalent) active for the current run.
## Each modifier has a unique ID, display info, and typed effect that
## game systems query to alter scoring, bust logic, or gold economy.

enum ModifierType {
	GAMBLERS_RUSH,    ## +1g per survived stop when banking
	EXPLOSOPHILE,     ## Explode chains get +1 extra chain-reroll die
	IRON_BANK,        ## +50% score if you don't reroll (first roll only)
	GLASS_CANNON,     ## Bust threshold -1, NUMBER faces +2
	SHIELD_WALL,      ## Each shield absorbs 2 stops instead of 1
	MISER,            ## Spend <15g in shop → +20g next shop
}

@export var modifier_type: ModifierType = ModifierType.GAMBLERS_RUSH
@export var modifier_name: String = ""
@export var description: String = ""
@export var cost: int = 0


# ---------------------------------------------------------------------------
# Factory methods
# ---------------------------------------------------------------------------

static func make_gamblers_rush() -> RunModifier:
	var m := RunModifier.new()
	m.modifier_type = ModifierType.GAMBLERS_RUSH
	m.modifier_name = "Gambler's Rush"
	m.description = "+1g per survived stop when banking."
	m.cost = 30
	return m


static func make_explosophile() -> RunModifier:
	var m := RunModifier.new()
	m.modifier_type = ModifierType.EXPLOSOPHILE
	m.modifier_name = "Explosophile"
	m.description = "Explode chains reroll 1 extra die."
	m.cost = 35
	return m


static func make_iron_bank() -> RunModifier:
	var m := RunModifier.new()
	m.modifier_type = ModifierType.IRON_BANK
	m.modifier_name = "Iron Bank"
	m.description = "+50% score if you bank without rerolling."
	m.cost = 40
	return m


static func make_glass_cannon() -> RunModifier:
	var m := RunModifier.new()
	m.modifier_type = ModifierType.GLASS_CANNON
	m.modifier_name = "Glass Cannon"
	m.description = "Bust threshold -1, but NUMBER faces score +2."
	m.cost = 35
	return m


static func make_shield_wall() -> RunModifier:
	var m := RunModifier.new()
	m.modifier_type = ModifierType.SHIELD_WALL
	m.modifier_name = "Shield Wall"
	m.description = "Each SHIELD absorbs 2 stops instead of 1."
	m.cost = 30
	return m


static func make_miser() -> RunModifier:
	var m := RunModifier.new()
	m.modifier_type = ModifierType.MISER
	m.modifier_name = "Miser"
	m.description = "Spend <15g in shop → +20g next shop."
	m.cost = 25
	return m


## Returns all 6 modifier factory methods for building the shop pool.
static func all_factories() -> Array[Callable]:
	return [
		RunModifier.make_gamblers_rush,
		RunModifier.make_explosophile,
		RunModifier.make_iron_bank,
		RunModifier.make_glass_cannon,
		RunModifier.make_shield_wall,
		RunModifier.make_miser,
	]
