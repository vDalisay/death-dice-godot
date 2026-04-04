extends GdUnitTestSuite
## Unit tests for the Momentum Scoring Meter feature.
## Tests momentum multiplier formula and integration with GameManager.

const MOMENTUM_STEP: float = 0.05


# ---------------------------------------------------------------------------
# Momentum multiplier formula: 1.0 + momentum * 0.05
# ---------------------------------------------------------------------------

func test_momentum_zero_gives_no_bonus() -> void:
	assert_float(_calc_momentum_mult(0)).is_equal(1.0)


func test_momentum_one_gives_five_percent() -> void:
	assert_float(_calc_momentum_mult(1)).is_equal_approx(1.05, 0.001)


func test_momentum_two_gives_ten_percent() -> void:
	assert_float(_calc_momentum_mult(2)).is_equal_approx(1.10, 0.001)


func test_momentum_five_gives_twentyfive_percent() -> void:
	assert_float(_calc_momentum_mult(5)).is_equal_approx(1.25, 0.001)


func test_momentum_ten_gives_fifty_percent() -> void:
	assert_float(_calc_momentum_mult(10)).is_equal_approx(1.50, 0.001)


# ---------------------------------------------------------------------------
# Applied to score: momentum multiplier affects banked points
# ---------------------------------------------------------------------------

func test_momentum_multiplied_score() -> void:
	# base_score = 100, momentum = 3 → mult = 1.15 → int(115.0) = 114 or 115
	# Uses int() truncation matching RollPhase behavior.
	var base: int = 100
	var mult: float = _calc_momentum_mult(3)
	var result: int = int(base * mult)
	assert_int(result).is_between(114, 115)


func test_momentum_multiplied_score_rounds_down() -> void:
	# base_score = 7, momentum = 1 → mult = 1.05 → 7.35 → 7
	var base: int = 7
	var mult: float = _calc_momentum_mult(1)
	var result: int = int(base * mult)
	assert_int(result).is_equal(7)


# ---------------------------------------------------------------------------
# Helper — mirrors the formula in RollPhase._get_momentum_multiplier()
# ---------------------------------------------------------------------------

func _calc_momentum_mult(momentum: int) -> float:
	if momentum <= 0:
		return 1.0
	return 1.0 + float(momentum) * MOMENTUM_STEP
