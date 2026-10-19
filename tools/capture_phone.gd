## Helper for the capture tools: `-- phone=390x844` (or 844x390) frames the
## Bonfire table like that phone screen. The table goes into a SubViewport
## the size the window would stretch to (portrait: 1920 wide, landscape:
## 1080 high), Bonfire3D.fit_phone() frames it, and shots come from that
## viewport, scaled to 2x the phone's points. Without phone= it's a no-op.
class_name CapturePhone
extends RefCounted

## The phone screen in points (Vector2.ZERO = no phone framing).
var screen := Vector2.ZERO
## The viewport the table renders into (null = the window).
var viewport: SubViewport


## Reads phone=WxH from the command line user args.
func parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("phone="):
			var wh := a.substr(6).split("x")
			if wh.size() == 2:
				screen = Vector2(float(wh[0]), float(wh[1]))


## Adds the table under root: straight in, or inside a phone-sized viewport.
func add_table(root: Window, table: Bonfire3D) -> void:
	if screen == Vector2.ZERO:
		root.add_child(table)
		return
	viewport = SubViewport.new()
	if screen.y > screen.x:
		viewport.size = Vector2i(1920, int(round(1920.0 * screen.y / screen.x)))
	else:
		viewport.size = Vector2i(int(round(1080.0 * screen.x / screen.y)), 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(table)


## After the table's first frames: point its camera and fit it to the phone.
func frame(table: Bonfire3D) -> void:
	if viewport == null:
		return
	table.camera.cam.current = true
	table.fit_phone(screen)
	table.camera.snap_home()


## The image to save for a shot.
func image(root: Window) -> Image:
	if viewport == null:
		return root.get_texture().get_image()
	var img := viewport.get_texture().get_image()
	img.resize(int(screen.x * 2.0), int(screen.y * 2.0), Image.INTERPOLATE_LANCZOS)
	return img
