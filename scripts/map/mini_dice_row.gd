## The table preview's mini dice row (design/first_time_clarity_v1.md §1-2):
## a small tile per die in the bag, in table order, under a "Your dice ·
## n/max" header. Any tile opens the read-only "Your dice" view.
## View only: emits opened.
class_name MiniDiceRow
extends VBoxContainer

signal opened

const TILE := Vector2(74, 46)


## Fill the row from `progress`'s bag (one tile per die: short name, its face
## count and how many face mods it carries; the full name as a tooltip).
func build(progress: RunProgress) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(RunTheme.label("Your dice · %d/%d" % [progress.dice.size(), progress.data.max_dice], 20, RunTheme.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in progress.dice.size():
		var b := RunTheme.button(tile_text(progress, i), 16)
		b.custom_minimum_size = TILE
		b.tooltip_text = progress.die_name(i)
		b.pressed.connect(func() -> void: opened.emit())
		row.add_child(b)


## A tile's text: the first word of the die's name (8 letters at most), then
## "d<faces>", then "+<mods>" with face mods, e.g. "Bone d6", "Lantern d8 +1".
static func tile_text(progress: RunProgress, i: int) -> String:
	var d := progress.dice[i]
	var mods := 0
	for f in d.faces:
		mods += 1 if f != &"" else 0
	var t := "%s d%d" % [progress.die_name(i).get_slice(" ", 0).left(8), d.faces.size()]
	return t + (" +%d" % mods if mods > 0 else "")
