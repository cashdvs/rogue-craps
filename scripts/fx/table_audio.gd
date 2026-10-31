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
## - goal_reached -> `table_goal_reached` (table goals). It stands in for
##   the TABLE CLEARED cue: a table_cleared after it stays silent.
## - goal_missed(soul_loss) -> `table_goal_missed` (out of hands short of
##   the target). Both are connected only once TableEvents has the signals.
##
## Fallbacks cover stand-in SfxManagers in tests (and any cue the live
## manager does not have yet) so nothing goes silent and SfxManager never warns.
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
	&"table_goal_reached": &"table_cleared",
	&"table_goal_missed": &"soul_burn",
}
## Signal on TableEvents -> handler method here (the agreed payloads).
const HOOKS: Dictionary[StringName, StringName] = {
	&"dice_thrown": &"_on_dice_thrown",
	&"die_impact": &"_on_die_impact",
	&"hot_hand": &"_on_hot_hand",
	&"no_score": &"_on_no_score",
	&"table_cleared": &"_on_table_cleared",
	&"table_started": &"_on_table_started",
	&"goal_reached": &"_on_goal_reached",
	&"goal_missed": &"_on_goal_missed",
}

## The SfxManager (typed Node so tests can pass a stand-in).
var sfx: Node
## The TableEvents node we listen to (null = unbound).
var events: Object
## Every cue played, as "<event>" or "<event>(fb)" (tests and captures).
## Trimmed like BonfireJuice so long tables do not grow forever.
var calls: Array[String] = []
## The table (for speed_mode and BonfireJuice's crowd); set by the parent bind.
var table: Node
## The #98 hook's flavour layers — ModTriggerSynth.FLAVORS keys on main.
var _cleared_played: bool = false
var _crowd_set: bool = false


func _init() -> void:
	name = "TableAudio"


func _ready() -> void:
	_bind_to_parent.call_deferred()


## Looks up the parent table's `events` and `sfx` (no-op without `events`).
func _bind_to_parent() -> void:
	var t := get_parent()
	if t == null or events != null:
		return
	table = t
	var ev: Variant = t.get("events")
	var s: Variant = t.get("sfx")
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


## Disconnects from events (safe to call twice).
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
		_record("throw")
	else:
		cue(&"dice_shake")


## kind / material arrive as String or StringName, so they're untyped here.
func _on_die_impact(kind: Variant, speed_mps: float, material: Variant, die_id: int) -> void:
	if sfx == null:
		return
	if sfx.has_method("play_impact"):
		if bool(sfx.call("play_impact", StringName(str(kind)), speed_mps, StringName(str(material)), die_id)):
			_record("impact")


func _on_hot_hand(_count: int) -> void:
	cue(&"hot_hand")


func _on_no_score() -> void:
	cue(&"no_score")


## A new table (TableEvents.table_started, #91): TABLE CLEARED may play again.
func _on_table_started() -> void:
	reset()


func _on_table_cleared() -> void:
	if _cleared_played:
		return
	_cleared_played = true
	cue(&"table_cleared", 0.0)


## The banked points reach the target: one goal sting in place of TABLE CLEARED.
func _on_goal_reached() -> void:
	if _cleared_played:
		return
	_cleared_played = true
	cue(&"table_goal_reached", 0.0)


func _on_goal_missed(_soul_loss: int = 0) -> void:
	cue(&"table_goal_missed", 0.0)


## Trigger FX sound (trigger_fx_spec.md 4, "Sound hooks"). TableAudio is the
## ONLY caller of sfx.play_mod_trigger: TriggerFx calls this once per trigger,
## in resolve order, at that trigger's FX start, and syncs its flash to the
## returned seconds until the audio hit (-1 = silent). The Sound Designer's
## hook does the stagger, the 4-voice cap and cluster, speed modes,
## Bellows-once and the signature crowd nudge, so none of that is here.
## ctx: tier (-1 = the row's), intensity (0..1), flavor (only a real #98
## flavour in ModTriggerSynth.FLAVORS is passed on; anything else plays unflavoured).
func mod_trigger(id: StringName, _die: Variant = null, _anchor: StringName = &"", ctx: Dictionary = {}) -> float:
	if sfx == null or not sfx.has_method("play_mod_trigger"):
		return -1.0
	_sync_trigger_audio()
	var flavor := StringName(ctx.get("flavor", &""))
	if not ModTriggerSynth.FLAVORS.has(flavor):
		flavor = &""
	var s := float(sfx.call("play_mod_trigger", id, int(ctx.get("tier", -1)), float(ctx.get("intensity", 1.0)), -1.0, flavor))
	calls.append("mod:%s" % id)
	return s


## Hands the hook the crowd (once) and the count-up speed (0 1x, 1 2x, 2
## Instant, as JuicePlan uses), if the SfxManager has those properties.
func _sync_trigger_audio() -> void:
	if table == null:
		return
	if "trigger_speed_mode" in sfx:
		if table.has_method("get_speed_mode"):
			sfx.set("trigger_speed_mode", int(table.call("get_speed_mode")))
		elif "speed_mode" in table:
			sfx.set("trigger_speed_mode", int(table.get("speed_mode")))
	if not _crowd_set and "crowd" in sfx and "juice" in table and table.get("juice") != null:
		var crowd: Variant = table.get("juice").get("crowd")
		if crowd is Node:
			sfx.set("crowd", crowd)
			_crowd_set = true


## Plays `event` (or its fallback) if the SfxManager has it. Returns what played.
func cue(event: StringName, jitter: float = 0.06) -> StringName:
	if sfx == null:
		return &""
	if _has(event):
		sfx.call("play", event, 1.0, 0.0, jitter)
		_record(String(event))
		return event
	var fb: StringName = FALLBACK.get(event, &"")
	if fb != &"" and _has(fb):
		sfx.call("play", fb, 1.0, 0.0, jitter)
		_record("%s(fb)" % fb)
		return fb
	return &""


func _record(s: String) -> void:
	calls.append(s)
	if calls.size() > 400:
		calls = calls.slice(200)


func _has(event: StringName) -> bool:
	return sfx.has_method("has_event") and bool(sfx.call("has_event", event))
