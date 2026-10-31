## Playtest e1cd912 bug 1: a rare die bought in the shop reaches the next
## table. Real path: MapRun shop buy_die -> RunProgress bag -> MapRun
## table_setup -> Bonfire3D (scenes/bonfire.tscn) -> the BonfireRun throw.
extends SceneTree

const RARES: Array[StringName] = [&"barrel", &"fortune", &"usurer", &"gallows", &"beacon"]

var _passed: int = 0
var _failed: int = 0
var _t: BonfireTuning
var _data: RunData


func _initialize() -> void:
	_t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	_data = load("res://resources/map/bonfire_run.tres") as RunData
	for id in RARES:
		await _test_rare(id)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_t = null
	_data = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, what: String) -> void:
	_passed += int(c)
	_failed += int(not c)
	if not c: print("FAIL: ", what)


func _shape(id: StringName) -> DieShape:
	for s in _data.shapes:
		if s.id == id: return s
	return null


func _test_rare(id: StringName) -> void:
	var sh := _shape(id)
	_check(sh != null and sh.is_rare(), "%s: is a rare shape in the run data" % id)
	if sh == null:
		return
	var run := MapRun.new(_data, 7)
	run.screen = MapRun.Screen.SHOP
	run.progress.embers = 999
	run.shop_dice = [sh, sh] as Array[SpecialDieData]
	var before := run.progress.dice.size()
	_check(run.buy_die(1), "%s: the shop sells it" % id)
	var bag := run.progress.dice
	_check(bag.size() == before + 1 and bag[-1].shape == id, "%s: it is in the bag (%d dice, last %s)" % [id, bag.size(), bag[-1].shape])
	run.screen = MapRun.Screen.MAP
	for n in run.map.reachable():
		if run.screen == MapRun.Screen.MAP and run.map.node(n).type == MapGenData.NodeType.TABLE:
			run.choose_node(n)
	var rs := run.table_setup()
	var at := -1
	for i in rs.table_dice.size():
		if rs.table_dice[i].id == id: at = i
	_check(at >= 0 and rs.table_dice[at].faces == sh.faces, "%s: the next table's dice carry it with its faces (at %d)" % [id, at])
	var b := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	b.setup = rs.to_table_setup(_t)
	b.tutorial_override = 0
	b.test_speed = 10.0
	root.add_child(b)
	await process_frame
	await process_frame
	for k in 900:
		if b.phase == Table3D.Phase.BET and b.run.state == BonfireRun.State.AIM and not b.hand_moving(): break
		await process_frame
	var on_table := b.dice.size() == bag.size() and at >= 0 and at < b.dice.size() and b._td(at).id == id
	_check(on_table, "%s: it is one of the %d dice in hand at the table" % [id, b.dice.size()])
	if on_table:
		_check_look(b, at, id, sh)
	var top: int = sh.faces.max()
	var rig: Array[int] = []
	for i in b.dice.size():
		rig.append(top if i == at else 2)
	b.rig_faces(rig)
	b.quick_throw()
	await b.sequence_finished
	var landed: Array = b.run.last_throw.dice if b.run.last_throw != null else []
	var td: TableDie = landed[at] if at >= 0 and at < landed.size() else null
	_check(td != null and td.id == id and b.run.last_throw.values[at] == top,
		"%s: it lands in the throw showing its %d (got %s)" % [id, top, b.run.last_throw.values if b.run.last_throw != null else []])
	b.queue_free()
	await process_frame


## The rare reads apart from Bone at the table: tinted body and its marks.
func _check_look(b: Bonfire3D, at: int, id: StringName, sh: DieShape) -> void:
	var d := b.dice[at]
	var body: Color = d.body_material.get_shader_parameter("albedo")
	_check(body.is_equal_approx(RareDieLook.body_color()), "%s: body is the rare tint (%s)" % [id, body.to_html(false)])
	var bone := b.dice[0 if at != 0 else 1]
	var bone_body: Color = bone.body_material.get_shader_parameter("albedo")
	var dist := Vector3(body.r - bone_body.r, body.g - bone_body.g, body.b - bone_body.b).length()
	_check(dist > 0.05, "%s: visibly distinct from the Bone die beside it (%.3f)" % [id, dist])
	_check(d.faces.get_node("Body").has_node("RareTrim") and not bone.faces.get_node("Body").has_node("RareTrim"), "%s: brass bevel trim on the rare only" % id)
	var fm := d.faces.get_node_or_null("FaceMods")
	var want := 0
	var have := 0
	for v in sh.preset_mods:
		var slot: int = sh.faces.find(v) + 1
		if RareDieLook.MARKS.has(StringName(sh.preset_mods[v])) and slot >= 1 and slot <= 6:
			want += 1
			if fm != null and fm.get_node_or_null("RareMark_%s" % sh.preset_mods[v]) != null:
				have += 1
	_check(have == want, "%s: shows its %d rare marks (%d)" % [id, want, have])
	if fm != null:
		for m in fm.get_children():
			if m.has_meta("ink"):
				var ink := m.get_meta("ink") as StandardMaterial3D
				b._set_lit(d, true)
				var lit := ink.emission_energy_multiplier
				b._set_lit(d, false)
				_check(lit > 0.0 and lit <= 0.3 + 1e-6 and ink.emission_energy_multiplier == 0.0, "%s: %s mark glows only while lit" % [id, m.name])
