class_name SideBetResolver extends RefCounted
## Manages side-bet state (insurance, heat, even/odd) and computes payouts.
## Does not handle gold — caller (GameManager) applies gold changes.

var insurance_payout: int = 0
var heat_bet_target_stops: int = -1
var heat_bet_payout: int = 0
var even_odd_bet_is_even: bool = true
var even_odd_bet_wager: int = 0


func clear() -> void:
	insurance_payout = 0
	heat_bet_target_stops = -1
	heat_bet_payout = 0
	even_odd_bet_wager = 0


func place_insurance(payout: int) -> void:
	insurance_payout = payout


## Returns the insurance payout amount. Caller should add_gold if > 0.
func resolve_insurance() -> int:
	var payout: int = insurance_payout
	insurance_payout = 0
	return payout


func place_heat_bet(target_stops: int, payout: int) -> void:
	heat_bet_target_stops = target_stops
	heat_bet_payout = payout


## Returns payout if stops match target, 0 otherwise. Caller should add_gold if > 0.
func resolve_heat(actual_stops: int) -> int:
	if heat_bet_target_stops < 0:
		return 0
	var payout: int = heat_bet_payout if actual_stops == heat_bet_target_stops else 0
	heat_bet_target_stops = -1
	heat_bet_payout = 0
	return payout


func place_even_odd_bet(is_even: bool, wager: int) -> void:
	even_odd_bet_is_even = is_even
	even_odd_bet_wager = wager


## Returns [net_gold_change, gold_to_credit].
## net: +wager on win, 0 on push, -wager on loss.
## credit: wager*2 on win, wager on push (refund), 0 on loss.
func resolve_even_odd(even_count: int, odd_count: int) -> Array[int]:
	if even_odd_bet_wager <= 0:
		return [0, 0]
	var wager: int = even_odd_bet_wager
	even_odd_bet_wager = 0
	if even_count == odd_count:
		return [0, wager]
	var player_wins: bool = (even_odd_bet_is_even and even_count > odd_count) or \
		(not even_odd_bet_is_even and odd_count > even_count)
	if player_wins:
		return [wager, wager * 2]
	return [-wager, 0]


func build_snapshot() -> Dictionary:
	return {
		"insurance_payout": insurance_payout,
		"heat_bet_target_stops": heat_bet_target_stops,
		"heat_bet_payout": heat_bet_payout,
		"even_odd_bet_is_even": even_odd_bet_is_even,
		"even_odd_bet_wager": even_odd_bet_wager,
	}


func restore_snapshot(data: Dictionary) -> void:
	insurance_payout = int(data.get("insurance_payout", 0))
	heat_bet_target_stops = int(data.get("heat_bet_target_stops", -1))
	heat_bet_payout = int(data.get("heat_bet_payout", 0))
	even_odd_bet_is_even = bool(data.get("even_odd_bet_is_even", true))
	even_odd_bet_wager = int(data.get("even_odd_bet_wager", 0))
