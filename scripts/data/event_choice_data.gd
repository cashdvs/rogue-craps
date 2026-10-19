## One choice on an event screen: its button text, the effects it applies
## in order, and the line shown after picking it. A choice whose costs you
## can't pay, or that needs a face mod you don't have, is greyed out
## (EventApplier.can_choose).
class_name EventChoiceData
extends Resource

@export var label: String = ""
@export_multiline var result_text: String = ""
@export var effects: Array[EventEffectData] = []
## Needs at least one carved face mod (Altar, Ember Merchant).
@export var requires_face_mod: bool = false
