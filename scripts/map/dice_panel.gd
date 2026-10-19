## "Your dice" view (design/first_time_clarity_v1.md §2): one card per die
## (name, ability line, every face with its number and mod) and the "Your
## Seals" strip. Read-only from the map; in pick mode (shop, Rest carve,
## events) it replaces the old face picker: `allowed` decides which faces
## can be picked, and with `price` each die shows what its next mod costs.
## View only: emits picked(Vector2i(die, face)).
class_name DicePanel
extends VBoxContainer

signal picked(at: Vector2i)

const BONE_LINE := "Bone die: plain faces 1 to 6."
const NEXT_MOD := "Next mod on this die: %d Embers."
const TAKEN := "This face already has a face mod."
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


func _card(progress: RunProgress, d: int, allowed: Callable, price: Callable) -> Control:
	var box := VBoxContainer.new()
	var def := progress.die_def(d)
	var head := "Die %d: %s" % [d + 1, progress.die_name(d)]
	box.add_child(RunTheme.label("%s  -  %s" % [head, def.description if def != null else BONE_LINE], 18))
	if price.is_valid():
		box.add_child(RunTheme.label(NEXT_MOD % int(price.call(d)), 18, RunTheme.GOLD))
	var row := HBoxContainer.new()
	var die := progress.dice[d]
	for f in die.faces.size():
		var mod: StringName = die.faces[f]
		var value: int = def.faces[f] if def != null and f < def.faces.size() else f + 1
		var mod_name := _mod_name(progress, mod)
		var b := RunTheme.button(str(value) if mod == &"" else "%d %s" % [value, mod_name], 16)
		b.custom_minimum_size = Vector2(92, 40)
		b.tooltip_text = "Face %d: %s" % [value, mod_name if mod != &"" else "Plain face."]
		var at := Vector2i(d, f)
		if allowed.is_valid():
			b.disabled = not bool(allowed.call(at))
			if b.disabled and mod != &"" and mod != RunDie.BLANK:
				b.tooltip_text += "\n" + TAKEN
			b.pressed.connect(func() -> void: picked.emit(at))
		else:
			b.disabled = true
		row.add_child(b)
	box.add_child(row)
	return box


static func _mod_name(progress: RunProgress, mod: StringName) -> String:
	if mod == RunDie.BLANK:
		return "Blank"
	for m in progress.data.face_mods:
		if m.id == mod:
			return m.display_name.trim_suffix(" Face")
	return String(mod).capitalize()
