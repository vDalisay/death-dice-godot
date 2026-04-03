class_name CosmeticData
extends Resource
## Defines a purchasable cosmetic for a die (glow, color shift, particle effects, etc.)
## Cosmetics are unlocked through mastery progression and can be purchased from shop.

@export var cosmetic_id: String = ""  # Unique ID for this cosmetic (e.g., "glow", "color_shift")
@export var cosmetic_name: String = ""  # Display name (e.g., "Golden Glow")
@export var description: String = ""  # What it does (e.g., "Adds a shimmering glow to the die")
@export var cost: int = 0  # Gold cost to purchase
@export var required_mastery_level: int = 0  # Minimum die mastery level to unlock purchase
@export var steam_achievement_id: String = ""  # Optional Steam achievement ID to unlock on purchase
@export var visual_effect: String = ""  # Type of effect: "glow", "color_shift", "particle_trail", "legendary_shine"
@export var color_override: Color = Color.WHITE  # Color to apply (for color_shift cosmetics)


static func make_glow_cosmetic() -> CosmeticData:
	var cosmetic := CosmeticData.new()
	cosmetic.cosmetic_id = "glow"
	cosmetic.cosmetic_name = "Golden Glow"
	cosmetic.description = "Adds a shimmering glow effect to the die"
	cosmetic.cost = 75
	cosmetic.required_mastery_level = 2
	cosmetic.steam_achievement_id = "ACH_GLOW_COSMETIC"
	cosmetic.visual_effect = "glow"
	cosmetic.color_override = Color.GOLD
	return cosmetic


static func make_color_shift_cosmetic() -> CosmeticData:
	var cosmetic := CosmeticData.new()
	cosmetic.cosmetic_id = "color_shift"
	cosmetic.cosmetic_name = "Chromatic Shift"
	cosmetic.description = "Changes the die color to a vibrant hue"
	cosmetic.cost = 100
	cosmetic.required_mastery_level = 3
	cosmetic.steam_achievement_id = "ACH_COLOR_SHIFT_COSMETIC"
	cosmetic.visual_effect = "color_shift"
	cosmetic.color_override = Color.LIGHT_CORAL
	return cosmetic


static func make_particle_trail_cosmetic() -> CosmeticData:
	var cosmetic := CosmeticData.new()
	cosmetic.cosmetic_id = "particle_trail"
	cosmetic.cosmetic_name = "Particle Trail"
	cosmetic.description = "Leaves a trail of particles when rolling"
	cosmetic.cost = 150
	cosmetic.required_mastery_level = 4
	cosmetic.steam_achievement_id = "ACH_PARTICLE_TRAIL_COSMETIC"
	cosmetic.visual_effect = "particle_trail"
	cosmetic.color_override = Color.CYAN
	return cosmetic


static func make_legendary_shine_cosmetic() -> CosmeticData:
	var cosmetic := CosmeticData.new()
	cosmetic.cosmetic_id = "legendary_shine"
	cosmetic.cosmetic_name = "Legendary Shine"
	cosmetic.description = "Legendary status with an ethereal glow"
	cosmetic.cost = 250
	cosmetic.required_mastery_level = 5
	cosmetic.steam_achievement_id = "ACH_LEGENDARY_SHINE_COSMETIC"
	cosmetic.visual_effect = "legendary_shine"
	cosmetic.color_override = Color.CORNFLOWER_BLUE
	return cosmetic


func to_dict() -> Dictionary:
	return {
		"cosmetic_id": cosmetic_id,
		"cosmetic_name": cosmetic_name,
		"description": description,
		"cost": cost,
		"required_mastery_level": required_mastery_level,
		"steam_achievement_id": steam_achievement_id,
		"visual_effect": visual_effect,
		"color_override": color_override,
	}
