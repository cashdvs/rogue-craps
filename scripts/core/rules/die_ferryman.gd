## Ferryman's Coin (design/nonstandard_dice.md §10, PM final): a 2-faced
## coin that copies another die, resolving in Mirror's slot (landed ->
## Mirror / Ferryman copies -> boss cheats / twists -> lit check).
##   HEADS (face slot 1, the coin's +Y side) copies the HIGHEST non-copy
##   die in the tray; TAILS (slot 2, -Y) copies the LOWEST.
##   Thrown alone (no non-copy die in the tray): HEADS = 5 (lights),
##   TAILS = Blank (never lights; a lone Tails busts).
## Rulings (Mirror's apply):
##   - The tray = this throw's dice; potted dice are out of it.
##   - Non-copy dice only: other Ferryman's Coins and Mirror Dice are never
##     copied (two coins each copy the landed non-copy dice).
##   - Values as they LANDED (before any copy or boss reroll); ties in value
##     don't matter (same number), so the lowest index is taken.
##   - The copy counts as a natural face: it keeps the coin's own landed
##     slot (heads / tails) and that slot's face mod, if one is carved there.
##   - Heads / Tails is the SLOT, never the printed value (the run sends
##     faces [5, 0]; nothing here reads them except via the copy).
class_name DieFerryman
extends TableRule

## Specials that are copies themselves (never a copy target).
const COPY_DICE: Array[StringName] = [&"mirror", &"ferryman"]
## TableDie face slots (1-based): slot 1 = faces[0] = heads (+Y), 2 = tails.
const HEADS_SLOT: int = 1
const TAILS_SLOT: int = 2

static var _blank: FaceModData


## A shared Blank face (Tails thrown alone).
static func blank_mod() -> FaceModData:
	if _blank == null:
		_blank = FaceModData.new()
		_blank.id = &"blank"
		_blank.display_name = "Blank"
		_blank.effect = FaceModData.Effect.BLANK
		_blank.is_curse = true
	return _blank


func on_throw_landed(_run: BonfireRun, th: TableThrow) -> void:
	var landed := th.values.duplicate()
	for i in th.size():
		if th.special(i) != &"ferryman":
			continue
		var slot := th.slots[i] if i < th.slots.size() and th.slots[i] > 0 else HEADS_SLOT
		var heads := slot != TAILS_SLOT
		var best := -1
		for j in th.size():
			if j == i or COPY_DICE.has(th.special(j)):
				continue
			if best < 0 or (heads and landed[j] > landed[best]) or (not heads and landed[j] < landed[best]):
				best = j
		if best >= 0:
			if landed[best] != th.values[i]:
				th.copy_value(i, landed[best], id)
		elif heads:
			if th.values[i] != 5:
				th.copy_value(i, 5, id)
		else:
			th.set_mod(i, blank_mod(), id)
