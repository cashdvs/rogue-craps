## Builds TableRule handlers from TableSetup.rules and the handful's special
## dice. TableSetup.rules entries: {id: StringName, params: Dictionary} plus
## optional name / description (a RunRuleData resource works too). Add a new
## cheat: write a TableRule subclass and register it in SCRIPTS + INFO.
class_name TableRules
extends RefCounted

const SCRIPTS := {
	&"cold_sixes": preload("res://scripts/core/rules/rule_cold_sixes.gd"),
	&"first_throw": preload("res://scripts/core/rules/rule_first_throw.gd"),
	&"greedy_pot": preload("res://scripts/core/rules/rule_greedy_pot.gd"),
	&"cold_hands": preload("res://scripts/core/rules/rule_no_hot_hand.gd"),
	&"short_table": preload("res://scripts/core/rules/rule_label.gd"),
	&"heavy_burn": preload("res://scripts/core/rules/rule_label.gd"),
	&"madame_shuffle": preload("res://scripts/core/rules/rule_madame_shuffle.gd"),
	&"pit_boss": preload("res://scripts/core/rules/rule_pit_boss.gd"),
	&"ashmouth": preload("res://scripts/core/rules/rule_no_hot_hand.gd"),
	&"straight_man": preload("res://scripts/core/rules/rule_straight_man.gd"),
	&"collector": preload("res://scripts/core/rules/rule_collector.gd"),
	&"bloodletter": preload("res://scripts/core/rules/rule_bloodletter.gd"),
}
## id -> [name, one line, kind] (Game Designer's text; a rule's own name /
## description override these).
const INFO := {
	&"cold_sixes": ["Cold Sixes", "6s never light.", TableRule.Kind.TWIST],
	&"first_throw": ["First Throw", "Bounties only count on a hand's first throw.", TableRule.Kind.TWIST],
	&"short_table": ["Short Table", "4 hands.", TableRule.Kind.TWIST],
	&"heavy_burn": ["Heavy Burn", "A bust costs 3 Soul.", TableRule.Kind.TWIST],
	&"greedy_pot": ["Greedy Pot", "Pot at least 2 dice per throw.", TableRule.Kind.TWIST],
	&"cold_hands": ["Cold Hands", "No Hot Hand.", TableRule.Kind.TWIST],
	&"madame_shuffle": ["Madame Shuffle", "Rerolls your highest unpotted die after each throw.", TableRule.Kind.CHEAT],
	&"pit_boss": ["The Pit Boss", "One face value locked each hand.", TableRule.Kind.CHEAT],
	&"ashmouth": ["Ashmouth", "No Hot Hand.", TableRule.Kind.CHEAT],
	&"straight_man": ["The Straight Man", "Only 5-die runs count.", TableRule.Kind.CHEAT],
	&"collector": ["The Collector", "Face mods are off on the first throw.", TableRule.Kind.CHEAT],
	&"bloodletter": ["The Bloodletter", "Every Soul cost is doubled: a bust costs 2.", TableRule.Kind.CHEAT],
}
## Special dice with a table-side handler (scoring-only ones live in
## BonfireScoring: twin_flame, coven, cracked x2, blood_pact, last_breath).
const DIE_SCRIPTS := {
	&"mirror": preload("res://scripts/core/rules/die_mirror.gd"),
	&"cracked": preload("res://scripts/core/rules/die_cracked.gd"),
	&"bellows": preload("res://scripts/core/rules/die_bellows.gd"),
	# Scored in BonfireScoring (run gap); the handler only shows it.
	&"wanderer": preload("res://scripts/core/rules/rule_label.gd"),
}
## Special die id -> [name, one line] for the HUD.
const DIE_INFO := {
	&"mirror": ["Mirror Die", "Copies the nearest die in the tray (ties: lower)."],
	&"cracked": ["Cracked Die", "x2 mult on its pot; 1 in 6 it shatters for good."],
	&"bellows": ["Bellows Die", "Each Hot Hand gives +2 mult instead of +1."],
	&"wanderer": ["Wanderer Die", "A run with it may skip one value (1-2-4-5)."],
}


## One rule entry -> {id, params, name, description} (accepts a Dictionary
## or any Object with id / params / display_name / description).
static func normalize(entry: Variant) -> Dictionary:
	if entry is Dictionary:
		return {"id": StringName(entry.get("id", &"")), "params": entry.get("params", {}),
			"name": str(entry.get("name", "")), "description": str(entry.get("description", ""))}
	if entry is Object:
		var o := entry as Object
		return {"id": StringName(o.get("id")), "params": o.get("params") if o.get("params") is Dictionary else {},
			"name": str(o.get("display_name")) if o.get("display_name") != null else "",
			"description": str(o.get("description")) if o.get("description") != null else ""}
	return {"id": StringName(str(entry)), "params": {}, "name": "", "description": ""}


static func make(entry: Variant) -> TableRule:
	var e := normalize(entry)
	var id: StringName = e["id"]
	var script: GDScript = SCRIPTS.get(id, preload("res://scripts/core/rules/rule_label.gd"))
	if not SCRIPTS.has(id):
		push_warning("TableRules: unknown rule '%s' (shown only)." % id)
	var r: TableRule = script.new()
	var info: Array = INFO.get(id, [String(id).capitalize(), "", TableRule.Kind.TWIST])
	r.id = id
	r.params = (e["params"] as Dictionary).duplicate(true)
	r.display_name = e["name"] if e["name"] != "" else info[0]
	r.description = e["description"] if e["description"] != "" else info[1]
	r.kind = info[2]
	return r


## Handlers for TableSetup.rules (in order), then one per special die kind
## in the handful that has a table-side ability.
static func build(entries: Array, specials: Array = []) -> Array[TableRule]:
	var out: Array[TableRule] = []
	var seen: Array[StringName] = []
	for sp in specials:
		var sid := StringName(sp)
		if DIE_SCRIPTS.has(sid) and not seen.has(sid):
			seen.append(sid)
			var r: TableRule = (DIE_SCRIPTS[sid] as GDScript).new()
			r.id = sid
			r.kind = TableRule.Kind.DIE
			var info: Array = DIE_INFO.get(sid, [String(sid).capitalize() + " Die", ""])
			r.display_name = info[0]
			r.description = info[1]
			out.append(r)
	for e in entries:
		out.append(make(e))
	return out
