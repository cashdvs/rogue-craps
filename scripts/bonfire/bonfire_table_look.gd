## Layer 2 of the Bonfire table: how the dice LOOK (the art seam).
## Everything that dresses a DieVisual for a TableDie lives here: the face
## values via set_look, the coin shape, and the face-mod decals. Swap the
## dice art by changing apply_die_look() / table_die(); the felt, rails and
## room come from Table3DBuilder (scripts/table3d/table_3d_builder.gd).
@abstract
class_name BonfireTableLook
extends BonfireTableState


# Declared here, written in a later layer (the chain ends at Bonfire3D).
# "@abstract" only promises the function exists so this file can call it.
@abstract func pot_slot(k: int) -> Vector3


## The TableDie behind a die on the table.
func table_die(d: DieVisual) -> TableDie:
	return _die_of.get(d)


## Shows a TableDie on a die: its face values (pips) and a cheap decal per
## modded face: Hellfire red-orange rim + glowing pips, Wild brass/dark rim +
## gold pips, Twin a double outline, Blank plain bone over the pips.
func apply_die_look(d: DieVisual, td: TableDie) -> void:
	if td == null:
		return
	apply_art_body(d, td.id)
	if td.shape == &"coin":
		d.make_coin()
	elif RareDieLook.is_rare(td.id):
		# Rares: the Art Director's warm body tint (RareDieLook) over Bone.
		d.set_look(RareDieLook.body_color(), Palette.PIT_BLACK, td.faces)
		d.set_meta("rare_look", true)
		RareDieLook.set_trim(d, true)
	elif td.faces != [1, 2, 3, 4, 5, 6] or d.has_meta("rare_look"):
		d.remove_meta("rare_look")
		RareDieLook.set_trim(d, false)
		# DieVisual.safe_labels pads / trims a mismatched face list to 6.
		d.set_look(Palette.BONE, Palette.PIT_BLACK, td.faces)
	place_face_mods(d, td)


## (Re)builds the FaceMods decals for a die. Called again after
## PolyBody.dress, so a d4 gets its marks on its real triangle faces.
func place_face_mods(d: DieVisual, td: TableDie) -> void:
	var old := d.faces.get_node_or_null("FaceMods")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "FaceMods"
	d.faces.add_child(root)
	# One decal per modded slot the mesh has (a coin: heads, tails).
	for slot in range(1, mini(td.mods.size(), {&"coin": 2, &"d4": 4, &"d8": 8}.get(d.shape, 6)) + 1):
		var m := td.mod_at(slot)
		if m != null:
			_add_mod_decal(root, d, slot if PolyBody.has_face_spots(d) else d.mesh_face(slot), m)


