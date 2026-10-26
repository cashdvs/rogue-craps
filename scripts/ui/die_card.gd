## One die's card, built in code: "name  -  ability", the next mod's price
## (when DieCardInfo.next_mod_price >= 0) and a button per face showing its
## value and mod, with "Face n: mod" tooltips. Read-only cards disable every
## face (tooltips kept); otherwise `allowed` decides which faces can be
## picked. View only: emits face_picked(face_index).
class_name DieCard
extends VBoxContainer

signal face_picked(face_index: int)

const NEXT_MOD := "Next mod on this die: %d Embers."
const TAKEN := "This face already has a face mod."
## strings_v1 rare_carved_locked: a rare die's pre-carved face (rare_dice_v1 §3).
const LOCKED := EconomyStrings.RARE_CARVED_LOCKED
const FACE_SIZE := Vector2(92, 40)
## Greys a refused-but-tappable face (a rare's locked face) like a disabled one.
const REFUSED_TINT := Color(1, 1, 1, 0.5)

var info: DieCardInfo


## A new card showing `card_info` (see set_die).
static func create(card_info: DieCardInfo, read_only: bool = true) -> DieCard:
	var c := DieCard.new()
	c.set_die(card_info, read_only)
	return c


## Show `card_info`. read_only: faces are disabled. Otherwise
## allowed (Callable(face_index) -> bool; invalid = every face) enables
## faces, and a disabled face that carries a mod adds the TAKEN line. A
## rare's locked face stays tappable (greyed): a tap shows LOCKED via refuse().
func set_die(card_info: DieCardInfo, read_only: bool = true, allowed: Callable = Callable()) -> void:
	info = card_info
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_child(RunTheme.label("%s  -  %s" % [info.display_name, info.ability], 18))
	if info.next_mod_price >= 0:
		add_child(RunTheme.label(NEXT_MOD % info.next_mod_price, 18, RunTheme.GOLD))
	var row := HBoxContainer.new()
	for f in info.faces.size():
		var face: Dictionary = info.faces[f]
		var value: int = int(face.get("value", f + 1))
		var mod: StringName = face.get("mod", &"")
		var mod_name: String = face.get("mod_name", "")
		var b := RunTheme.button(str(value) if mod == &"" else "%d %s" % [value, mod_name], 16)
		b.custom_minimum_size = FACE_SIZE
		b.tooltip_text = "Face %d: %s" % [value, mod_name if mod != &"" else "Plain face."]
		if read_only:
			b.disabled = true
		else:
			b.disabled = allowed.is_valid() and not bool(allowed.call(f))
			if b.disabled and bool(face.get("locked", false)):
				# Tappable (no hover on phones): a tap refuses and says why.
				b.disabled = false
				b.modulate = REFUSED_TINT
				b.tooltip_text += "\n" + LOCKED
				b.pressed.connect(func() -> void: refuse(LOCKED))
			else:
				if b.disabled and mod != &"" and mod != RunDie.BLANK:
					b.tooltip_text += "\n" + TAKEN
				b.pressed.connect(func() -> void: face_picked.emit(f))
		row.add_child(b)
	add_child(row)


## Show `text` on the card (one line, replaced on the next refusal): why a
## tapped face can't be carved. No face_picked.
func refuse(text: String) -> void:
	var l := get_node_or_null("Refused") as Label
	if l == null:
		l = RunTheme.label(text, 16, RunTheme.GOLD)
		l.name = "Refused"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)
	l.text = text
