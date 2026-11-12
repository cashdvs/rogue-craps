## A camera-facing number for the Powder Keg barrel. The value that counts
## is the stave pointing straight up (PolyDie.up_slot, values 1, 1, 2, 2,
## 3, 3 around the barrel). The table camera looks down at about 47 degrees,
## so a neighbouring stave faces the lens more squarely than the scoring
## stave, and that neighbour is a different number. The printed marks are
## pips about 5 mm across, and the outer pips of a 2 or a 3 sit under the
## iron hoops, so counting them at a glance fails on a phone and on a small
## window. This tag shows DieVisual.shown_value straight on, the same
## unlit readout a d4 uses (D4ValueTag). It does not change which stave is
## read, and it adds no glow: the label is unlit, and the die's own
## emission is left alone (scoring glow stays <= 0.3).
## Extending D4ValueTag also keeps HudTextRects from treating the tag as
## HUD text (it skips every D4ValueTag).
class_name KegValueTag
extends D4ValueTag


## Adds a tag to [param d] (a dressed Powder Keg) and returns it.
static func attach(d: DieVisual) -> KegValueTag:
	var t := KegValueTag.new()
	t.name = "KegValueTag"
	t.die = d
	d.add_child(t)
	return t
