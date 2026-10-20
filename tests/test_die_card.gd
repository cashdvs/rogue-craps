## DieCard / DieCardInfo (extracted from DicePanel._card, no behaviour
## change): from_run gives the same text as the old card, read-only cards
## disable every face, and picks emit face_picked / DicePanel.picked.
##   godot --headless --path . --script res://tests/test_die_card.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var _run: RunData


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	var p := RunProgress.new(_run)
	p.add_die(&"mirror")
	p.set_face(0, 0, &"wild")
	p.set_face(1, 2, RunDie.BLANK)
	p.set_face(5, 1, &"heavy")
	_test_same_text(p)
	_test_read_only(p)
	_test_picks(p)
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## The pre-extraction DicePanel._card text, as [header, faces (text|tooltip)].
func _old(p: RunProgress, d: int) -> Array:
	var def := p.die_def(d)
	var head := "Die %d: %s  -  %s" % [d + 1, p.die_name(d), def.description if def != null else "Bone die: plain faces 1 to 6."]
	var faces: Array[String] = []
	for f in p.dice[d].faces.size():
		var mod: StringName = p.dice[d].faces[f]
		var value: int = def.faces[f] if def != null and f < def.faces.size() else f + 1
		var mn := "Blank" if mod == RunDie.BLANK else String(mod).capitalize()
		for m in p.data.face_mods:
			if m.id == mod:
				mn = m.display_name.trim_suffix(" Face")
		faces.append("%s|%s" % [str(value) if mod == &"" else "%d %s" % [value, mn], "Face %d: %s" % [value, mn if mod != &"" else "Plain face."]])
	return [head, faces]


func _face_buttons(card: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in card.get_child(card.get_child_count() - 1).get_children():
		out.append(c as Button)
	return out


func _test_same_text(p: RunProgress) -> void:
	var panel := DicePanel.new()
	panel.build(p, {"seals": false})
	var same := true
	for d in p.dice.size():
		var card := panel.get_child(d + 1)
		var old := _old(p, d)
		var faces: Array[String] = []
		for b in _face_buttons(card):
			faces.append("%s|%s" % [b.text, b.tooltip_text])
		var ok: bool = card is DieCard and (card.get_child(0) as Label).text == old[0] and faces == old[1]
		if not ok:
			print("  die %d: %s / %s vs %s" % [d, (card.get_child(0) as Label).text, faces, old])
		same = same and ok
	_check(same, "from_run: every card's header and faces read as before (plain, Wild, Blank, Mirror + Heavy)")
	var info := DieCardInfo.from_run(p, 0)
	_check(info.display_name == "Bone" and info.ability == DieCardInfo.BONE_LINE and info.shape == &"d6" and info.faces.size() == 6
		and info.faces[0] == {"value": 1, "mod": &"wild", "mod_name": "Wild"} and info.next_mod_price == -1, "from_run: the info fields")
	var priced := DicePanel.new()
	priced.build(p, {"seals": false, "allowed": func(_at: Vector2i) -> bool: return true, "price": func(d: int) -> int: return 10 + d})
	_check((priced.get_child(2).get_child(1) as Label).text == DicePanel.NEXT_MOD % 11, "pick mode: the next mod price line as before")
	panel.free()
	priced.free()


func _test_read_only(p: RunProgress) -> void:
	var card := DieCard.create(DieCardInfo.from_run(p, 0))
	var all_off := true
	for b in _face_buttons(card):
		all_off = all_off and b.disabled and b.tooltip_text.begins_with("Face ")
	_check(all_off, "read-only: every face is disabled, tooltips kept")
	var hits: Array[int] = []
	card.face_picked.connect(func(f: int) -> void: hits.append(f))
	card.set_die(DieCardInfo.from_run(p, 0), true, func(_f: int) -> bool: return true)
	_check(_face_buttons(card).all(func(b: Button) -> bool: return b.disabled), "read-only: `allowed` is ignored")
	card.free()


func _test_picks(p: RunProgress) -> void:
	var card := DieCard.new()
	var hits: Array[int] = []
	card.face_picked.connect(func(f: int) -> void: hits.append(f))
	card.set_die(DieCardInfo.from_run(p, 0), false, func(f: int) -> bool: return f != 0)
	var bs := _face_buttons(card)
	_check(bs[0].disabled and bs[0].tooltip_text.ends_with(DieCard.TAKEN) and not bs[3].disabled, "pick: `allowed` greys faces; a modded one says why")
	bs[3].pressed.emit()
	_check(hits == ([3] as Array[int]), "pick: a face emits face_picked(3)")
	card.free()
	var panel := DicePanel.new()
	var got: Array[Vector2i] = []
	panel.picked.connect(func(at: Vector2i) -> void: got.append(at))
	panel.build(p, {"seals": false, "allowed": func(at: Vector2i) -> bool: return at.x == 5})
	_face_buttons(panel.get_child(6))[4].pressed.emit()
	_check(got == ([Vector2i(5, 4)] as Array[Vector2i]), "DicePanel: face_picked maps to picked(Vector2i(die, face))")
	panel.free()
