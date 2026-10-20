## "Your dice" view (design/first_time_clarity_v1.md §2): one card per die
## (name, ability line, every face with its number and mod) and the "Your
## Seals" strip. Read-only from the map; in pick mode (shop, Rest carve,
## events) it replaces the old face picker: `allowed` decides which faces
## can be picked, and with `price` each die shows what its next mod costs.
## View only: emits picked(Vector2i(die, face)).
class_name DicePanel
extends VBoxContainer

signal picked(at: Vector2i)

const BONE_LINE := DieCardInfo.BONE_LINE
const NEXT_MOD := DieCard.NEXT_MOD
const TAKEN := DieCard.TAKEN
const NO_SEALS := "No Seals yet; win a table to pick one."


## Fill the panel. opts (all optional): "prompt" (pick-mode header),
## "allowed" (Callable(Vector2i) -> bool; set = pick mode), "price"
## (Callable(die_i) -> int; the next-mod cost per die), "combos"
## (Array[BonfireCombo] for Seal names and values), "seals" (bool, default true).
func build(progress: RunProgress, opts: Dictionary = {}) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var allowed: Callable = opts.get("allowed", Callable())
	var price: Callable = opts.get("price", Callable())
	var title := "Your dice · %d/%d" % [progress.dice.size(), progress.data.max_dice]
	add_child(RunTheme.label(String(opts.get("prompt", title)), 24, RunTheme.GOLD))
	for d in progress.dice.size():
		add_child(_card(progress, d, allowed, price))
	if bool(opts.get("seals", true)):
		add_child(RunTheme.label("Your Seals", 22, RunTheme.EMBER))
		for l in seal_lines(progress, opts.get("combos", [])):
			add_child(RunTheme.label(l, 18))


## One line per owned Seal, from Lv1: "Trips Lv1: +10 base, +1 mult".
static func seal_lines(progress: RunProgress, combos: Array) -> Array[String]:
	var out: Array[String] = []
	for c in progress.data.seal_combos:
		var lv := progress.seal_level(c)
		if lv <= 0:
			continue
		var name := String(c).capitalize()
		for bc in combos:
			if bc.id == c:
				name = bc.display_name
		var b := progress.seal_bonus(c)
		out.append("%s Lv%d: +%d base, +%d mult" % [name, lv, b.x, b.y])
	if out.is_empty():
		out.append(NO_SEALS)
	return out


## Die d's card (DieCard). Header "Die n: name"; in pick mode the faces
## `allowed` accepts are pickable and picks come out as picked(Vector2i(d, f)).
func _card(progress: RunProgress, d: int, allowed: Callable, price: Callable) -> Control:
	var info := DieCardInfo.from_run(progress, d)
	info.display_name = "Die %d: %s" % [d + 1, info.display_name]
	if price.is_valid():
		info.next_mod_price = int(price.call(d))
	var card := DieCard.new()
	if allowed.is_valid():
		card.set_die(info, false, func(f: int) -> bool: return bool(allowed.call(Vector2i(d, f))))
		card.face_picked.connect(func(f: int) -> void: picked.emit(Vector2i(d, f)))
	else:
		card.set_die(info, true)
	return card
