## Bonfire HUD (plain Controls, 1920x1080 design space): Embers / points,
## hands left, the bounty cards, the hand's pot with the live pot preview
## "TRIPS: (30+12) x3 = 126", the rethrow risk "Throw 2 cold dice: 1 in 3
## burns", BANK / THROW and the end screen (how_bonfire_plays.md section 4).
## The combo table is printed on the felt (FeltComboTable), not here.
class_name BonfireHud
extends BonfireHudGoal

# This script is the top of a chain of layers, each in its own short file:
#   bonfire_hud_build.gd (BonfireHudBuild) variables + building the labels and buttons
#   bonfire_hud_goal.gd  (BonfireHudGoal)  goal / bounty readout, meters, stamps
# This file keeps the prompts, flash text, banners, portrait layout and end panel.


## Leave table asks once (PM, Oct 19: no modal): the first tap or L turns
## the button into "Leave? Tap again"; a second one within LEAVE_CONFIRM_S
## leaves (emits leave_pressed). Otherwise the text goes back.
func press_leave() -> void:
	if not leave_button.visible:
		return
	var now: float = leave_clock.call()
	if _leave_asked_at >= 0.0 and now - _leave_asked_at <= LEAVE_CONFIRM_S:
		_reset_leave_ask()
		leave_pressed.emit()
	else:
		_leave_asked_at = now
		leave_button.text = LEAVE_ASK_TEXT


func _reset_leave_ask() -> void:
	_leave_asked_at = -1.0
	leave_button.text = LEAVE_TEXT


## Pops a short callout ("doesn't score") just above screen point `at`,
## then fades it out.
func callout(at: Vector2, text: String = "doesn't score") -> void:
	callout_label.text = text
	callout_label.position = at - Vector2(callout_label.size.x * 0.5, callout_label.size.y + 30.0)
	callout_label.modulate.a = 1.0
	var tw := callout_label.create_tween().set_ignore_time_scale(true)
	tw.tween_property(callout_label, "position:y", callout_label.position.y - 24.0, 0.7)
	tw.parallel().tween_property(callout_label, "modulate:a", 0.0, 0.3).set_delay(0.5)


## Bank: embers fly from the pot into the Ember counter (the pile).
func ember_flow(count: int, seconds: float, reduced: bool = false) -> void:
	var from := pot_label.global_position + pot_label.size * 0.5
	var to := coin_label.global_position + Vector2(coin_label.size.x * 0.5, coin_label.size.y * 0.5)
	var n := clampi(count, 1, 6 if reduced else 24)
	for i in n:
		var e := ColorRect.new()
		e.color = Palette.EMBER if i % 3 else Palette.BRASS_HI
		e.size = Vector2(10, 10)
		e.rotation = PI / 4
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(e)
		e.global_position = from + Vector2(randf_range(-40, 40), randf_range(-10, 10))
		var mid := (e.global_position + to) * 0.5 + Vector2(0, -160)
		var start := e.global_position
		var delay := seconds * 0.5 * float(i) / float(n)
		var tw := e.create_tween().set_ignore_time_scale(true)
		tw.tween_interval(delay)
		tw.tween_method(func(f: float) -> void:
			var a := start.lerp(mid, f)
			var b := mid.lerp(to, f)
			e.global_position = a.lerp(b, f), 0.0, 1.0, seconds * 0.5)
		tw.tween_callback(func() -> void:
			coin_label.pivot_offset = coin_label.size * 0.5
			coin_label.scale = Vector2.ONE * 1.08
			var t2 := coin_label.create_tween().set_ignore_time_scale(true)
			t2.tween_property(coin_label, "scale", Vector2.ONE, 0.08)
			e.queue_free())


## Bust: the Soul flask (the Soul meter) cracks and drips.
func flask_crack(rect: Rect2, reduced: bool = false) -> void:
	var o := FlaskCrack.new()
	o.rect = rect
	o.reduced = reduced
	add_child(o)


## Small flash on the bounties just banked.
func flash_ticks(ids: Array) -> void:
	for id in ids:
		var l: Label = bounty_rows.get(id)
		if l == null:
			continue
		l.pivot_offset = Vector2(0, 14)
		var tw := l.create_tween()
		l.modulate = Color(2.0, 2.0, 1.2)
		tw.tween_property(l, "scale", Vector2.ONE * 1.25, 0.1)
		tw.tween_property(l, "scale", Vector2.ONE, 0.2)
		tw.parallel().tween_property(l, "modulate", Color.WHITE, 0.5)


