## Bakes scripts/table3d/face_print_spots.gd: where the Twin diamond goes on
## each Gallows d4 face and the rare glyph badge on each Beacon d8 face,
## read from the printed face art (FacePrint). Rerun when the d4 / d8 face
## textures or meshes change:
##   godot --headless --path . --script res://tools/gen_face_print_spots.gd
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var st := TableSetup.new()
	for id in [DiceIds.DIE_GALLOWS, DiceIds.DIE_BEACON]:
		st.dice.append(TableDie.new(id, "bake", DiceIds.shape_of(id)))
	st.run_mode = false
	var s := (load("res://scenes/bonfire.tscn") as PackedScene).instantiate() as Bonfire3D
	s.setup = st
	root.add_child(s)
	await process_frame
	var out := PackedStringArray()
	for d: DieVisual in s.all_dice:
		var img := FacePrint.image_of(d)
		var row := PackedStringArray()
		for k in range(1, DieHullData.SHAPES[d.shape]["dirs"].size() + 1):
			var f := PolyBody.face_tri(d, k)
			var h: float = f.h
			var ink := FacePrint.ink_points(d, f, img)
			var w := Vector3.ZERO
			if d.shape == &"d4":
				w = FacePrint.best_diamond(f, ink, h * FacePrintSpots.TWIN_SIZE * 0.5, h * FacePrintSpots.MARGIN, h * FacePrintSpots.PAD)
			else:
				var box := FacePrint.numeral_box(ink, f.normal, (f.tri[0] as Vector3).distance_to(f.tri[1]) / 72.0)
				w = FacePrint.best_badge(f, box, h * FacePrintSpots.BADGE_SIZE * 0.5, h * FacePrintSpots.MARGIN)
			row.append("Vector3(%.4f, %.4f, %.4f)" % [w.x, w.y, w.z])
			print(d.shape, " slot ", k, " -> ", w)
		out.append("\t&\"%s\": [%s]," % [d.shape, ", ".join(row)])
	var src := FileAccess.get_file_as_string("res://scripts/table3d/face_print_spots.gd")
	var a := src.find("const SPOTS := {") + "const SPOTS := {".length()
	var b := src.find("}", a)
	src = src.substr(0, a) + "\n" + "\n".join(out) + "\n" + src.substr(b)
	FileAccess.open("res://scripts/table3d/face_print_spots.gd", FileAccess.WRITE).store_string(src)
	s.queue_free()
	await process_frame
	quit()
