## Headless test: every dealer's hands mirror each other (Cash playtest: "the hands are all on the same side").
## Smiles and all six boss dealers share Smiles' clips (build_smiles.py). In the idle clip, the pose seen at the
## table almost all the time, both forearms rest on the rail: the left hand must be the mirror image of the right
## (same palm roll, mirrored across the body), with both palms facing down. Before the fix the left palm faced
## down and the right palm up, so both hands read as the same hand. Also checks the chip prop stays on hand_R.
##
## Run:
##   godot --headless --path . --script res://tests/test_dealer_hands.gd
extends SceneTree

const SCENES := [
	"res://art/models/characters/smiles/scenes/smiles%s.tscn",
	"res://art/models/characters/bosses/pit_boss/scenes/pit_boss%s.tscn",
	"res://art/models/characters/bosses/shuffle/scenes/shuffle%s.tscn",
	"res://art/models/characters/bosses/ashmouth/scenes/ashmouth%s.tscn",
	"res://art/models/characters/bosses/straight_man/scenes/straight_man%s.tscn",
	"res://art/models/characters/bosses/collector/scenes/collector%s.tscn",
	"res://art/models/characters/bosses/bloodletter/scenes/bloodletter%s.tscn",
]
## Mirror across the body's centre plane (model X).
const MX := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
const MIN_MIRROR_DOT := 0.8
const MIN_PALM_DOWN := 0.7

var _pass := 0
var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL ", msg)


func _run() -> void:
	print("=== Dice of the Damned: dealer hand mirroring ===")
	for path: String in SCENES:
		for lod in ["", "_mobile"]:
			await _check_scene(path % lod)
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)


## Palm normal in model space: the palm faces the body at rest, i.e. -X for hand_L and +X for hand_R.
func _palm(sk: Skeleton3D, side: String) -> Vector3:
	var g := sk.get_bone_global_pose(sk.find_bone("hand_" + side))
	var rest := sk.get_bone_global_rest(sk.find_bone("hand_" + side))
	var local := rest.basis.inverse() * Vector3(-1.0 if side == "L" else 1.0, 0, 0)
	return (g.basis * local).normalized()


func _check_scene(path: String) -> void:
	var name := path.get_file().get_basename()
	var b := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(b)
	await process_frame
	var ap := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := b.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(ap != null and sk != null, "%s: AnimationPlayer + Skeleton3D" % name)
	if ap == null or sk == null:
		b.queue_free()
		return
	var chip := sk.find_bone("chip")
	_check(chip >= 0 and sk.get_bone_name(sk.get_bone_parent(chip)) == "hand_R", "%s: chip prop bone on hand_R" % name)
	var length := ap.get_animation("idle").length
	var worst_mirror := 1.0
	var worst_down := 1.0
	for k in 7:
		ap.play("idle")
		ap.seek(length * k / 6.0, true)
		ap.pause()
		var hl := sk.get_bone_global_pose(sk.find_bone("hand_L")).basis
		var hr := MX * sk.get_bone_global_pose(sk.find_bone("hand_R")).basis * MX
		for ax in 3:
			worst_mirror = minf(worst_mirror, hl[ax].normalized().dot(hr[ax].normalized()))
		var up := sk.get_bone_global_pose(sk.find_bone("chest")).basis.y.normalized()
		for s in ["L", "R"]:
			worst_down = minf(worst_down, -_palm(sk, s).dot(up))
	_check(worst_mirror >= MIN_MIRROR_DOT, "%s idle: left hand mirrors right (worst axis dot %.2f >= %.2f)" % [name, worst_mirror, MIN_MIRROR_DOT])
	_check(worst_down >= MIN_PALM_DOWN, "%s idle: both palms face down on the rail (worst %.2f >= %.2f)" % [name, worst_down, MIN_PALM_DOWN])
	print("  %s idle: mirror dot %.2f, palm-down %.2f" % [name, worst_mirror, worst_down])
	b.queue_free()
	await process_frame
