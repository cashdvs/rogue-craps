## A running total of single-die throws that the player can stop at any time.
##
## Groundwork for the new core loop (Burn Line, spec pending): you throw one
## die at a time into a running total and decide when to stop. This class
## only keeps the numbers; how a stop pays (exactly on the line, close, or
## over) is NOT decided here yet. It waits for the spec.
## Pure logic (no nodes), so it can be tested headless.
class_name RunningTotal
extends RefCounted

## The total changed: `added` is the value just thrown (0 on reset).
signal total_changed(total: int, added: int)
## The player stopped; `total` is the final total, `throws` the history.
signal stopped(total: int, throws: Array[Dictionary])

## The marker the player aims at (placeholder until the spec sets it).
var target_line: int = 21
## Current total.
var total: int = 0
## Every throw so far: {"value": int, "die": String (die name)}.
var throws: Array[Dictionary] = []


func _init(line: int = 21) -> void:
	target_line = line


## Adds one thrown die's value. Returns the new total.
func add(value: int, die_name: String = "Die") -> int:
	total += value
	throws.append({"value": value, "die": die_name})
	total_changed.emit(total, value)
	return total


## How many dice have been thrown into this total.
func count() -> int:
	return throws.size()


## Signed distance to the line: negative = under, 0 = exactly on, positive = over.
func distance_to_line() -> int:
	return total - target_line


func is_over_line() -> bool:
	return total > target_line


## Ends this total: emits `stopped` and starts a new one. Returns the final
## total (0 and no signal if nothing was thrown yet).
func stop() -> int:
	if throws.is_empty():
		return 0
	var final_total := total
	var history := throws.duplicate()
	reset()
	stopped.emit(final_total, history)
	return final_total


func reset() -> void:
	total = 0
	throws.clear()
	total_changed.emit(0, 0)
