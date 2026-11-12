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
	var die_pick := bool(opts.get("die_pick", false))
	var title := "Your dice · %d/%d" % [progress.dice.size(), progress.data.max_dice]
	add_child(RunTheme.label(String(opts.get("prompt", title)), 24, RunTheme.GOLD))
	for d in progress.dice.size():
		add_child(_card(progress, d, allowed, price, die_pick))
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
func _card(progress: RunProgress, d: int, allowed: Callable, price: Callable, die_pick: bool = false) -> Control:
	var info := DieCardInfo.from_run(progress, d)
	info.display_name = "Die %d: %s" % [d + 1, info.display_name]
	if price.is_valid():
		info.next_mod_price = int(price.call(d))
	var card := DieCard.new()
	if die_pick:
		card.set_die(info, true)
		_ignore_mouse(card)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent) -> void:
			var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
			if click or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
				picked.emit(Vector2i(d, 0)))
		_card_tags(card, progress, d)
	elif allowed.is_valid():
		card.set_die(info, false, func(f: int) -> bool: return bool(allowed.call(Vector2i(d, f))))
		card.face_picked.connect(func(f: int) -> void: picked.emit(Vector2i(d, f)))
		_card_tags(card, progress, d)
	else:
		card.set_die(info, true)
	return card


func _card_tags(card: DieCard, progress: RunProgress, d: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if progress.die_is_rare(d):
		row.add_child(RareMarks.chip(maxi(11, 16), 1.0))
	if progress.die_has_mods(d):
		row.add_child(RunTheme.label(ShopSideCard.SWAP_TEXT.shop_bag_carved_tag, maxi(11, 16), Color("#C9A24A"), true))
	if row.get_child_count() > 0:
		card.add_child(row)
		card.move_child(row, mini(1, card.get_child_count() - 1))


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)
