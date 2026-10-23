## Soul Reliquary close-up turntable / state sheet on a felt card under a warm key (inspection aid, not a test).
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1600x900 \
##     --script res://art/models/props/soul_reliquary/src/render_soul_reliquary.gd -- [out=<png>] [yaw=..] [pitch=..] [state=..]
extends SceneTree

const STATES := {"full": [35, 35, false], "mid": [18, 35, false], "low": [4, 35, false], "lethal": [3, 35, true],
	"grow": [39, 39, false]}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/rq_close.png"
	var yaw := 0.0
	var pitch := -35.0
	var st := "mid"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a.begins_with("yaw="):
			yaw = float(a.substr(4))
		if a.begins_with("pitch="):
			pitch = float(a.substr(6))
		if a.begins_with("state="):
			st = a.substr(6)
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.06, 0.05, 0.05)
	env.environment.ambient_light_color = Color(0.5, 0.42, 0.35)
	env.environment.ambient_light_energy = 0.6
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.82, 0.6)
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	var felt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.13, 0.3, 0.2)
	pm.material = fm
	felt.mesh = pm
	w.add_child(felt)
	var rq := (load("res://art/models/props/soul_reliquary/scenes/soul_reliquary.tscn") as PackedScene).instantiate() as SoulReliquary
	rq.reduced_motion = true
	w.add_child(rq)
	var sv: Array = STATES[st]
	rq.set_soul(sv[0], sv[1], false)
	rq.lethal = sv[2]
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0.08, 0)
	pivot.rotation_degrees = Vector3(pitch, yaw, 0)
	w.add_child(pivot)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 0, 0.55)
	pivot.add_child(cam)
	cam.current = true
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
