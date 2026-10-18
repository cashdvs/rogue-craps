## Mini dice icons of a bounty's pattern for the bounty cards
## (bonfire_map_events_juice.md section 4): Triple = 3 matching dice, Run of 3
## = 1-2-3, Two Pairs = 2-2-5-5, Full House = 3-3-3-5-5 (example faces; a
## bounty with a set face shows that face).
class_name DiceIcons
extends Control

const PIPS := {
	1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

var values: Array[int] = []
var die_px: float = 18.0


static func pattern(b: BountyData) -> Array[int]:
	var out: Array[int] = []
	match b.kind:
		BountyData.Kind.N_OF_A_KIND:
			for i in b.n:
				out.append(b.face if b.face > 0 else 4)
		BountyData.Kind.RUN, BountyData.Kind.STRAIGHT_5:
			var n := 5 if b.kind == BountyData.Kind.STRAIGHT_5 else b.n
			for i in n:
				out.append(i + 1)
		BountyData.Kind.TWO_PAIR:
			out = [2, 2, 5, 5]
		BountyData.Kind.FULL_HOUSE:
			out = [3, 3, 3, 5, 5]
	return out


func set_values(v: Array[int]) -> void:
	values = v
	custom_minimum_size = Vector2(values.size() * (die_px + 3.0), die_px + 2.0)
	queue_redraw()


func _draw() -> void:
	for i in values.size():
		var r := Rect2(Vector2(i * (die_px + 3.0), 1.0), Vector2(die_px, die_px))
		draw_rect(r, Palette.BONE)
		draw_rect(r, Palette.PIT_BLACK, false, 1.5)
		var c := r.get_center()
		for p: Vector2 in PIPS.get(clampi(values[i], 1, 6), []):
			draw_circle(c + p * die_px * 0.27, die_px * 0.09, Palette.PIT_BLACK)
