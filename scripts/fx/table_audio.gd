## Feel layer, audio: listens to the table's gameplay signals (`table.events`,
## a TableEvents node owned by Godot Dev) and plays the Sound Designer's cues.
##
## Why a listener: the table's logic should only *say what happened*
## (dice_thrown, die_impact, hot_hand, ...). Which sound plays, how loud and
## when is a feel decision, so it lives here in scripts/fx/ and the table
## code never calls the SfxManager for these moments (AGENTS.md section 5:
## logic emits signals, views connect to them).
##
## Cues and calls follow scripts/audio/README.md:
## - dice_thrown(flick_speed_px_s) -> SfxManager.play_throw (momentum layers
##   and rattle, PR #26). The old fixed `dice_shake` only plays when that hook
##   is missing (a stand-in SfxManager in a test).
## - die_impact(kind, speed_mps, material, die_id) -> SfxManager.play_impact
##   (PR #27). It has its own silence floor and per-die rate limit.
## - hot_hand(count) -> `hot_hand` (rev 2, PR #58): five bone clacks into the
##   palm. Emitted when the dice ARRIVE in the hand. No ignite, no fire
##   trail sound: dice never sound like fire (bonfire_map_events_juice.md 3).
## - no_score -> `no_score` (PR #58), in place of the old `chip_refuse`.
## - table_cleared -> `table_cleared` (PR #58), once per table.
##
## Cues that aren't baked yet (PR #29 unmerged) fall back to an existing
## sound so nothing goes silent and SfxManager never warns.
##
## Binding: add it as a child of the table. On the next idle frame it reads
## `table.events` and `table.sfx`; if the table has no `events` node yet it
## does nothing, so it can merge before TableEvents lands without playing
## anything twice. Tests call bind(events, sfx) directly.
class_name TableAudio
extends Node

## Cue -> fallback event used when the cue isn't in the SfxManager yet.
const FALLBACK: Dictionary[StringName, StringName] = {
	&"hot_hand": &"win_big",
	&"no_score": &"chip_refuse",
	&"table_cleared": &"win_big",
}
## Signal on TableEvents -> handler method here (the agreed payloads).
const HOOKS: Dictionary[StringName, StringName] = {
	&"dice_thrown": &"_on_dice_thrown",
	&"die_impact": &"_on_die_impact",
	&"hot_hand": &"_on_hot_hand",
	&"no_score": &"_on_no_score",
	&"table_cleared": &"_on_table_cleared",
}

## The SfxManager (typed Node so tests can pass a stand-in).
var sfx: Node
## The TableEvents node we listen to (null = unbound).
var events: Object
## Every cue played, as "<event>" or "<event>(fb)" (tests and captures).
var calls: Array[String] = []
var _cleared_played: bool = false


func _init() -> void:
	name = "TableAudio"


func _ready() -> void:
	_bind_to_parent.call_deferred()


## Looks up the parent table's `events` and `sfx` (no-op without `events`).
func _bind_to_parent() -> void:
	var table := get_parent()
	if table == null or events != null:
		return
	var ev: Variant = table.get("events")
	var s: Variant = table.get("sfx")
	if ev is Object and s is Node:
		bind(ev as Object, s as Node)


## Connects to every agreed signal the events node has. Returns how many
## were connected (signals it doesn't have yet are skipped).
func bind(ev: Object, s: Node) -> int:
	unbind()
	events = ev
	sfx = s
	_cleared_played = false
	var n := 0
	for sig: StringName in HOOKS:
		if ev.has_signal(sig):
			ev.connect(sig, Callable(self, HOOKS[sig]))
			n += 1
	return n


func unbind() -> void:
	if events != null and is_instance_valid(events):
		for sig: StringName in HOOKS:
			var c := Callable(self, HOOKS[sig])
			if events.has_signal(sig) and events.is_connected(sig, c):
				events.disconnect(sig, c)
	events = null


## A new table on the same node (sandbox restart): TABLE CLEARED may play again.
func reset() -> void:
	_cleared_played = false


# --- Handlers (payloads as agreed with Godot Dev) -------------------------------------

func _on_dice_thrown(flick_speed_px_s: float) -> void:
	if sfx == null:
		return
	if sfx.has_method("play_throw"):
		sfx.call("play_throw", flick_speed_px_s)
		calls.append("throw")
	else:
		cue(&"dice_shake")


## kind / material arrive as String or StringName, so they're untyped here.
func _on_die_impact(kind: Variant, speed_mps: float, material: Variant, die_id: int) -> void:
	if sfx == null:
		return
	if sfx.has_method("play_impact"):
		if bool(sfx.call("play_impact", StringName(str(kind)), speed_mps, StringName(str(material)), die_id)):
			calls.append("impact")


func _on_hot_hand(_count: int) -> void:
	cue(&"hot_hand")


func _on_no_score() -> void:
	cue(&"no_score")


func _on_table_cleared() -> void:
	if _cleared_played:
		return
	_cleared_played = true
	cue(&"table_cleared", 0.0)


## Plays `event` (or its fallback) if the SfxManager has it. Returns what played.
func cue(event: StringName, jitter: float = 0.06) -> StringName:
	if sfx == null:
		return &""
	if _has(event):
		sfx.call("play", event, 1.0, 0.0, jitter)
		calls.append(String(event))
		return event
	var fb: StringName = FALLBACK.get(event, &"")
	if fb != &"" and _has(fb):
		sfx.call("play", fb, 1.0, 0.0, jitter)
		calls.append("%s(fb)" % fb)
		return fb
	return &""


func _has(event: StringName) -> bool:
	return sfx.has_method("has_event") and bool(sfx.call("has_event", event))
