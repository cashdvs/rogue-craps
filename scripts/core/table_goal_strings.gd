## Target-table lines (design/strings_v1.md "HUD table goal (PR1)", ids in
## the comments; table_goals_v1 PR1). Numbers get thousands separators.
class_name TableGoalStrings
extends RefCounted

const TARGET_LABEL := "TARGET"  # goal_target_label
const TO_GO := "%s to go · %d hands left"  # goal_to_go
const TO_GO_ONE_HAND := "%s to go · 1 hand left"  # goal_to_go_one_hand
const PASSED := "PASSED · %d hands left"  # goal_passed
const PASSED_ONE_HAND := "PASSED · 1 hand left"  # goal_passed_one_hand
const OVER := "+%s"  # goal_over
const MISS := "Missed: -%d Soul"  # goal_miss
const PREVIEW_TARGET := "Target %s"  # table_preview_target
const PREVIEW_TARGET_RULE := "Target %s · %s"  # table_preview_target_rule
const PREVIEW_MISS := "Miss: -%d Soul"  # table_preview_miss
const BOSS_TAG := "BOSS"  # goal_boss_tag (the plate's boss tag)
const SEALS_CHIP := "SEALS · %d"  # hud_seals_chip ("SEALS · {n}")


## 1234567 -> "1,234,567".
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## "TARGET 1,000"
static func target(n: int) -> String:
	return "%s %s" % [TARGET_LABEL, num(n)]


## Line 3 of the plate: "360 to go · 3 hands left", or once passed
## "PASSED · 3 hands left" (+ " +240" over the target).
static func progress(target_points: int, banked: int, hands_left: int) -> String:
	if banked >= target_points:
		var s := PASSED_ONE_HAND if hands_left == 1 else PASSED % hands_left
		return s + ((" " + OVER % num(banked - target_points)) if banked > target_points else "")
	var left := num(target_points - banked)
	return TO_GO_ONE_HAND % left if hands_left == 1 else TO_GO % [left, hands_left]


## "TARGET 1,000 · 360 to go · 3 hands left" for one-line HUD readouts.
static func line(run: BonfireRun) -> String:
	return "%s · %s" % [target(run.goal.target), progress(run.goal.target, run.points, run.hands_left)]


## "SEALS · 3" for the HUD Seals chip.
static func seals(n: int) -> String:
	return SEALS_CHIP % n


## The Soul a miss really costs at this table: `miss_soul` through each
## rule's own soul_cost (the same TableRule handlers BonfireRun.soul_cost
## charges with; the Bloodletter doubles it, 5 -> 10). Rules are TableRules
## or map entries (RunRuleData), which are built through TableRules.make.
static func miss_cost(miss_soul: int, rules: Array) -> int:
	var c := miss_soul
	for r in rules:
		var tr: TableRule = r if r is TableRule else TableRules.make(r)
		c = tr.soul_cost(null, c, &"timeout")
	return c


## Map table preview miss line: "Miss: -5 Soul" ("Miss: -10 Soul" under the Bloodletter).
static func preview_miss(miss_soul: int, rules: Array = []) -> String:
	return PREVIEW_MISS % miss_cost(miss_soul, rules)


## Map table preview: "Target 1,000" or "Target 1,000 · <rule>".
static func preview(target_points: int, rule_name: String = "") -> String:
	return PREVIEW_TARGET % num(target_points) if rule_name.is_empty() else PREVIEW_TARGET_RULE % [num(target_points), rule_name]
