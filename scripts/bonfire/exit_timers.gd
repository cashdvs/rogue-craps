## A small list of SceneTreeTimers that can all be unhooked at once.
## Use it in a node that starts timers and might leave the tree before they
## fire: make timers with start(), then call stop_all() from _exit_tree().
## After stop_all(), nothing connected to (or awaiting) those timers runs.
class_name ExitTimers
extends RefCounted

## Timers that may still be running (finished ones are dropped on start()).
var live: Array[SceneTreeTimer] = []


## Same as node.get_tree().create_timer(...), but remembered here.
func start(node: Node, seconds: float, process_always: bool = true, process_in_physics: bool = false, ignore_time_scale: bool = false) -> SceneTreeTimer:
	var t := node.get_tree().create_timer(seconds, process_always, process_in_physics, ignore_time_scale)
	live = live.filter(func(old: SceneTreeTimer) -> bool: return old.time_left > 0.0)
	live.append(t)
	return t


## Unhooks every remembered timer: its timeout reaches nobody any more.
func stop_all() -> void:
	for t in live:
		for c in t.timeout.get_connections():
			t.timeout.disconnect(c.callable)
	live.clear()
