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
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TWIST
## Added to the table's hands (Short Table: 5 -> 4 is -1).
@export var hands_delta: int = 0
## Soul a bust costs at this table; -1 = the normal value (Heavy Toll: 3).
@export var bust_soul_loss: int = -1
## Extra numbers the table reads, e.g. {"face": 6} for Cold Sixes.
@export var params: Dictionary = {}

@export_group("Boss sign (optional)")
## Boss intro / pause sign at 600x210 (null = no sign; text panels only).
## Script-built by Art Director (build_signs.py); see BossSign for use.
@export var sign_texture: Texture2D
## The same sign at 1200x420, used when the window is 1080 px tall or more.
@export var sign_texture_2x: Texture2D
## 128 px rule icon for the table HUD row (shown at ~56 px). null = text row.
@export var rule_icon: Texture2D
## The sign's rule line(s), e.g. "POT 3+ DICE EVERY THROW" (HUD tooltip).
@export var tooltip_text: String = ""
## Everything printed on the sign, for screen readers / accessible text.
@export var sign_alt_text: String = ""
## HUD: keep the rule's text line visible under the name even with an icon
## (BossSign also does this for any rule that states a Soul / Ember cost).
@export var hud_always_show_line: bool = false
