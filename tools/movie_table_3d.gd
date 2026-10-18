## Records one real 3D throw with Godot's Movie Maker: the mouse is driven by
## synthetic input events (press on the dice, drag, fast flick, release), so
## the clip goes through the same grab/flick path a player uses.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan \
##       --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/throw.avi \
##       --script res://tools/movie_table_3d.gd
## (Tooling only; not part of the game or the tests.)
extends SceneTree

var scene: Table3D
var pointer := Vector2.ZERO
var marker: Control


func _initialize() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout


## Sends a mouse event the same way the OS would.
## `vp_pos` is in game (viewport) pixels; events are sent in window pixels.
func mouse(vp_pos: Vector2, button: int = 0, pressed: bool = false) -> void:
	var pos := root.get_final_transform() * vp_pos
	var rel := pos - pointer
	pointer = pos
	marker.queue_redraw()
	if button != 0:
		var b := InputEventMouseButton.new()
		b.button_index = button as MouseButton
		b.pressed = pressed
		b.position = pos
		b.global_position = pos
		Input.parse_input_event(b)
	else:
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		m.relative = rel
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)


func _run() -> void:
	scene = (load("res://scenes/table_3d.tscn") as PackedScene).instantiate() as Table3D
	scene.rng_seed = 31
	root.add_child(scene)
	# A small ring shows where the (synthetic) mouse is.
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	marker = Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker.draw.connect(func() -> void:
		marker.draw_arc(root.get_final_transform().affine_inverse() * pointer, 14.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85), 3.0)
		marker.draw_circle(root.get_final_transform().affine_inverse() * pointer, 3.0, Color(1, 1, 1, 0.85)))
	layer.add_child(marker)
	await wait(0.6)
	scene.place()
	await wait(0.15)
	scene.place()
	await wait(0.5)
	var vp := root.get_visible_rect().size
	var hand := scene.camera.cam.unproject_position(Table3D.HAND)
	# Move to the dice, grab, wind up, flick toward the back wall.
	var from := hand + Vector2(120, 80)
	for i in 10:
		mouse(from.lerp(hand, float(i + 1) / 10.0))
		await process_frame
	mouse(hand, MOUSE_BUTTON_LEFT, true)
	await wait(0.25)
	var drag_to := hand + Vector2(-0.08, -0.04) * vp.x
	for i in 18:
		mouse(hand.lerp(drag_to, float(i + 1) / 18.0) + Vector2(0, sin(i * 0.9) * 6.0))
		await process_frame
	await wait(0.15)
	var flick_to := drag_to + Vector2(-0.16, -0.22) * vp.x
	for i in 4:
		mouse(drag_to.lerp(flick_to, float(i + 1) / 4.0))
		await process_frame
	mouse(flick_to, MOUSE_BUTTON_LEFT, false)
	if scene.phase != Table3D.Phase.BET:  # a weak flick drops the dice back: nothing to wait for
		await scene.sequence_finished
	await wait(0.5)
	quit()
