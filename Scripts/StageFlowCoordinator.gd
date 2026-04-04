class_name StageFlowCoordinator
extends RefCounted
## Coordinates map-node progression state transitions via GameManager APIs.


func advance_row(col: int) -> void:
	GameManager.advance_row(col)


func begin_stage_from_map() -> void:
	GameManager.begin_stage_from_map()


func apply_rest_rewards(heal_lives: int, gold_bonus: int) -> void:
	GameManager.heal_lives(heal_lives)
	GameManager.add_gold(gold_bonus)


func complete_loop() -> void:
	GameManager.advance_loop()
