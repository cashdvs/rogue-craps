## EmberPrice (shop redesign, AD): the ember coin is a #C8783C disc about
## 0.8x the numeral's cap height, centred on the digits (not a degree-sign
## dot at the top left), with a 4 spec px gap before the number.
##   godot --headless --path . --script res://tests/test_ember_price.gd
extends SceneTree

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	var cases := [[28, 1.0, "18"], [40, 1.0, "120"], [28, 4.92, "8-12"]]
	var built: Array[EmberPrice] = []
	for c: Array in cases:
		var p := EmberPrice.new()
		p.setup(c[2], int(c[0] * c[1]), Color("#E8DCC0"), c[1])
		root.add_child(p)
		built.append(p)
	await process_frame  # Let the containers lay out.
	await process_frame
	for i in cases.size():
		_test_one(built[i], cases[i][1])
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _test_one(p: EmberPrice, k: float) -> void:
	var c := p.coin.get_global_rect()
	var l := p.label.get_global_rect()
	var px := p.label.get_theme_font_size("font_size")
	var font := p.label.get_theme_font("font")
	var cap := px * 0.71  # Measured cap height of the numeral font.
	_check(p.get_child(0) == p.coin and p.get_child(1) == p.label, "coin comes before the number")
	_check(absf(c.size.x - cap * 0.8) <= 1.0 and c.size.x == c.size.y, "coin %s is ~0.8x the %.0f px cap" % [c.size, cap])
	# Digits sit on the baseline: their middle is half a cap above it.
	var digits_mid := l.position.y + font.get_ascent(px) - cap / 2
	_check(absf(c.get_center().y + p.drop - digits_mid) <= 1.0, "coin centred on the digits (%.1f vs %.1f)" % [c.get_center().y + p.drop, digits_mid])
	_check(absf(l.position.x - c.end.x - 4 * k) <= 1.0, "4 spec px gap before the number (got %.1f)" % (l.position.x - c.end.x))
	_check(EmberPrice.COIN == Color("#C8783C"), "coin colour")
	_check(p.label.text != "" and p.coin.mouse_filter == Control.MOUSE_FILTER_IGNORE, "number shown; coin ignores clicks")
