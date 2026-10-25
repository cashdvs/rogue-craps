## The dealer you see at a Bonfire table (art/models/characters).
## Normal tables: Smiles. Boss tables: that boss's own dealer scene, swapped
## in at the SAME spot instead of Smiles (never both at once).
##
## How a boss table is spotted: the run passes the boss cheat in
## TableSetup.rules as {"id": ..., "params": ...} (RunTableSetup.rule_entries,
## Systems Dev). The cheat id says which boss sits at the table.
## Madame Shuffle: her stopgap rule has its own id, madame_shuffle_stopgap
## (PR #172), mapped below. A plain pit_boss id is always the Pit Boss.
## Bosses without a dealer scene yet (floor 3) keep Smiles.
##
## The greybox Dealer3D bust is hidden while an art dealer stands here; its
## rake stays (it still drags lost chips) and so does its head anchor for
## the speech bubble.
class_name BonfireDealerArt
extends Node

## Smiles stands here (art/dealer-smiles README "Placement"); every boss scene
## is built as a straight swap for Smiles at this anchor.
const DEALER_SPOT := Vector3(-0.42, -0.47, -0.86)
## Smiles' spot was set for the Hearth board, whose far rail lip is low.
## Gameplay still uses the greybox table, whose far rail hides the dealers'
## faces at that height (QA on #171: only hats / hands showed on PC), so the
## dealer stands this much higher. Their tops still clear the frame top
## (~0.25 m of headroom left). Set to 0 when the Hearth board ships.
const GREYBOX_RAIL_LIFT := Vector3(0, 0.12, 0)
const SMILES := "res://art/models/characters/smiles/scenes/smiles.tscn"
const BOSS_DIR := "res://art/models/characters/bosses/%s/scenes/%s.tscn"
## Boss cheat id -> boss art folder.
const BOSS_ART := {
	&"pit_boss": "pit_boss",
	&"madame_shuffle": "shuffle",
	&"madame_shuffle_stopgap": "shuffle",
	&"ashmouth": "ashmouth",
	&"straight_man": "straight_man",
	&"collector": "collector",
	&"bloodletter": "bloodletter",
}
## Ashmouth's soot puff fires at the 1.2 s door slam and lives ~0.55 s, so
## his scene must stay alive until about 1.75 s into the taunt.
const ASHMOUTH_KEEP_ALIVE := 1.75

## The Bonfire3D table this dealer belongs to.
var table: Node3D
## Which art is showing: "smiles" or a boss folder name (e.g. "ashmouth").
var art_id: String = ""
## The instanced dealer scene (Smiles or the boss), placed at DEALER_SPOT.
var scene: Node3D
## Ashmouth only: his puff listener (AshmouthPuffFx), else null.
var puff_fx: Node
var player: AnimationPlayer


## Which art folder the rules ask for: a boss name, or "smiles".
static func art_for_rules(rules: Array) -> String:
	for entry in rules:
		var e: Dictionary = TableRules.normalize(entry)
		var id := StringName(e.get("id", &""))
		if not BOSS_ART.has(id):
			continue
		return BOSS_ART[id]
	return "smiles"


## The scene path for an art id (mobile = the low-poly variant).
static func scene_path(id: String, mobile: bool) -> String:
	var path := SMILES if id == "smiles" else BOSS_DIR % [id, id]
	if mobile:
		var low := path.replace(".tscn", "_mobile.tscn")
		if ResourceLoader.exists(low):
			return low
	return path


## Builds the dealer for `t` (a Bonfire3D) from its setup.rules.
func setup(t: Node3D, rules: Array) -> void:
	table = t
	var mobile := RenderingServer.get_current_rendering_method() != "forward_plus"
	show_art(art_for_rules(rules), mobile)


## Swaps the dealer art: frees the old scene, then adds the new one at the
## same anchor. Only one dealer scene ever stands here.
func show_art(id: String, mobile: bool = false) -> void:
	_release_scene()
	art_id = id
	var path := scene_path(id, mobile)
	if not ResourceLoader.exists(path):
		push_warning("Dealer art missing: " + path)
		_show_greybox(true)
		return
	scene = (load(path) as PackedScene).instantiate() as Node3D
	scene.name = "DealerArt"
	scene.position = DEALER_SPOT + GREYBOX_RAIL_LIFT
	table.add_child(scene)
	_show_greybox(false)
	var found := scene.find_children("*", "AnimationPlayer", true, false)
	player = found[0] as AnimationPlayer if not found.is_empty() else null
	puff_fx = null
	for n in scene.find_children("*", "Node", true, false):
		if n is AshmouthPuffFx:
			puff_fx = n
	_sync_reduced_motion()
	play_idle()


## Loops the idle clip (also what plays after a taunt ends).
func play_idle() -> void:
	if player != null and player.has_animation(&"idle"):
		player.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
		player.play(&"idle")


## The dealer taunts (Table3D.taunted): play the taunt clip, then idle.
func taunt() -> void:
	if player == null or not player.has_animation(&"taunt"):
		return
	_sync_reduced_motion()
	player.play(&"taunt")
	player.queue(&"idle")


func _process(_dt: float) -> void:
	# Follow the table's Reduced motion option live (it can be toggled mid-run).
	_sync_reduced_motion()


## Ashmouth's puffs read Bonfire3D.reduced_motion through their export.
func _sync_reduced_motion() -> void:
	if puff_fx != null and is_instance_valid(puff_fx) and table != null:
		puff_fx.set("reduced_motion", bool(table.get("reduced_motion")))


## Frees the current scene before a swap. Ashmouth mid-taunt is kept alive
## (body hidden, clip still running) until ~1.75 s into his taunt so the soot
## puff can finish; the new dealer is added at once.
func _release_scene() -> void:
	if scene == null or not is_instance_valid(scene):
		return
	if art_id == "ashmouth" and _keep_ashmouth_alive():
		scene = null
		return
	scene.queue_free()
	scene = null


## Returns true when the Ashmouth scene was handed a delayed free.
func _keep_ashmouth_alive() -> bool:
	if scene == null or not is_instance_valid(scene) or player == null:
		return false
	if player.current_animation != &"taunt" or not player.is_playing():
		return false
	var left := ASHMOUTH_KEEP_ALIVE - player.current_animation_position
	if left <= 0.0 or not scene.is_inside_tree():
		return false
	# Move him to the tree root (reparent keeps his global spot) so he
	# outlives a swap, then free him once the soot puff is done.
	var tree := scene.get_tree()
	var keep := scene
	keep.reparent(tree.root)
	keep.name = "AshmouthLeaving"
	# Hidden body, so he's never seen beside the dealer who replaced him;
	# his clip and sockets keep running so the puffs still fire.
	var model := keep.get_node_or_null("Model") as Node3D
	if model != null:
		model.visible = false
	tree.create_timer(left, false).timeout.connect(keep.queue_free)
	return true


## Shows or hides the greybox bust (the rake always stays visible).
func _show_greybox(on: bool) -> void:
	var bust := table.get("dealer") as Node3D
	if bust == null:
		return
	for c in bust.get_children():
		if c is VisualInstance3D or (c is Node3D and c.name != &"Rake"):
			(c as Node3D).visible = on
