## What one simulated throw looked like: every die's transform at every
## physics tick, plus the collisions (for sounds), and which faces ended up
## on top. Played back by Table3D at normal speed after the fast simulation.
class_name ThrowRecording
extends RefCounted

## Any number of dice (1 for a single-die throw). Call init(n) first.
## Seconds between frames (1 / physics ticks per second of the simulation).
var dt: float = 1.0 / 120.0
## frames[die] = Array of Transform3D, one per tick, starting at release.
var frames: Array = []
## {"t": s, "die": int, "kind": &"felt"|&"rail"|&"backboard"|&"die"|&"chip"|&"puck",
##  "speed": relative contact speed m/s, "impulse": N*s, "other": other die id or -1}
var contacts: Array[Dictionary] = []
## When each die physically came to rest (s into the recording).
var rest_t: Array[float] = []
## When each die's spin first dropped under tuning.tumble_end_rad_s, and how fast it was.
var tumble_end_t: Array[float] = []
var tumble_end_speed: Array[float] = []
## Physical top face of each die at rest (before the face remap).
var up_values: Array[int] = []
## Did all dice really come to rest (false = timed out and were damped)?
var settled: bool = false
## Did the settle assist fire (a die still moving at assist_start)?
var assisted: bool = false
## How many dice the assist actually eased.
var assisted_dice: int = 0
## How many small nudges un-cocked a die leaning on the rail.
var nudges: int = 0
## Coin nudges that found it standing on its edge (CoinPhysics.EDGE_DEG).
var edge_nudges: int = 0
## Per die: a coin's tilt off flat (deg) when the sim stopped, before the
## final lay-flat (0 for cubes). Near 90 would mean it rested on its edge.
var rest_tilt_deg: Array[float] = []
## Per die: still moving when the settle assist took over (it was then
## eased flat, not at rest where it was).
var end_moving: Array[bool] = []
## Tests only (DiceSim.post_rest_watch): per die, the largest linear /
## angular speed after it had settled, and how often it started moving again.
var post_rest_max_lin: Array[float] = []
var post_rest_max_ang: Array[float] = []
var post_rest_restarts: Array[int] = []


## Sizes every per-die array for `n` dice.
func init(n: int) -> void:
	frames = []
	rest_t = []
	tumble_end_t = []
	tumble_end_speed = []
	up_values = []
	rest_tilt_deg = []
	end_moving = []
	post_rest_max_lin = []
	post_rest_max_ang = []
	post_rest_restarts = []
	for i in n:
		rest_tilt_deg.append(0.0)
		end_moving.append(false)
		post_rest_max_lin.append(0.0)
		post_rest_max_ang.append(0.0)
		post_rest_restarts.append(0)
		frames.append([])
		rest_t.append(-1.0)
		tumble_end_t.append(-1.0)
		tumble_end_speed.append(0.0)
		up_values.append(1)


## How many dice this throw had.
func count() -> int:
	return frames.size()


func duration() -> float:
	if frames.is_empty():
		return 0.0
	return maxf(float((frames[0] as Array).size() - 1), 0.0) * dt


## The die's transform at time t (smoothly between the recorded ticks).
func sample(die: int, t: float) -> Transform3D:
	var f := frames[die] as Array
	if f.is_empty():
		return Transform3D.IDENTITY
	var x := clampf(t / dt, 0.0, float(f.size() - 1))
	var i := int(floor(x))
	var j := mini(i + 1, f.size() - 1)
	var a := f[i] as Transform3D
	var b := f[j] as Transform3D
	return a.interpolate_with(b, x - float(i))


func final_transform(die: int) -> Transform3D:
	var f := frames[die] as Array
	return f[f.size() - 1] as Transform3D