func _add_mod_decal(root: Node3D, d: DieVisual, slot: int, m: FaceModData) -> void:
	var e := d.edge
	# Everything sits just above the pip tops (h + 0.01 e) so the die's ink
	# outline pass can't swallow it; fills would hide the pips, so the
	# coloured mods are a rim + tinted pips.
	var n: Vector3
	var lift: float
	_at = Vector3.ZERO
	if PolyBody.has_face_spots(d):
		# A d4 / d8 face is a tilted triangle: use its real normal, sit flush
		# on it (a hair above), and shrink the mark to fit inside it.
		var f := PolyBody.face_spot(d, slot)
		n = f.normal
		lift = f.dist + 0.002 * e
		e = f.width
		_at = f.at
	else:
		n = DieVisual.FACE_AXES[slot] as Vector3
		lift = d.face_half(slot) + 0.014 * e
	var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
	u = (u - n * u.dot(n)).normalized()
	var v := n.cross(u)
	# The d4 Twin and d8 rare glyphs go around the printed face art.
	if d.shape == &"d4" and m.effect == FaceModData.Effect.TWIN and not RareDieLook.MARKS.has(m.id):
		PolyFaceMarks.twin_diamond(root, d, slot)
		return
	if d.shape == &"d8" and PolyFaceMarks.rare_on_d8(root, d, slot, m.id):
		return
	# Rare mods (Fuse, Jackpot, Hex, Gilded, Step) get their own glyph mark.
	if RareDieLook.add_mark(root, d, n, u, v, lift, m.id):
		if PolyBody.has_face_spots(d):
			_fit_rare_mark(root.get_child(-1) as Node3D, d, e)
		return
	match m.effect:
		FaceModData.Effect.MULT_FACTOR:
			var c: Array[Color] = [HELLFIRE_COLOR, HELLFIRE_COLOR, HELLFIRE_COLOR, HELLFIRE_COLOR]
			_decal_frame(root, n, u, v, lift, e * 0.88, e * 0.08, c)
			_tint_pips(d, n, HELLFIRE_COLOR)
		FaceModData.Effect.WILD:
			_wild_frame(root, n, u, v, lift, e * 0.88, e * 0.104)
			_tint_pips(d, n, WILD_COLOR)
		FaceModData.Effect.TWIN:
			var c: Array[Color] = [TWIN_COLOR, TWIN_COLOR, TWIN_COLOR, TWIN_COLOR]
			_decal_frame(root, n, u, v, lift, e * 0.84, e * 0.04, c)
			_decal_frame(root, n, u, v, lift, e * 0.70, e * 0.04, c)
		FaceModData.Effect.BLANK:
			# A plain bone face over the pips.
			_decal_quad(root, n, u, v, lift, e * 0.86, e * 0.86, Vector2.ZERO, Palette.BONE, false)


## Recolours (and lights) the pips on the face with outward normal `n`.
func _tint_pips(d: DieVisual, n: Vector3, col: Color) -> void:
	var pips := d.faces.get_node_or_null("Pips")
	if pips == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for p in pips.get_children():
		if p is MeshInstance3D and (p as MeshInstance3D).position.dot(n) > d.edge * 0.3:
			(p as MeshInstance3D).material_override = mat


func _decal_quad(root: Node3D, n: Vector3, u: Vector3, v: Vector3, lift: float, w: float, ht: float,
		off: Vector2, col: Color, glow: bool) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(w, ht)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	if glow:
		# Unshaded: the lit-die ember glow would wash a shaded colour out.
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(u, v, n), _at + n * lift + u * off.x + v * off.y)
	root.add_child(mi)


## In-plane centre of the mark being placed (zero on a cube; set per d4/d8 face).
var _at := Vector3.ZERO


## A rare glyph mark is sized for a cube face: shrink it to [param w] wide
## and slide it to this d4/d8 face's spot.
func _fit_rare_mark(mark: Node3D, d: DieVisual, w: float) -> void:
	var dia: float = d.edge * float(mark.get_meta("size", 1.0))
	var k := minf(1.0, w / maxf(dia, 0.0001))
	mark.transform = Transform3D(mark.transform.basis.scaled_local(Vector3(k, k, 1)), _at + mark.transform.basis.z.normalized() * mark.transform.origin.dot(mark.transform.basis.z.normalized()))


## A square outline (4 strips, one colour each) of outer size `size`.
func _decal_frame(root: Node3D, n: Vector3, u: Vector3, v: Vector3, lift: float, size: float, thick: float, cols: Array[Color]) -> void:
	var o := (size - thick) * 0.5
	_decal_quad(root, n, u, v, lift, size, thick, Vector2(0, o), cols[0], true)
	_decal_quad(root, n, u, v, lift, thick, size, Vector2(o, 0), cols[1], true)
	_decal_quad(root, n, u, v, lift, size, thick, Vector2(0, -o), cols[2], true)
	_decal_quad(root, n, u, v, lift, thick, size, Vector2(-o, 0), cols[3], true)


