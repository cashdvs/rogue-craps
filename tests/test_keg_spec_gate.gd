## Keg specular is keg-only (QA on #270). Evaluates keg_spec_keep and
## keg_spec_lobe in keg_stave_dim.gdshaderinc (used by toon_noir and
## toon_noir_twin). A non-keg (keg_body 0) keeps specular on every cell and
## uses step(spec_size, N·H). Headless Forward+ never finishes a frame here,
## and ./run_tests.sh is always --headless, so this reads the shader.
##   godot --headless --path . --script res://tests/test_keg_spec_gate.gd
extends SceneTree

const INCLUDE := "res://shaders/3d/keg_stave_dim.gdshaderinc"
const SHADERS: Array[String] = [
	"res://shaders/3d/toon_noir.gdshader",
	"res://shaders/3d/toon_noir_twin.gdshader",
]

var _passed := 0
var _failed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL  ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var src := _strip(FileAccess.get_file_as_string(INCLUDE))
	check(src != "", "keg stave include loads")
	var keep := _extract(src, "keg_spec_keep")
	var lobe := _extract(src, "keg_spec_lobe")
	check(not keep.is_empty() and not lobe.is_empty(), "both gate functions are in the include")
	if keep.is_empty() or lobe.is_empty():
		_finish()
		return
	_check_keep(keep)
	_check_lobe(lobe)
	for path in SHADERS:
		_check_shader(path)
	_finish()


