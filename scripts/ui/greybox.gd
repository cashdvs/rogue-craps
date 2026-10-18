## Greybox screen: plain buttons and labels for testing the betting rules.
##
## The pretty proof-of-concept lives in scenes/table.tscn. This screen stays
## as a quick, no-frills way to poke at CrapsTable. It's deliberately "thin":
## it never decides a rule itself; everything goes through scripts/core.
extends Control

## The dice to roll. Any number of dice is displayed (labels are built at
## runtime); craps rules expect totals 2-12 for now.
@export var starting_dice: Array[DieData] = []
## Bets offered as buttons.
@export var bet_catalog: BetCatalog
## Fixed seed for repeatable sessions. -1 (DiceRoller.RANDOM_SEED) = random;
## any other value, including other negatives, is a real seed.
@export var rng_seed: int = DiceRoller.RANDOM_SEED
## Doc section 3: start with 50 Coin.
@export var starting_coin: int = 50

var bankroll: Bankroll
var table: CrapsTable

var _roller: DiceRoller
## Run copies of the dice (see DieData.make_run_copy for why).
var _dice: Array[DieData] = []
## One value Label per die, built at runtime to match _dice.size().
var _die_value_labels: Array[Label] = []

@onready var _coin_label: Label = %CoinLabel
@onready var _dice_row: HBoxContainer = %DiceRow
@onready var _total_label: Label = %TotalLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _point_label: Label = %PointLabel
@onready var _result_label: Label = %ResultLabel
@onready var _payout_label: Label = %PayoutLabel
@onready var _bet_buttons: HFlowContainer = %BetButtons
@onready var _active_bets_label: Label = %ActiveBetsLabel
@onready var _clear_button: Button = %ClearButton
@onready var _roll_button: Button = %RollButton


func _ready() -> void:
	_roller = DiceRoller.new(rng_seed)
	bankroll = Bankroll.new(starting_coin)
	table = CrapsTable.new(bankroll)

	# Copy the dice so mid-run face edits never touch the shared .tres files.
	for die in starting_dice:
		if die == null:
			push_error("Greybox: a starting die slot is empty.")
			continue
		_dice.append(die.make_run_copy())
	_build_die_views()
	_build_bet_buttons()

	# Buttons never take keyboard focus, so Space only triggers our handler.
	_roll_button.focus_mode = Control.FOCUS_NONE
	_clear_button.focus_mode = Control.FOCUS_NONE
	_roll_button.pressed.connect(roll)
	_clear_button.pressed.connect(clear_bets)
	_result_label.text = "Place a bet, then press Roll or Space."
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		roll()
		get_viewport().set_input_as_handled()


## Rolls all dice and resolves the roll. Returns the report, or null if
## the dice couldn't be rolled. Public so tests can drive the scene.
func roll() -> TableReport:
	var faces := _roller.roll_dice(_dice)
	if faces.is_empty():
		# DiceRoller already push_error'd the details.
		_result_label.text = "Dice error: a die has no faces. Check the die data."
		return null
	var values := DiceRoller.face_values(faces)
	for i in range(mini(values.size(), _die_value_labels.size())):
		_die_value_labels[i].text = str(values[i])

	var report := table.roll(values)
	if report.rejected:
		_result_label.text = report.reject_reason
		return report
	_total_label.text = "Total: %d" % report.roll.total
	_result_label.text = report.roll.message
	var lines := report.lines()
	_payout_label.text = "  |  ".join(lines)
	if not lines.is_empty():
		_payout_label.text += "   (net %+d)" % report.net
	_refresh()
	return report


## Adds the table minimum to a bet. Returns "" on success or the reason.
func press_bet(bet_id: StringName) -> String:
	var bet := bet_catalog.find(bet_id)
	var reason := table.place_bet(bet, table.min_bet)
	_result_label.text = reason if reason != "" else "Bet placed on %s." % bet.display_name
	_refresh()
	return reason


func clear_bets() -> void:
	var returned := table.clear_all_removable()
	_result_label.text = "Took down %d Coin of bets." % returned
	_refresh()


## Creates one die box per die, so 1, 2 or 3 dice all display correctly.
func _build_die_views() -> void:
	for child in _dice_row.get_children():
		child.queue_free()
	_die_value_labels.clear()
	for die in _dice:
		var column := VBoxContainer.new()
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(130, 130)
		box.color = Color(0.93, 0.93, 0.88)
		var value := Label.new()
		value.set_anchors_preset(Control.PRESET_FULL_RECT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 80)
		value.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		value.text = "-"
		box.add_child(value)
		var die_name := Label.new()
		die_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		die_name.text = "%s (Lv %d)" % [die.display_name, die.level]
		column.add_child(box)
		column.add_child(die_name)
		_dice_row.add_child(column)
		_die_value_labels.append(value)


func _build_bet_buttons() -> void:
	for bet in bet_catalog.bets:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 44)
		button.text = "%s +%d (%s)" % [bet.display_name, table.min_bet, bet.ratio_text()]
		button.tooltip_text = bet.description
		button.pressed.connect(press_bet.bind(bet.id))
		button.set_meta("bet_id", bet.id)
		_bet_buttons.add_child(button)


func _refresh() -> void:
	_coin_label.text = "Coin: %d" % bankroll.coin
	_phase_label.text = "Phase: %s" % CrapsRound.phase_name(table.craps.phase)
	_point_label.text = "Point: %s" % (str(table.craps.point) if table.craps.has_point() else "OFF")
	var parts := PackedStringArray()
	for bet in table.active_bets:
		parts.append("%s %d" % [bet.bet_type.display_name, bet.stake])
	_active_bets_label.text = "On the table: " + (", ".join(parts) if not parts.is_empty() else "nothing")
	# Grey out bets that can't be placed right now; the tooltip says why.
	for child in _bet_buttons.get_children():
		var button := child as Button
		var bet := bet_catalog.find(button.get_meta("bet_id"))
		var reason := table.can_place(bet, table.min_bet)
		button.disabled = reason != ""
		button.tooltip_text = bet.description if reason == "" else reason
