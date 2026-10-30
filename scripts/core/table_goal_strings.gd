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


## Map table preview: "Target 1,000" or "Target 1,000 · <rule>".
static func preview(target_points: int, rule_name: String = "") -> String:
	return PREVIEW_TARGET % num(target_points) if rule_name.is_empty() else PREVIEW_TARGET_RULE % [num(target_points), rule_name]
