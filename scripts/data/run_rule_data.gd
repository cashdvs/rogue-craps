## An Elite twist or a boss cheat (map/events spec §1, Game Designer pools).
## Data only. MapRun picks them (seeded) and passes them to the table in
## RunTableSetup.rules; the table enforces them (Godot Dev). Only the two
## setup-value rules change numbers on the run's side: hands_delta (Short
## Table) and bust_soul_loss (Heavy Toll).
class_name RunRuleData
extends Resource

enum Kind { TWIST, CHEAT }

@export var id: StringName = &""
## Twists: the rule's name. Cheats: the boss's name (e.g. "Madame Shuffle").
@export var display_name: String = ""
## "{hands}" is replaced by the table's real hands (text()).
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TWIST
## Added to the table's hands (Short Table: 5 -> 4 is -1).
@export var hands_delta: int = 0
## Soul a bust costs at this table; -1 = the normal value (Heavy Toll: 3).
@export var bust_soul_loss: int = -1
## Extra numbers the table reads, e.g. {"face": 6} for Cold Sixes.
@export var params: Dictionary = {}
## Rules with the same non-empty group do the same thing (e.g. Ashmouth and
## Cold Hands: &"no_hot_hand"); a boss never rolls a twist that repeats its cheat.
@export var effect_group: StringName = &""


## The description with "{hands}" filled in from the table's hands.
func text(hands: int) -> String:
	return description.replace("{hands}", str(hands))


## Same rule or same effect as `other` (same id, or same effect_group).
func same_effect(other: RunRuleData) -> bool:
	return other != null and (other.id == id or (effect_group != &"" and other.effect_group == effect_group))

@export_group("Boss sign (optional)")
## Boss intro / pause sign at 600x210 (null = no sign; text panels only).
## Script-built by Art Director (build_signs.py); see BossSign for use.
@export var sign_texture: Texture2D
## The same sign at 1200x420, used when the window is 1080 px tall or more.
@export var sign_texture_2x: Texture2D
## 128 px rule icon for the table HUD row (shown at ~56 px). null = text row.
@export var rule_icon: Texture2D
## The sign's rule line(s), e.g. "Pot at least 3 dice every throw" (HUD tooltip).
## With sign_hand_pill the hands part is added from hands_delta: use sign_tooltip().
@export var tooltip_text: String = ""
## Everything printed on the sign, for screen readers / accessible text.
@export var sign_alt_text: String = ""
## The sign art is pill-free: BossSign draws a "%+d HAND" brass pill from
## hands_delta, and sign_tooltip() / sign_alt() add the hands part.
@export var sign_hand_pill: bool = false


## "-1 HAND" / "+2 HAND" from hands_delta; "" when hands_delta is 0.
func hand_pill_text() -> String:
	return "" if hands_delta == 0 else "%+d HAND" % hands_delta


## The rule tooltip: tooltip_text plus "; -1 hand." from hands_delta
## (sign_hand_pill rules only; otherwise tooltip_text as written).
func sign_tooltip() -> String:
	if not sign_hand_pill:
		return tooltip_text
	if hands_delta == 0:
		return tooltip_text + "."
	return "%s; %+d hand." % [tooltip_text, hands_delta]


## Accessible text for the sign: sign_alt_text plus the pill and tooltip.
func sign_alt() -> String:
	if not sign_hand_pill:
		return sign_alt_text
	var pill := hand_pill_text()
	return "%s%s %s" % [sign_alt_text, (" Pill: %s." % pill) if pill != "" else "", sign_tooltip()]
## HUD: keep the rule's text line visible under the name even with an icon
## (BossSign also does this for any rule that states a Soul / Ember cost).
@export var hud_always_show_line: bool = false
