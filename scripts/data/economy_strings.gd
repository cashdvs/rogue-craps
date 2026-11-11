## Player-facing economy lines (design/strings_v1.md, economy_balance_v1.md
## P1/P3-P5), keyed by their strings_v1 id. Numbers come from the data, so
## the shipped values read exactly as strings_v1 has them.
class_name EconomyStrings
extends RefCounted

## strings_v1 table_points_embers (P1). Miss / standalone-legacy context
## only: a cleared map table pays a fixed amount instead
## (fixed_table_payout_v1).
const TABLE_POINTS_EMBERS := "Points: 1 Ember per %d, up to %d per table."

## strings_v1 table_payout_* (fixed_table_payout_v1). Copied verbatim.
const TEXT: Dictionary[String, String] = {
	"table_payout_clear": "Table beaten: +{n} Embers.",
	"table_payout_elite": "Elite beaten: +{n} Embers.",
	"table_payout_boss": "Boss beaten: +{n} Embers.",
	"table_payout_final": "Final table beaten: +{n} Embers, run complete.",
	"table_payout_continue": "Continue",
	"table_payout_preview": "+{n} Embers",
}
const TABLE_PAYOUT_CONTINUE: String = TEXT["table_payout_continue"]


## strings_v1 row [param id] with [param args] filled ("" if unknown).
static func text(id: String, args: Dictionary = {}) -> String:
	return TEXT.get(id, "").format(args)


## Payout summary line for a cleared map table.
static func table_payout_line(table_type: int, n: int, is_final: bool = false) -> String:
	if is_final:
		return text("table_payout_final", {"n": n})
	var id := "table_payout_clear"
	if table_type == MapGenData.NodeType.ELITE:
		id = "table_payout_elite"
	elif table_type == MapGenData.NodeType.BOSS:
		id = "table_payout_boss"
	return text(id, {"n": n})


## Legacy / miss conversion line on the table end panel.
const POINTS_BECAME_EMBERS := "%d points became %d Embers%s.  Embers %d."


## Short top-right preview for a fixed-payout table (table_payout_preview).
static func table_payout_preview(n: int) -> String:
	return text("table_payout_preview", {"n": n})


## Live points-line preview (HUD top-right). A fixed-payout goal shows the
## short table_payout_preview string; the full table_payout_* sentences stay
## on the end panel. Miss / legacy tables keep the conversion preview.
static func points_preview_line(run: BonfireRun, pts: int) -> String:
	var g := run.goal
	# Mid-table and a successful clear: the short fixed payout. A miss still
	# converts, so the preview falls back to the cap line.
	if g != null and g.fixed_payout and (not run.is_over() or run.cleared):
		return table_payout_preview(g.clear_embers)
	return "points %d → +%d Embers" % [pts, BonfireRun.points_to_embers(run.tuning, pts)]


## End-panel Ember line: fixed payout string when `table_summary.fixed_payout`
## is true, otherwise the miss / legacy "points became Embers" line.
static func end_ember_line(run: BonfireRun) -> String:
	var sm := run.table_summary
	if bool(sm.get("fixed_payout", false)):
		var g := run.goal
		var t: int = g.table_type if g != null else MapGenData.NodeType.TABLE
		return table_payout_line(t, int(sm.get("clear_embers", 0)), g != null and g.is_final)
	var clear := int(sm.get("clear_embers", 0))
	return POINTS_BECAME_EMBERS % [run.points, int(sm.get("points_embers", 0)),
		(", clear +%d" % clear) if clear > 0 else "", run.embers]


## "Points: 1 Ember per 100, up to 5 per table." from `t`; uncapped tuning
## drops the cap clause. Miss / standalone-legacy conversion only; the
## table HUD (bonfire_hud.gd, Godot Dev's) still shows this preview.
static func table_points_embers(t: BonfireTuning) -> String:
	if t.points_embers_cap <= 0:
		return "Points: 1 Ember per %d." % t.points_per_ember
	return TABLE_POINTS_EMBERS % [t.points_per_ember, t.points_embers_cap]


## strings_v1 shop_rare_tag (rare_dice_v1 §4): the shop card's tag on a rare die.
const SHOP_RARE_TAG := "Rare: its carved faces come with the die."
## strings_v1 rare_v2_risk_tag: the tag on a risky rare (DieShape.risky).
const RARE_V2_RISK_TAG := "Risk"
## strings_v1 rare_carved_locked (rare_dice_v1 §3): a rare's pre-carved face refuses a carve.
const RARE_CARVED_LOCKED := "Carved at the forge; this face cannot be recarved."


## strings_v1 shop_soul_button (P3): "Soul Draught: +4 max Soul, heals 4. 12 Embers".
static func shop_soul_button(amount: int, price: int) -> String:
	return "Soul Draught: +%d max Soul, heals %d. %d Embers" % [amount, amount, price]


## strings_v1 shop_premium_seal_button (P4), "Rare Seal: 12 Embers", plus
## which rare Seal it is, e.g. "Rare Seal: 12 Embers (Transference)".
static func shop_premium_seal_button(price: int, seal_name: String) -> String:
	return "Rare Seal: %d Embers (%s)" % [price, seal_name]


## strings_v1 shop_floor_price_note (P5): "Prices on this floor: 25% above Floor 1."
static func shop_floor_price_note(pct: int) -> String:
	return "Prices on this floor: %d%% above Floor 1." % pct
