## Rare dice v1 (design/rare_dice_v1.md) QA follow-ups on #174: a rare's
## locked pre-carved faces can't be taken by event remove-mod (ruling 5),
## and the shop's rare roll draws from its own seed.
##   godot --headless --path . --script res://tests/test_rare_dice_rulings.gd
extends SceneTree

const K := EventEffectData.Kind
const T := EventEffectData.Target

var _passed: int = 0
var _failed: int = 0
var _run: RunData


func _initialize() -> void:
	_run = load("res://resources/map/bonfire_run.tres") as RunData
	_test_event_targets()
	_test_picked_locked()
	_test_random_skips_locked()
	_test_rare_seed()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	_run = null
	quit(1 if _failed > 0 else 0)


func _check(c: bool, name: String) -> void:
	if c:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


## The Altar's "give a face mod, +15 Soul" choice (picked removal).
func _altar_soul() -> EventChoiceData:
	var ev: EventData = load("res://resources/events/altar.tres")
	return ev.choices[0]


func _pyre_bag() -> RunProgress:
	var p := RunProgress.new(_run)
	p.add_die(&"pyre")
	p.soul = 10
	return p


## Only a rare's presets in the bag: nothing removable, the Altar refuses.
func _test_event_targets() -> void:
	var p := _pyre_bag()
	var d := p.dice.size() - 1
	_check(p.modded_faces().size() == 2 and p.removable_faces().is_empty() and not p.has_removable_mod(),
		"targets: a rare's locked presets aren't removable")
	var choice := _altar_soul()
	_check(EventApplier.why_not(choice, p) != "", "targets: Altar give-a-mod unavailable with only rare presets")
	var log := EventApplier.apply(choice, p, RandomNumberGenerator.new(), [Vector2i(d, 5)] as Array[Vector2i])
	_check(log.size() == 1 and log[0].begins_with("refused"), "targets: Altar apply refused %s" % [log])
	_check(p.soul == 10 and p.dice[d].faces[4] == &"ember_pip" and p.dice[d].faces[5] == &"hellfire",
		"targets: no Soul paid, presets intact")


## A real mod elsewhere makes the choice available, but picking a locked
## face is refused with no cost and no reward.
func _test_picked_locked() -> void:
	var p := _pyre_bag()
	var d := p.dice.size() - 1
	p.set_face(0, 0, &"wild")
	var choice := _altar_soul()
	_check(EventApplier.why_not(choice, p) == "", "picked: Altar available with a removable mod")
	_check(not EventApplier.pick_ok(choice.effects[0], p, Vector2i(d, 5)), "picked: a locked face isn't a legal pick")
	var log := EventApplier.apply(choice, p, RandomNumberGenerator.new(), [Vector2i(d, 5)] as Array[Vector2i])
	_check(log.size() == 1 and log[0].begins_with("refused"), "picked: locked pick refused %s" % [log])
	_check(p.soul == 10 and p.dice[d].faces[5] == &"hellfire" and p.dice[0].faces[0] == &"wild",
		"picked: no Soul paid, nothing removed")
	log = EventApplier.apply(choice, p, RandomNumberGenerator.new(), [Vector2i(0, 0)] as Array[Vector2i])
	_check(p.soul == 25 and p.dice[0].faces[0] == &"", "picked: a normal mod still trades for +15 Soul %s" % [log])


## A random removal never lands on a locked face.
func _test_random_skips_locked() -> void:
	var remove := EventEffectData.new()
	remove.kind = K.REMOVE_FACE_MOD
	remove.target = T.RANDOM
	var choice := EventChoiceData.new()
	choice.effects.append(remove)
	var ok := true
	for s in 60:
		var p := _pyre_bag()
		var d := p.dice.size() - 1
		p.set_face(1, 2, &"wild")
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		EventApplier.apply(choice, p, rng)
		ok = ok and p.dice[1].faces[2] == &"" and p.dice[d].faces[4] == &"ember_pip" and p.dice[d].faces[5] == &"hellfire"
	_check(ok, "random: removal takes the normal mod, never a rare preset")
	var p2 := _pyre_bag()
	var log := EventApplier.apply(choice, p2, RandomNumberGenerator.new())
	_check(log == ["no valid face"] and p2.modded_faces().size() == 2, "random: only presets -> no valid face %s" % [log])


func _offers(run: MapRun) -> Array:
	return [run.shop_dice[0].id, run.shop_mods.map(func(m): return m.id), run.shop_seals.duplicate(), run.shop_premium_seal]


## Common offers match with the rare roll on and off; the hit follows the
## &"shop_rare" rng, not &"shop".
func _test_rare_seed() -> void:
	var off := _run.duplicate() as RunData
	off.shop_rare_die_chance = off.shop_rare_die_chance.duplicate()
	off.shop_rare_die_chance.fill(0.0)
	var same := true
	var follows := true
	var differs := false
	for s in 400:
		var a := MapRun.new(_run, s)
		var b := MapRun.new(off, s)
		for r in [a, b]:
			r.floor_index = 2
			r.screen = MapRun.Screen.SHOP
			r._roll_shop()
		same = same and _offers(a) == _offers(b) and (a.shop_dice[1].is_rare() or a.shop_dice[1] == b.shop_dice[1])
		same = same and not b.shop_dice[1].is_rare()
		var own := a._rng(&"shop_rare", 0).randf() < a.rare_die_chance()
		var shared := a._rng(&"shop", 0).randf() < a.rare_die_chance()
		follows = follows and a.shop_dice[1].is_rare() == own
		differs = differs or own != shared
	_check(same, "seed: common offers identical with and without the rare roll")
	_check(follows, "seed: rare hits follow the shop_rare rng")
	_check(differs, "seed: shop_rare and shop rngs differ (the check above can tell them apart)")
