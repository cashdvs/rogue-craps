## Rare dice v1 UI (design/rare_dice_v1.md, PR 2): the shop card's Rare tag,
## the can't-recarve tooltip on a rare's forge-carved face, and the art keys
## with their stand-in bodies.
##   godot --headless --path . --script res://tests/test_rare_dice_ui.gd
extends SceneTree

const RARES := [&"pyre", &"gilt", &"lodestone", &"ossuary"]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_test_strings()
	await _test_shop_tag()
	_test_locked_tooltip()
	_test_not_locked()
	_test_art_keys()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _test_strings() -> void:
	_check(EconomyStrings.SHOP_RARE_TAG == "Rare: its carved faces come with the die.", "shop_rare_tag text")
	_check(EconomyStrings.RARE_CARVED_LOCKED == "Carved at the forge; this face cannot be recarved.", "rare_carved_locked text")


## Steps the shop's reroll seed until slot 2 is a rare, then reads the cards.
func _test_shop_tag() -> void:
	var scene: RunScreen = (load("res://scenes/run.tscn") as PackedScene).instantiate()
	scene.run_seed = 1234
	root.add_child(scene)
	await process_frame
	var run := scene.run
	run.screen = MapRun.Screen.SHOP
	var hit := false
	for k in 300:
		run.shop_rerolls = k
		run._roll_shop()
		if run.shop_dice.size() > 1 and run.shop_dice[1] != null and run.shop_dice[1].is_rare():
			hit = true
			break
	_check(hit, "some reroll seed puts a rare in slot 2")
	scene.refresh()
	# The counter (PR C removed the old text list): each die item's offer.
	var rare_it: ShopItem = null
	var common_it: ShopItem = null
	for it in scene.shop_screen.items:
		if it.offer.kind == ShopOffer.Kind.DIE:
			if it.offer.index == 1:
				rare_it = it
			elif it.offer.index == 0:
				common_it = it
	_check(rare_it != null and rare_it.offer.rare and rare_it.offer.id == run.shop_dice[1].id, "rare card shows the Rare tag")
	_check(common_it != null and not common_it.offer.rare, "common card has no Rare tag")
	scene.queue_free()
	await process_frame


func _test_locked_tooltip() -> void:
	var data := load("res://resources/map/bonfire_run.tres") as RunData
	for id in RARES:
		var p := RunProgress.new(data)
		_check(p.add_die(id), "%s added" % id)
		var d := p.dice.size() - 1
		var info := DieCardInfo.from_run(p, d)
		var card := DieCard.new()
		# The carve picker's rule (MapRun.free_face): modded faces can't be picked.
		card.set_die(info, false, func(f: int) -> bool: return p.dice[d].faces[f] == &"")
		var row: HBoxContainer = card.get_child(card.get_child_count() - 1)
		var seen := 0
		for f in info.faces.size():
			var face: Dictionary = info.faces[f]
			var tip: String = (row.get_child(f) as Button).tooltip_text
			_check(bool(face.get("locked", false)) == p.face_locked(d, f), "%s face %d locked flag" % [id, f])
			if bool(face.get("locked", false)):
				seen += 1
				_check(EconomyStrings.RARE_CARVED_LOCKED in tip and not DieCard.TAKEN in tip, "%s face %d locked tooltip" % [id, f])
				# A tap (Android: no hover) refuses the carve and shows the message.
				var b := row.get_child(f) as Button
				var picked := [false]
				card.face_picked.connect(func(_i: int) -> void: picked[0] = true)
				_check(not b.disabled, "%s face %d tappable" % [id, f])
				b.pressed.emit()
				var l := card.get_node_or_null("Refused") as Label
				_check(l != null and l.text == EconomyStrings.RARE_CARVED_LOCKED and not picked[0],
					"%s face %d tap refuses and shows the locked message" % [id, f])
		_check(seen > 0, "%s has forge-carved faces" % id)
		card.free()


## Only a rare's forge-carved faces are locked: a face the player carves on a
## rare, and a common die's preset (Powder Keg's twin), aren't flagged.
func _test_not_locked() -> void:
	var data := load("res://resources/map/bonfire_run.tres") as RunData
	var p := RunProgress.new(data)
	p.add_die(&"pyre")
	var d := p.dice.size() - 1
	_check(p.set_face(d, 0, &"wild"), "pyre face 1 carvable")
	var info := DieCardInfo.from_run(p, d)
	_check(info.faces[0]["mod"] == &"wild" and not info.faces[0].has("locked"), "carved face on a rare not locked")
	var q := RunProgress.new(data)
	_check(q.add_die(&"powder_keg"), "powder keg added")
	var k := q.dice.size() - 1
	var kinfo := DieCardInfo.from_run(q, k)
	var preset := 0
	var flagged := false
	for f in kinfo.faces.size():
		preset += 1 if kinfo.faces[f]["mod"] != &"" else 0
		flagged = flagged or kinfo.faces[f].has("locked") or q.face_locked(k, f)
	_check(preset > 0 and not flagged, "common die's preset face not locked")


func _test_art_keys() -> void:
	var want := {&"pyre": &"hellfire_d6", &"gilt": &"gilded_d6", &"lodestone": &"mirror_d6", &"ossuary": &"bone_d6"}
	for id in RARES:
		var key := DiceIds.asset_key(id)
		_check(key == StringName("%s_d6" % id), "%s art key" % id)
		_check(DiceIds.RARE_ART_BODIES.get(key) == want[id], "%s stand-in body" % id)
		var body := DiceIds.body_key(id)
		_check(ResourceLoader.exists("res://art/models/dice/%s.glb" % body), "%s body %s exists" % [id, body])
