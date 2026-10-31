## Face mods in Bonfire scoring (FaceModData: Hellfire, Wild, Twin, Blank),
## alone and combined, plus lighting and the run's bounty ticks.
##   godot --headless --path . --script res://tests/test_bonfire_face_mods.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0
var t: BonfireTuning
var H: FaceModData
var W: FaceModData
var T: FaceModData
var B: FaceModData


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func d(v: int, m: FaceModData = null) -> Dictionary:
	return BonfireScoring.make_die(v, m)


func sc(dice: Array, bonus: int = 0) -> Dictionary:
	return BonfireScoring.score_selection(dice, t, bonus)


func pts(dice: Array, bonus: int = 0) -> int:
	return int(sc(dice, bonus)["points"])


func combo(dice: Array) -> StringName:
	return sc(dice)["combo"]


func lit(dice: Array) -> Array[int]:
	return BonfireScoring.lit_indices(dice, t)


func _initialize() -> void:
	t = load("res://resources/tuning/bonfire_tuning.tres") as BonfireTuning
	H = load("res://resources/mods/hellfire.tres") as FaceModData
	W = load("res://resources/mods/wild.tres") as FaceModData
	T = load("res://resources/mods/twin.tres") as FaceModData
	B = load("res://resources/mods/blank.tres") as FaceModData
	check(H.effect == FaceModData.Effect.MULT_FACTOR and is_equal_approx(H.mult_factor, 1.5), "Hellfire resource: x1.5")
	check(W.effect == FaceModData.Effect.WILD and T.effect == FaceModData.Effect.TWIN and B.effect == FaceModData.Effect.BLANK, "mod resources load")

	# Plain dice as dictionaries score like ints.
	check(pts([d(4), d(4), d(4)]) == 126 and pts([4, 4, 4]) == 126, "plain {value, mod:null} == int")

	# --- Hellfire ---
	check(pts([d(4, H), d(4), d(4)]) == 189 and is_equal_approx(float(sc([d(4, H), d(4), d(4)])["factor"]), 1.5), "Hellfire in trips: (30+12)x3 x1.5 = 189")
	check(pts([d(4, H), d(4, H), d(4)]) == floori(42 * 3 * 2.25), "two Hellfires stack multiplicatively: x2.25 = 283")
	check(pts([d(4, H), d(4, H), d(4, H)]) == floori(42 * 3 * 3.375), "three Hellfires: x3.375")
	check(pts([d(5, H)]) == 15, "Hellfire single 5: (5+5)x1 x1.5 = 15")
	check(pts([d(1, H)]) == 9, "Hellfire single 1: 6 x1.5 = 9")
	check(pts([d(3, H), d(3)]) == 48, "Hellfire pair of 3s: 32 x1.5 = 48")
	check(pts([d(4, H), d(4), d(4)], 1) == floori(42 * 4 * 1.5), "Hellfire applies after the Hot Hand bonus: 42 x (3+1) x1.5")
	check(not sc([d(4, H), d(4), d(4), d(2)])["valid"], "Hellfire doesn't make a dead die legal")
	check(lit([d(2, H), d(3), d(6)]).is_empty(), "a Hellfire 2 alone doesn't light")
	check(BonfireScoring.formula(sc([d(4, H), d(4), d(4)])) == "Trips  (30 + 12) x 3 x1.5 = 189", "formula shows the mod factor")

	# --- Twin ---
	check(combo([d(4, T)]) == &"pair" and pts([d(4, T)]) == (10 + 8) * 2, "a Twin 4 alone is a pair of 4s = 36")
	check(combo([d(1, T)]) == &"pair", "a Twin 1 is a pair, not a single")
	check(combo([d(4, T), d(4)]) == &"trips" and pts([d(4, T), d(4)]) == (30 + 12) * 3, "Twin 4 + 4 = trips (faces sum 12)")
	check(combo([d(4, T), d(4, T)]) == &"quads" and pts([d(4, T), d(4, T)]) == (60 + 16) * 8, "two Twin 4s = quads")
	check(combo([d(6, T), d(6, T), d(6)]) == &"five_kind", "Twin 6 + Twin 6 + 6 = five of a kind")
	check(combo([d(3, T), d(5), d(5)]) == &"two_pair", "Twin 3 + 5 + 5 = two pair")
	check(combo([d(3, T), d(3), d(5, T)]) == &"full_house" and pts([d(3, T), d(3), d(5, T)]) == (40 + 19) * 5, "Twin 3 + 3 + Twin 5 = full house")
	check(not sc([d(2, T), d(3), d(4)])["valid"], "a Twin breaks a run (2,2,3,4 isn't a combo)")
	check(lit([d(2, T), d(3), d(6)]) == [0], "a lone Twin 2 lights (it's a pair)")
	check(sc([d(4, T), d(4)])["values"] == [4, 4, 4], "Twin effective values")

	# --- Wild ---
	check(combo([d(3, W)]) == &"single" and pts([d(3, W)]) == 10, "a lone Wild is the best single: a 5 = 10")
	check(combo([d(1, W), d(4), d(4)]) == &"trips" and pts([d(1, W), d(4), d(4)]) == 126, "Wild + 4 + 4 = trips of 4s")
	check(combo([d(2, W), d(4), d(5)]) == &"run3" and pts([d(2, W), d(4), d(5)]) == (20 + 15) * 2, "Wild + 4 + 5 = best run 4-5-6 (70) over 3-4-5")
	check(combo([d(6, W), d(6)]) == &"pair" and pts([d(6, W), d(6)]) == (10 + 12) * 2, "Wild + 6 = pair of 6s")
	check(combo([d(1, W), d(2), d(3), d(4), d(6)]) == &"run5" and pts([d(1, W), d(2), d(3), d(4), d(6)]) == (60 + 20) * 6, "Wild completes 2-3-4-5-6")
	check(combo([d(1, W), d(1, W), d(1, W)]) == &"trips" and pts([d(1, W), d(1, W), d(1, W)]) == (30 + 18) * 3, "three Wilds = trips of 6s")
	check(combo([d(1, W), d(3), d(3), d(5), d(5)]) == &"full_house" and pts([d(1, W), d(3), d(3), d(5), d(5)]) == (40 + 21) * 5, "Wild picks the best full house (5s over 3s)")
	check(combo([d(1, W), d(6), d(6), d(6), d(6)]) == &"five_kind", "Wild + four 6s = five of a kind (beats a run)")
	check(not sc([d(1, W), d(2), d(6)])["valid"], "a Wild can't rescue 2 + 6")
	check(lit([d(1, W), d(2), d(6)]) == [0, 1, 2], "Wild + 2 + 6: all light (Wild pairs with either), though all three don't pot together")
	check(lit([d(1, W), d(2, B), d(6, B)]) == [0], "a Wild always lights (a single 5 at worst); Blanks stay cold")
	check(lit([d(1, W), d(2), d(4)]) == [0, 1, 2], "Wild lights 2 and 4 as the run 2-3-4")
	check(lit([d(2), d(4), d(6)]).is_empty(), "control: 2-4-6 is a bust without the Wild")

	# --- Blank ---
	check(not sc([d(5, B)])["valid"] and not sc([d(4, B), d(4), d(4)])["valid"], "a Blank never scores, even in a set")
	check(lit([d(1, B), d(2), d(6)]).is_empty(), "a Blank 1 doesn't light (bust)")
	check(lit([d(4, B), d(4), d(4)]) == [1, 2], "a Blank doesn't count toward trips (the other two still pair)")
	check(not BonfireScoring.can_extend([0], [d(4, B), d(4), d(4)], t), "a Blank can't be selected")

	# --- Mixed ---
	check(pts([d(4, T), d(4, H)]) == floori(42 * 3 * 1.5) and combo([d(4, T), d(4, H)]) == &"trips", "Twin + Hellfire: trips x1.5")
	check(pts([d(1, W), d(4, H), d(4)]) == 189, "Wild + Hellfire 4 + 4 = trips x1.5")
	check(combo([d(1, W), d(3, T)]) == &"trips" and pts([d(1, W), d(3, T)]) == (30 + 9) * 3, "Wild + Twin 3 = trips of 3s")
	check(combo([d(5, W), d(2, T), d(2, T)]) == &"five_kind", "Wild + two Twin 2s = five of a kind")
	check(not sc([d(1, W), d(4, B)])["valid"], "a Blank spoils any pot, even with a Wild")
	check(pts([d(4, T), d(4, H), d(4, H)]) == floori((60 + 16) * 8 * 2.25), "Twin + 2 Hellfires = quads x2.25")

	# --- Run integration: lighting, Hot Hand and bounties with mods ---
	var r := BonfireRun.new(t, null, 30, 3)
	check(r.soul == 30 and r.cold == 3 and r.dice_count == 3, "run with 3 dice and Soul 30")
	check(r.set_throw([4, 4, 2] as Array[int], [T, null, null]), "Twin throw lights")
	check(r.lit() == [0, 1], "Twin 4 + 4 light, 2 cold")
	r.toggle(0)
	r.toggle(1)
	check(r.selection()["combo"] == &"trips" and r.throw_points() == 126, "potting Twin 4 + 4 scores trips")
	r.bank()  # 2 of 3 dice potted: no cold rethrow, bank it
	check(r.is_ticked(t.table_goal.required[0]), "Twin trips ticks the Triple bounty")
	check(r.set_throw([5, 5, 5] as Array[int]), "next hand lights")
	r.toggle(0)
	r.toggle(1)
	r.toggle(2)
	check(r.is_hot(), "Hot Hand = all 3 dice potted")
	var rt := r.rethrow()
	check(rt["hot"] and r.cold == 3, "Hot Hand scoops all 3 back")
	r.set_throw([2, 6, 6] as Array[int], [B, null, null])
	check(r.lit() == [1, 2], "Blank 2 stays cold in a throw")
	print("test_bonfire_face_mods: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