## The clearing bank (how_bonfire_plays.md §4): "TABLE CLEARED: chase the
## bonus or Leave table" (ClearedBanner: 1.8 s at 1x, never blocks input).
## speed: 2.0 at the 2x roll speed; instant: the Instant speed / reduced motion.
func show_cleared(speed: float = 1.0, instant: bool = false) -> void:
	cleared_banner.pt_px = ui_pt_px
	cleared_banner.rest_center = _banner_center()
	cleared_banner.play(speed, instant)


## Where the banner rests: over the upper felt, clear of the BANKED flash.
func _banner_center() -> Vector2:
	if portrait_goal.visible:
		var vs := get_viewport_rect().size
		return Vector2(960, maxf(vs.y * 0.40, result_label.position.y + 600.0))
	return Vector2(960, 620)


func flash(text: String, col: Color) -> void:
	result_label.text = text
	result_label.label_settings.font_color = col
	result_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(result_label, "modulate:a", 0.0, 0.4)


## Space (design px) between the hands line and the rules panel in portrait.
const RULES_GAP := 14.0


## Phone portrait (the screen is taller than wide): the goal readout at the
## top replaces the bounty cards, so there is one list; the bank / bust
## banner moves down under the readout so both stay readable. PC and phone
## landscape keep the cards and the banner where they were.
func set_portrait(on: bool) -> void:
	if on == portrait_goal.visible:
		return
	portrait_goal.visible = on
	checklist_panel.visible = not on
	_place_rules()
	_place_result()


## Rules panel: BonfireHudGoal's spot, but in portrait (no cards) it also
## clears the Embers / points / hands lines above it.
func _place_rules() -> void:
	super()
	if portrait_goal != null and portrait_goal.visible:
		rules_panel.position.y = maxf(rules_panel.position.y, hands_label.position.y + hands_label.size.y + RULES_GAP)  # QA: don't crowd the Embers lines


## The bank / bust banner: under the readout in portrait (its height can
## change when the goal's rows are built), else at RESULT_Y.
func _place_result() -> void:
	if portrait_goal.visible:
		result_label.position.y = portrait_goal.position.y + portrait_goal.get_combined_minimum_size().y + RESULT_GAP
	else:
		result_label.position.y = RESULT_Y


## Run mode: CONTINUE instead of RESTART on the end panel.
func set_run_mode(on: bool) -> void:
	restart_button.visible = not on
	continue_button.visible = on


func show_end(run: BonfireRun) -> void:
	var sm := run.table_summary
	var ember_line := "%d points became %d Embers%s.  Embers %d." % [run.points, int(sm.get("points_embers", 0)),
		(", clear +%d" % int(sm["clear_embers"])) if int(sm.get("clear_embers", 0)) > 0 else "", run.embers]
	match run.state:
		BonfireRun.State.CLEARED:
			end_title.text = "Table cleared"
			var bonus: Array[String] = []
			for b: BountyData in run.goal.bonus:
				if run.is_ticked(b):
					bonus.append("%s +%d" % [b.display_name, b.bonus_embers])
			end_body.text = "You banked every bounty%s.\n%s\nSoul %d." % [
				(" (bonus: %s)" % ", ".join(bonus)) if not bonus.is_empty() else "", ember_line, run.soul]
		_ when run.forfeited and run.state != BonfireRun.State.RUN_OVER:
			end_title.text = "You left the table"
			end_body.text = "%d bounties unclaimed: -%d Soul (Soul %d).\n%s" % [run.unticked_required(), int(sm.get("timeout_soul", 0)), run.soul, ember_line]
		BonfireRun.State.RUN_OVER:
			end_title.text = "Out of Soul"
			end_body.text = "Your Soul hit 0, so the run is over.\n%s" % ember_line
		_:
			end_title.text = "Out of hands"
			end_body.text = "%d bounties unclaimed: -%d Soul (Soul %d).\n%s" % [run.unticked_required(), int(sm.get("timeout_soul", 0)), run.soul, ember_line]
	end_panel.visible = true
	# A table can end mid-tutorial: the hint panel must not cover the end
	# panel (#103 N6). stop() also drops the waiting hints, so dismiss()
	# can't pop the next one over the end panel.
	tutorial.stop()