func _finish() -> void:
	print("test_keg_spec_gate: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Non-keg: every cell keeps specular. A keg still drops the stave cells.
func _check_keep(fn: Dictionary) -> void:
	for cell in 25:
		var got := _call(fn, [float(cell), 1.0], 0.0)
		check(got.ok and is_equal_approx(got.value, 1.0), "non-keg cell %d keeps specular (got %s)" % [cell, got.text])
	check(_call(fn, [0.0, 1.0], 1.0).value == 0.0, "keg cell 0 drops specular")
	check(_call(fn, [22.0, 0.0], 1.0).value == 0.0, "keg gutter cell 22 drops specular")
	check(_call(fn, [23.0, 1.0], 1.0).value == 1.0, "keg lid cell 23 keeps specular")
	check(_call(fn, [24.0, 1.0], 1.0).value == 1.0, "keg hoop cell 24 keeps specular")


## Non-keg: hard step at spec_size 0.97. N·H 0.90 is inside the keg's soft
## ramp and outside the hard step, so a dropped gate (always smoothstep)
## reads 1 here and fails.
func _check_lobe(fn: Dictionary) -> void:
	var hard := 0.97
	check(_call(fn, [0.90, hard], 0.0).value == 0.0, "non-keg N·H 0.90 is outside the hard step")
	check(_call(fn, [0.96, hard], 0.0).value == 0.0, "non-keg N·H 0.96 is outside the hard step")
	check(_call(fn, [0.97, hard], 0.0).value == 1.0, "non-keg N·H 0.97 hits the hard step")
	check(_call(fn, [0.99, hard], 0.0).value == 1.0, "non-keg N·H 0.99 hits the hard step")
	var keg := _call(fn, [0.90, hard], 1.0)
	check(keg.ok and keg.value > 0.9, "keg N·H 0.90 stays on the soft lobe (got %s)" % keg.text)


## Both toon shaders must call the include. The lobe call must not sit
## inside a keg_body branch, or non-keg dice would lose the hard step.
func _check_shader(path: String) -> void:
	var src := _strip(FileAccess.get_file_as_string(path))
	var name := path.get_file()
	check("keg_stave_dim.gdshaderinc" in src, "%s includes the gate" % name)
	check("keg_s = 1.0" in src, "%s starts non-keg specular on" % name)
	var keep_at := src.find("keg_spec_keep(")
	var lobe_at := src.find("keg_spec_lobe(")
	check(keep_at >= 0 and lobe_at >= 0, "%s calls both gates" % name)
	if keep_at < 0 or lobe_at < 0:
		return
	check("keg_body" in _enclosing_if(src, keep_at), "%s only swaps specular off inside a keg_body check" % name)
	check("keg_body" not in _enclosing_if(src, lobe_at), "%s hard lobe is not inside a keg_body branch" % name)


func _call(fn: Dictionary, args: Array, keg_body: float) -> Dictionary:
	var env := {"keg_body": keg_body}
	var params: PackedStringArray = fn.params
	if params.size() != args.size():
		return {"ok": false, "value": 0.0, "text": "arity"}
	for i in params.size():
		env[params[i]] = float(args[i])
	var ev := _Eval.new(fn.body, env)
	var got := ev.run()
	return {"ok": got.ok, "value": got.value, "text": got.text}


func _extract(src: String, fname: String) -> Dictionary:
	var key := "float %s(" % fname
	var at := src.find(key)
	if at < 0:
		return {}
	var p0 := at + key.length()
	var p1 := src.find(")", p0)
	var brace := src.find("{", p1)
	if p1 < 0 or brace < 0:
		return {}
	var params := PackedStringArray()
	for part in src.substr(p0, p1 - p0).split(","):
		var bits := part.strip_edges().split(" ")
		if bits.size() > 0 and bits[bits.size() - 1] != "":
			params.append(bits[bits.size() - 1])
	var depth := 0
	var i := brace
	while i < src.length():
		if src[i] == "{":
			depth += 1
		elif src[i] == "}":
			depth -= 1
			if depth == 0:
				return {"params": params, "body": src.substr(brace + 1, i - brace - 1)}
		i += 1
	return {}


## The if (...) that owns the brace wrapping `at`.
func _enclosing_if(src: String, at: int) -> String:
	var depth := 0
	var i := at - 1
	while i >= 0:
		if src[i] == "}":
			depth += 1
		elif src[i] == "{":
			if depth == 0:
				var head := src.substr(0, i)
				var k := head.rfind("if")
				return "" if k < 0 else src.substr(k, i - k)
			depth -= 1
		i -= 1
	return ""


func _strip(src: String) -> String:
	var out := ""
	var i := 0
	while i < src.length():
		# res:// paths contain :// and are not comments.
		if src.substr(i, 2) == "//" and (i == 0 or src[i - 1] != ":"):
			while i < src.length() and src[i] != "\n":
				i += 1
		else:
			out += src[i]
			i += 1
	return out


## A tiny reader for the two gate functions: if / return / float, and the
## comparisons, ||, step and smoothstep those functions use.
class _Eval:
	extends RefCounted
	var src: String
	var i := 0
	var env: Dictionary
	var err := ""

	func _init(body: String, vars: Dictionary) -> void:
		src = body
		env = vars

	func run() -> Dictionary:
		var result := _block(false)
		if err != "":
			return {"ok": false, "value": 0.0, "text": err}
		if not result.hit:
			return {"ok": false, "value": 0.0, "text": "no return"}
		return {"ok": true, "value": result.value, "text": str(result.value)}
	func _block(stop_at_brace: bool) -> Dictionary:
		while i < src.length() and err == "":
			_skip()
			if i >= src.length():
				break
			if stop_at_brace and src[i] == "}":
				i += 1
				break
			if _kw("if"):
				var cond := _paren_expr()
				_skip()
				if i >= src.length() or src[i] != "{":
					err = "if without block"
					break
				i += 1
				if cond > 0.5:
					var inner := _block(true)
					if inner.hit:
						return inner
				else:
					_skip_block()
			elif _kw("return"):
				var v := _expr()
				_semi()
				return {"hit": true, "value": v}
			elif _kw("float"):
				_decl()
			else:
				err = "bad stmt '%s'" % src.substr(i, mini(12, src.length() - i))
				break
		return {"hit": false, "value": 0.0}
	func _decl() -> void:
		_skip()
		var name := _ident()
		_skip()
		if i >= src.length() or src[i] != "=":
			err = "float without ="
			return
		i += 1
		var v := _expr()
		_semi()
		env[name] = v
	func _paren_expr() -> float:
		_skip()
		if i >= src.length() or src[i] != "(":
			err = "missing ("
			return 0.0
		i += 1
		var v := _expr()
		_skip()
		if i < src.length() and src[i] == ")":
			i += 1
		return v
	func _expr() -> float:
		var left := _and()
		while err == "" and _op("||"):
			var right := _and()
			left = 1.0 if left > 0.5 or right > 0.5 else 0.0
		return left
	func _and() -> float:
		var left := _cmp()
		while err == "" and _op("&&"):
			var right := _cmp()
			left = 1.0 if left > 0.5 and right > 0.5 else 0.0
		return left
	func _cmp() -> float:
		var left := _add()
		_skip()
		for op in ["<=", ">=", "==", "!=", "<", ">"]:
			if _op(op):
				var right := _add()
				return 1.0 if _cmp_ok(left, op, right) else 0.0
		return left
	func _add() -> float:
		var left := _mul()
		while err == "":
			_skip()
			if i < src.length() and (src[i] == "+" or src[i] == "-"):
				var op := src[i]
				i += 1
				var right := _mul()
				left = left + right if op == "+" else left - right
			else:
				break
		return left
	func _mul() -> float:
		var left := _unary()
		while err == "":
			_skip()
			if i < src.length() and (src[i] == "*" or src[i] == "/"):
				var op := src[i]
				i += 1
				var right := _unary()
				left = left * right if op == "*" else left / right
			else:
				break
		return left
	func _unary() -> float:
		_skip()
		if i < src.length() and src[i] == "!":
			i += 1
			return 0.0 if _unary() > 0.5 else 1.0
		if i < src.length() and src[i] == "-":
			i += 1
			return -_unary()
		return _primary()
	func _primary() -> float:
		_skip()
		if i >= src.length():
			err = "eof"
			return 0.0
		if src[i] == "(":
			i += 1
			var v := _expr()
			_skip()
			if i < src.length() and src[i] == ")":
				i += 1
			return v
		if _is_num(src[i]):
			return _number()
		var name := _ident()
		_skip()
		if i < src.length() and src[i] == "(":
			i += 1
			var args: Array[float] = []
			_skip()
			if i < src.length() and src[i] != ")":
				args.append(_expr())
				while err == "" and _op(","):
					args.append(_expr())
			_skip()
			if i < src.length() and src[i] == ")":
				i += 1
			return _call_fn(name, args)
		if not env.has(name):
			err = "unknown %s" % name
			return 0.0
		return float(env[name])
	func _call_fn(name: String, args: Array[float]) -> float:
		if name == "step" and args.size() == 2:
			return 0.0 if args[1] < args[0] else 1.0
		if name == "smoothstep" and args.size() == 3:
			var e0 := args[0]
			var e1 := args[1]
			var x := clampf((args[2] - e0) / (e1 - e0), 0.0, 1.0)
			return x * x * (3.0 - 2.0 * x)
		err = "bad call %s" % name
		return 0.0
	func _cmp_ok(a: float, op: String, b: float) -> bool:
		match op:
			"<": return a < b
			">": return a > b
			"<=": return a <= b
			">=": return a >= b
			"==": return is_equal_approx(a, b)
			"!=": return not is_equal_approx(a, b)
		return false
	func _kw(word: String) -> bool:
		_skip()
		if src.substr(i, word.length()) != word:
			return false
		var n := i + word.length()
		if n < src.length() and _is_id(src[n]):
			return false
		i = n
		return true
	func _op(word: String) -> bool:
		_skip()
		if src.substr(i, word.length()) != word:
			return false
		i += word.length()
		return true
	func _ident() -> String:
		_skip()
		var start := i
		while i < src.length() and _is_id(src[i]):
			i += 1
		return src.substr(start, i - start)
	func _number() -> float:
		var start := i
		while i < src.length() and (src[i].is_valid_int() or src[i] == "."):
			i += 1
		return float(src.substr(start, i - start))
	func _semi() -> void:
		_skip()
		if i < src.length() and src[i] == ";":
			i += 1
	func _skip() -> void:
		while i < src.length() and (src[i] == " " or src[i] == "\t" or src[i] == "\n" or src[i] == "\r"):
			i += 1
	func _skip_block() -> void:
		var depth := 1
		while i < src.length() and depth > 0:
			if src[i] == "{":
				depth += 1
			elif src[i] == "}":
				depth -= 1
			i += 1
	func _is_num(c: String) -> bool:
		return c.is_valid_int() or c == "."
	func _is_id(c: String) -> bool:
		return c.is_valid_int() or (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or c == "_"
