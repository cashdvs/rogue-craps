## Every bet available in a run, starters and shop unlocks alike.
##
## The shop stub sells the non-starter entries (unlock_cost > 0), so this
## one list is the "data-driven list of unlockable bets with Coin costs".
class_name BetCatalog
extends Resource

@export var bets: Array[BetType] = []


## Finds a bet by id, or null if it isn't in the catalog.
func find(bet_id: StringName) -> BetType:
	for bet in bets:
		if bet != null and bet.id == bet_id:
			return bet
	return null


func starter_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for bet in bets:
		if bet != null and bet.is_starter():
			ids.append(bet.id)
	return ids
