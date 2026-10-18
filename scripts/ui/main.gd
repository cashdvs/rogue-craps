## Greybox main screen: roll two dice and watch the craps rules resolve.
##
## This script is deliberately "thin": it loads data, asks DiceRoller for
## faces, hands the numbers to CrapsRound, and displays the RollResult.
## All rule decisions live in scripts/core so they stay testable.
extends Control

## The two starting dice. Assign different .tres files in the inspector to
## try other dice (later these will come from the "choose 2 dice" screen).
@export var starting_dice: Array[DieData] = []
## The bet being shown (only Pass Line semantics exist so far).
@export var bet_type: BetType

## Optional fixed seed for repeatable greybox sessions. -1 = random.
@export var rng_seed: int = -1

var _round := CrapsRound.new()
var _roller: DiceRoller
## Run copies of the dice (see DieData.make_run_copy for why).
var _dice: Array[DieData] = []
var _wins: int = 0
var _losses: int = 0

@onready var _die_labels: Array[Label] = [%Die1Value, %Die2Value]
@onready var _die_name_labels: Array[Label] = [%Die1Name, %Die2Name]
@onready var _phase_label: Label = %PhaseLabel
@onready var _point_label: Label = %PointLabel
@onready var _total_label: Label = %TotalLabel
@onready var _result_label: Label = %ResultLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _bet_label: Label = %BetLabel
@onready var _roll_button: Button = %RollButton


func _ready() -> void:
	_roller = DiceRoller.new(rng_seed)

	# Copy the dice so mid-run face edits never touch the shared .tres files.
	for die in starting_dice:
		if die != null:
			_dice.append(die.make_run_copy())
	# Safety net: always have exactly two dice even if the scene is misconfigured.
	while _dice.size() < 2:
		push_warning("Main: missing starting die, using a standard d6.")
		_dice.append(DieData.make_standard_d6())

	for i in range(_die_name_labels.size()):
		var die := _dice[i]
		_die_name_labels[i].text = "%s (Lv %d)" % [die.display_name, die.level]

	if bet_type != null:
		_bet_label.text = "Bet: %s (pays %s:1)\n%s" % [bet_type.display_name, str(bet_type.payout), bet_type.description]
	else:
		_bet_label.text = "Bet: none"

	# Focus none so Space doesn't BOTH press the button and trigger our key
	# handler (which would roll twice).
	_roll_button.focus_mode = Control.FOCUS_NONE
	_roll_button.pressed.connect(roll)

	_result_label.text = "Press Roll or Space to start the come-out roll."
	_refresh_state_labels()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		roll()
		get_viewport().set_input_as_handled()


## Rolls both dice and resolves the result. Public so other code can call it.
func roll() -> RollResult:
	var faces := _roller.roll_dice(_dice)
	var values := DiceRoller.face_values(faces)
	var result := _round.resolve_dice(values)

	for i in range(_die_labels.size()):
		_die_labels[i].text = str(values[i])
	_total_label.text = "Total: %d" % result.total

	if result.is_win():
		_wins += 1
	elif result.is_loss():
		_losses += 1

	_result_label.text = result.message
	_refresh_state_labels()
	return result


func _refresh_state_labels() -> void:
	_phase_label.text = "Phase: %s" % CrapsRound.phase_name(_round.phase)
	_point_label.text = "Point: %s" % (str(_round.point) if _round.has_point() else "OFF")
	_score_label.text = "Wins: %d   Losses: %d" % [_wins, _losses]