## The Wild rim: the same frame, brass / dark strips, then a brass square
## tick over each corner (a hair higher, so it sits on top of the strips).
func _wild_frame(root: Node3D, n: Vector3, u: Vector3, v: Vector3, lift: float, size: float, thick: float) -> void:
	_decal_frame(root, n, u, v, lift, size, thick, WILD_FRAME)
	var o := (size - thick) * 0.5
	for c: Vector2 in [Vector2(-o, o), Vector2(o, o), Vector2(o, -o), Vector2(-o, -o)]:
		_decal_quad(root, n, u, v, lift + 0.0002, thick, thick, c, WILD_TICK, true)


## A Cracked die shatters: burst, gone for the rest of the table.
func _shatter_die(d: DieVisual) -> void:
	all_dice.erase(d)
	bhud.flash("CRACKED DIE SHATTERED", Color("#FF2E3E"))
	sfx.play(&"rim_hit", 0.55, 0.0)
	_camera_shake(tuning.shake_craps_px * 0.5, 0.2)
	_embers(d.global_position, 30, 12)
	_set_lit(d, false)
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector3.ONE * 1.25, 0.06)
	tw.tween_property(d, "scale", Vector3.ONE * 0.05, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: d.visible = false)


## The dice the next throw uses (also resizes the per-die playback state).
func _set_active(list: Array[DieVisual]) -> void:
	dice = list.duplicate()
	var n := dice.size()
	for i in n:
		dice[i].die_id = i
	_remap_from.resize(n)
	_remap_to.resize(n)
	_last_impact.resize(n)
	_rest_sent.resize(n)
	_tumble_sent.resize(n)
	_remap_from.fill(Quaternion.IDENTITY)
	_remap_to.fill(Quaternion.IDENTITY)
	if sim != null:
		sim.ensure_bodies(n)


func _sync_colliders() -> void:
	super()
	while _pot_bodies.size() < MAX_HANDFUL:
		var b := StaticBody3D.new()
		b.name = "PotDie%d" % _pot_bodies.size()
		b.set_meta("surface", &"pot_die")
		var mat := PhysicsMaterial.new()
		mat.friction = 0.5
		mat.bounce = 0.3
		b.physics_material_override = mat
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE * tuning.die_size
		cs.shape = box
		b.add_child(cs)
		add_child(b)
		_pot_bodies.append(b)
	for k in _pot_bodies.size():
		var on := k < pot_dice.size() and is_instance_valid(pot_dice[k])
		(_pot_bodies[k].get_child(0) as CollisionShape3D).disabled = not on
		_pot_bodies[k].global_position = pot_slot(k) if on else Vector3(0, -5, 0)


## Free pot slots can hold a cold die that came to rest there; when a die is
## potted into that slot the cold die is nudged toward the middle.
func _clear_slot(at: Vector3, except: DieVisual) -> void:
	for j in throw_dice.size():
		var o := throw_dice[j]
		if o == except or run.potted.has(j):
			continue
		var p := _felt_pos[j] if j < _felt_pos.size() else o.global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < tuning.die_size * 1.15:
			var to := Vector3(p.x, p.y, at.z + tuning.die_size * 1.3)
			_felt_pos[j] = to
			var tw := o.create_tween()
			tw.tween_property(o, "global_position", to, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_lit(d: DieVisual, on: bool) -> void:
	# Material only (design section 4): a lit die glows ember, no lights or
	# flames. Turning "off" returns it to the plain bone look.
	var was := _lights.has(d)
	if on:
		_lights[d] = true
	else:
		_lights.erase(d)
	d.set_glow_state(on, false)
	RareDieLook.set_marks_lit(d, on)
	if was != on and events != null:
		events.die_lit_changed.emit(event_id(d), on)


## A thrown die that did not score goes matte grey ("cold") once it settles.
func _set_cold(d: DieVisual) -> void:
	if _lights.has(d) and events != null:
		events.die_lit_changed.emit(event_id(d), false)
	_lights.erase(d)
	d.set_glow_state(false, true)
	RareDieLook.set_marks_lit(d, false)


func _refuse(why: String) -> void:
	sfx.play(&"chip_refuse")
	_set_why(why)
