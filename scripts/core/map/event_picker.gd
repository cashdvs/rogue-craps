## Which event an Event node opens (events §2, Game Designer rules of Oct 19):
## only events tagged for this floor (EventData.floors, empty = every floor),
## never one where only Leave would be enabled, unseen ones first. Pure
## logic and seeded: the same RNG gives the same event.
class_name EventPicker
extends RefCounted

const NT := MapGenData.NodeType


## Can event `e` appear on floor `floor_number` (1-based)?
static func on_floor(e: EventData, floor_number: int) -> bool:
	return e != null and (e.floors.is_empty() or e.floors.has(floor_number))


## A choice with no effects is the event's "Leave".
static func is_leave(c: EventChoiceData) -> bool:
	return c.effects.is_empty()


## True when at least one non-Leave choice is enabled, using the same check
## the event screen greys choices with (EventApplier.why_not).
static func worth_offering(e: EventData, p: RunProgress, table_ahead: bool) -> bool:
	for c in e.choices:
		if not is_leave(c) and not EventApplier.is_hidden(c, p) and EventApplier.why_not(c, p, table_ahead) == "":
			return true
	return false


## Pick an event: unseen floor events first, then any floor event (the seen
## list is cleared when that happens); events with only Leave enabled are
## skipped. Draws in the RNG's order, so it's deterministic. Returns null if
## nothing on this floor is worth offering (the caller opens a non-event
## node instead). Appends the pick to `seen`.
static func pick(events: Array[EventData], seen: Array[StringName], floor_number: int,
		p: RunProgress, table_ahead: bool, rng: RandomNumberGenerator) -> EventData:
	var unseen: Array[EventData] = []
	var all: Array[EventData] = []
	for e in events:
		if on_floor(e, floor_number):
			all.append(e)
			if not seen.has(e.id):
				unseen.append(e)
	var e := _draw(unseen, p, table_ahead, rng)
	if e == null:
		e = _draw(all, p, table_ahead, rng)
		if e != null:
			seen.clear()
	if e != null:
		seen.append(e.id)
	return e


static func _draw(pool: Array[EventData], p: RunProgress, table_ahead: bool,
		rng: RandomNumberGenerator) -> EventData:
	var left := pool.duplicate()
	while not left.is_empty():
		var e: EventData = left.pop_at(rng.randi_range(0, left.size() - 1))
		if worth_offering(e, p, table_ahead):
			return e
	return null


## Is a regular Table still ahead on this floor (reachable from where you
## stand, so not yet played)? Before the first move, the whole map counts.
static func table_ahead(map: RunMap) -> bool:
	if map == null:
		return false
	var stack: Array[int] = map.reachable()
	var seen: Dictionary = {}
	while not stack.is_empty():
		var id: int = stack.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		var n := map.node(id)
		if n == null:
			continue
		if n.type == NT.TABLE:
			return true
		stack.append_array(n.next)
	return false
