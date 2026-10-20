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
	# Floor 3 boss (run_tuning_v1.md): the Cold Sixes handler under his own
	# name; the run side applies his 2-Soul bust.
	&"mister_wick": preload("res://scripts/core/rules/rule_cold_sixes.gd"),
	# The other two Floor 3 bosses (run_tuning_v1.md Addendum 2) reuse twist
	# handlers with boss numbers (DEFAULT_PARAMS below).
	&"baron_vig": preload("res://scripts/core/rules/rule_greedy_pot.gd"),
	&"odds_bodkin": preload("res://scripts/core/rules/rule_first_throw.gd"),
}
## Params a rule id gets when its entry doesn't set them (the entry's own
## params win): the bosses that borrow a twist's handler.
const DEFAULT_PARAMS := {
	&"mister_wick": {"face": 6},
	&"baron_vig": {"min_pot": 3},
	&"odds_bodkin": {"throws": 1},
}
## id -> [name, one line, kind] (Game Designer's text, design/strings_v1.md;
## a rule's own name / description override these). The Elite twists'
## "+1 hand" is the retune's hands_delta (run_tuning_v1.md addendum), which
## the run applies; the line tells the player.
const INFO := {
	&"cold_sixes": ["Cold Sixes", "6s never light, but you get +1 hand.", TableRule.Kind.TWIST],
	&"first_throw": ["First Throw", "Bounties count only on each hand's first 2 throws; +1 hand.", TableRule.Kind.TWIST],
	&"short_table": ["Short Table", "4 hands.", TableRule.Kind.TWIST],
	&"heavy_burn": ["Heavy Burn", "A bust costs 3 Soul.", TableRule.Kind.TWIST],
	&"greedy_pot": ["Greedy Pot", "Pot at least 2 dice every throw, but you get +1 hand.", TableRule.Kind.TWIST],
	&"cold_hands": ["Cold Hands", "No Hot Hand, but you get +1 hand.", TableRule.Kind.TWIST],
	&"madame_shuffle": ["Madame Shuffle", "After each throw, she rerolls one random lit die.", TableRule.Kind.CHEAT],
	&"pit_boss": ["The Pit Boss", "One face value locked each hand.", TableRule.Kind.CHEAT],
	&"ashmouth": ["Ashmouth", "No Hot Hand, and you get one fewer hand.", TableRule.Kind.CHEAT],
	&"straight_man": ["The Straight Man", "Runs of 3 don't count; runs of 4 or 5 still do.", TableRule.Kind.CHEAT],
	&"collector": ["The Collector", "Face mods are off on the first throw.", TableRule.Kind.CHEAT],
	&"bloodletter": ["The Bloodletter", "Every Soul cost is doubled.", TableRule.Kind.CHEAT],
	&"mister_wick": ["Mister Wick", "6s never light, and a bust costs 2 Soul.", TableRule.Kind.CHEAT],
	&"baron_vig": ["Baron Vig", "Pot at least 3 dice every throw.", TableRule.Kind.CHEAT],
	&"odds_bodkin": ["Odds Bodkin", "Bounties count only on each hand's first throw; +1 hand.", TableRule.Kind.CHEAT],
}
## Special dice with a table-side handler (scoring-only ones live in
## BonfireScoring: twin_flame, coven, cracked x2, blood_pact, last_breath).
const DIE_SCRIPTS := {
	&"mirror": preload("res://scripts/core/rules/die_mirror.gd"),
	&"ferryman": preload("res://scripts/core/rules/die_ferryman.gd"),
	&"cracked": preload("res://scripts/core/rules/die_cracked.gd"),
	&"bellows": preload("res://scripts/core/rules/die_bellows.gd"),
	# Scored in BonfireScoring (run gap); the handler only shows it.
	&"wanderer": preload("res://scripts/core/rules/rule_label.gd"),
}
## Special die id -> [name, one line] for the HUD.
const DIE_INFO := {
	&"mirror": ["Mirror Die", "Copies the nearest die in the tray (ties: lower)."],
	&"ferryman": ["Ferryman's Coin", "Heads copies your highest die, Tails your lowest. Alone: Heads 5, Tails Blank."],
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
	r.params = (DEFAULT_PARAMS.get(id, {}) as Dictionary).duplicate(true)
	r.params.merge((e["params"] as Dictionary).duplicate(true), true)
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
