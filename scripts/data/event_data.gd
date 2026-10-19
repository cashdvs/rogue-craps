## A random event (events §2): title, body text, an art slot with the art
## note for the artist, and 2-3 choices. resources/events/*.tres.
class_name EventData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var body: String = ""
## Shown in the art slot; null = the placeholder panel with art_note on it.
@export var art: Texture2D
## What the art should show (Game Designer's note for the 3D Artist).
@export var art_note: String = ""
@export var choices: Array[EventChoiceData] = []
