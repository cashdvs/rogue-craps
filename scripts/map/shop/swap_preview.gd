## Old -> new face strips for a die swap confirm (die_buy_flow_v1 §2d).
## Also builds a RunDie face strip for bag cards: player-carved faces get a
## brass ring and 20% brass fill; forge-locked faces keep the lock, no fill.
class_name SwapPreview
extends HBoxContainer

const CREAM := Color("#E8DCC0")
const BRASS := Color("#C9A24A")
const DARK := Color("#141210")
const FILL := Color(0.788, 0.635, 0.290, 0.2)  # #C9A24A at 20%.


## Side-by-side old and new strips with an arrow. `phone`: wrap a 6-face
## strip to 2x3 when 6 cells will not fit across `max_w`.
static func make(old: DieCardInfo, new_info: DieCardInfo, cell: float, k: float, max_w: float, phone: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SwapPreview"
	row.add_theme_constant_override("separation", int(8 * k))
	row.add_child(face_strip(old, cell, k, max_w * 0.45, phone))
	var arrow := RunTheme.label("->", maxi(11, int(22 * k)), BRASS, true)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)
	row.add_child(face_strip(new_info, cell, k, max_w * 0.45, phone))
	return row


## A DieCardInfo built from a shop / event offer (the incoming die).
static func from_def(p: RunProgress, def: SpecialDieData) -> DieCardInfo:
	var info := DieCardInfo.new()
	info.display_name = def.display_name
	info.ability = def.description
	var presets: Dictionary = def.preset_mods if def is DieShape else {}
	for f in def.faces.size():
		var v: int = def.faces[f]
		var mod := StringName(presets.get(v, &""))
		var face := {"value": v, "mod": mod, "mod_name": DieCardInfo.mod_name(p, mod)}
		if def.is_rare() and def is DieShape and (def as DieShape).is_preset(f, mod):
			face["locked"] = true
		info.faces.append(face)
	return info


## Face cells are at least 24 px. d10+: a range line plus a carved/locked highlight.
static func face_strip(info: DieCardInfo, cell: float, k: float, max_w: float = 0.0, phone: bool = false) -> Control:
	cell = maxf(24.0, cell)
	var gap := maxf(4.0, 6.0 * k)
	var box := VBoxContainer.new()
	box.name = "FaceStrip"
	box.add_theme_constant_override("separation", int(gap))
	var n := info.faces.size()
	if n > 8:
		var lab := RunTheme.label(ShopCardStrings.fill("shop_card_faces_range", n), maxi(11, int(16 * k)), CREAM)
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(lab)
		var carved: Array[Dictionary] = []
		for face in info.faces:
			var mod: StringName = face.get("mod", &"")
			if mod != &"" and (bool(face.get("locked", false)) or mod != RunDie.BLANK):
				carved.append(face)
		if not carved.is_empty():
			box.add_child(_grid(carved, cell, gap, max_w, phone, carved.size()))
		return box
	box.add_child(_grid(info.faces, cell, gap, max_w, phone, n))
	return box


static func _grid(faces: Array, cell: float, gap: float, max_w: float, phone: bool, n: int) -> Control:
	var cols := n
	if phone and n == 6 and max_w > 0.0 and 6.0 * cell + 5.0 * gap > max_w + 0.5:
		cols = 3
	elif max_w > 0.0 and n > 1 and n * cell + (n - 1) * gap > max_w + 0.5:
		cols = maxi(1, int((max_w + gap) / (cell + gap)))
	var grid := GridContainer.new()
	grid.columns = maxi(1, cols)
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	for face: Dictionary in faces:
		grid.add_child(_face(face, cell))
	return grid


static func _face(face: Dictionary, cell: float) -> Control:
	var f := Control.new()
	f.custom_minimum_size = Vector2.ONE * cell
	var value: int = int(face.get("value", 0))
	var mod: StringName = face.get("mod", &"")
	var locked := bool(face.get("locked", false))
	var carved := mod != &"" and mod != RunDie.BLANK and not locked
	f.draw.connect(_draw_face.bind(f, value, carved, locked))
	if carved or (mod != &"" and locked):
		_badge(f, "ModIcon", 0.0, cell, mod, false)
	if locked:
		_badge(f, "Lock", 1.0, cell, mod, true)
	return f


static func _badge(face: Control, id: String, y: float, cell: float, mod: StringName, lock: bool) -> void:
	var m := Control.new()
	m.name = id
	var px := maxf(10.0, cell * 16.0 / 42.0)
	m.position = Vector2(y * (cell - px), y * (cell - px))
	m.custom_minimum_size = Vector2.ONE * px
	m.size = m.custom_minimum_size
	m.draw.connect(_draw_lock.bind(m, px) if lock else _draw_mod.bind(m, px, String(mod)))
	face.add_child(m)


static func _draw_face(f: Control, value: int, carved: bool, locked: bool) -> void:
	var s := f.size.x
	f.draw_rect(Rect2(Vector2.ZERO, f.size), CREAM)
	if carved:
		f.draw_rect(Rect2(Vector2.ZERO, f.size), FILL)
		f.draw_rect(Rect2(Vector2.ZERO, f.size), BRASS, false, maxf(1.5, s * 0.07))
	elif locked:
		f.draw_rect(Rect2(Vector2.ZERO, f.size), BRASS, false, maxf(1.0, s * 0.07))
	for p: Vector2 in ShopCard.pips(value):
		f.draw_circle(Vector2.ONE * s / 2.0 + p * s * 0.27, s * 0.085, DARK)


static func _draw_mod(m: Control, px: float, mod: String) -> void:
	m.draw_circle(Vector2.ONE * px / 2, px / 2, BRASS)
	m.draw_circle(Vector2.ONE * px / 2, px * 0.38, CREAM)
	m.draw_string(RunTheme.title_font, Vector2(px * 0.28, px * 0.72), mod.left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(px * 0.55), DARK)


static func _draw_lock(m: Control, px: float) -> void:
	m.draw_arc(Vector2(px / 2, px * 0.42), px * 0.22, PI, TAU, 12, DARK, px * 0.12)
	m.draw_rect(Rect2(px * 0.18, px * 0.42, px * 0.64, px * 0.5), DARK)
