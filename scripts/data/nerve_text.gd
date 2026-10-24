## Nerve's player-facing text (design/strings_v1.md, block "nerve_v1",
## approved Oct 20). Text only, looked up by the strings_v1 id:
##   NerveText.get_text("nerve_spent") -> "Nerve spent for this table."
## NerveState.refusal() returns these ids; the table shows the text.
class_name NerveText
extends RefCounted

## strings_v1 id -> text (copied verbatim; check_strings.py owns the source).
const TEXT: Dictionary[String, String] = {
	"nerve_button": "Nerve",
	"nerve_tooltip": "Once per table, turn one die up or down one face.",
	"nerve_pick": "Pick a die, then tap up or down.",
	"nerve_ready": "Nerve ready: 1 per table.",
	"nerve_spent": "Nerve spent for this table.",
	"nerve_undo": "Tap Nerve (or Backspace) to undo before you pot.",
	"nerve_used_refusal": "Nerve is already used this table.",
	"nerve_high_refusal": "This die can't go higher.",
	"nerve_low_refusal": "This die can't go lower.",
	"nerve_copy_refusal": "Copy dice follow other dice; turn the die they copy.",
	"nerve_potted_refusal": "Potted dice are locked; turn a die still on the felt.",
	"nerve_bust_save": "Nothing lit: use Nerve to save the hand, or bust.",
	"HN1": "Nothing lit, but Nerve can turn one die to save it.",
	"HN2": "Nerve resets each table: save it for a bounty or a bust.",
	"glossary_nerve": "Once per table, turn one unpotted die one face up or down.",
}


## The text for strings_v1 id [param id] ("" if unknown or empty: then
## nothing is shown).
static func get_text(id: String) -> String:
	return TEXT.get(id, "")

