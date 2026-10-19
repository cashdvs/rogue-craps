## Pure numbers for the Bonfire scoring juice (bonfire_map_events_juice.md
## section 3): score tier, banner tier and the count-up timeline, all from
## BonfireTuning "Juice". Tests use it directly.
class_name JuicePlan
extends RefCounted

## Banner colours per tier: face, shade, ink, glow (3D Artist's palette,
## art/vfx/bonfire/README.md "Combo banner palette").
const BANNER_COLORS: Array = [
	[Color("#E8DCC0"), Color("#BFAF8E"), Color("#0E1414"), Color("#FFE2B0")],
	[Color("#E8622A"), Color("#A8401A"), Color("#0E1414"), Color("#F6A845")],
	[Color("#C8281E"), Color("#6E1A24"), Color("#0E1414"), Color("#E8622A")],
	[Color("#0E1414"), Color("#B08D3C"), Color("#E2C06A"), Color("#E2C06A")],
]
## Banner text colour per tier (Pit Black on bone / ember, Bone on hellfire,
## Brass hi on black-gold).
const BANNER_TEXT: Array[Color] = [Color("#0E1414"), Color("#0E1414"), Color("#E8DCC0"), Color("#E2C06A")]
const TIER_NAMES: Array[StringName] = [&"sparks", &"flames", &"inferno", &"pillar"]


## 0 sparks (< 100), 1 flames (100-299), 2 inferno (300-999), 3 pillar (1000+).
static func tier(points: int, t: BonfireTuning) -> int:
	var k := 0
	for th in t.juice_tier_thresholds:
		if points >= th:
			k += 1
	return k


static func banner_tier(combo: StringName, t: BonfireTuning) -> int:
	return int(t.juice_banner_tiers.get(combo, 0))


static func is_big(score_tier: int) -> bool:
	return score_tier >= 3


## The count-up beats in seconds from the start (real time).
## pips: one per counted value; chips: extra Mult chips after the first.
## speed_mode: 0 = 1x, 1 = 2x, 2 = Instant (everything at 0).
## {pips: Array[float], slam, chips: Array[float], sweep, count_start,
##  count_end, banner, end, cap, big}
static func timeline(n_pips: int, n_extra_chips: int, score_tier: int, speed_mode: int, t: BonfireTuning) -> Dictionary:
	var big := is_big(score_tier)
	var gap := t.juice_pip_gap_big if big else t.juice_pip_gap
	var pips: Array[float] = []
	for i in n_pips:
		pips.append(i * gap)
	var slam := n_pips * gap
	var chips: Array[float] = []
	for k in n_extra_chips:
		chips.append(slam + t.juice_slam_time * 0.5 + (k + 1) * t.juice_chip_gap)
	var sweep := slam + t.juice_slam_time + n_extra_chips * t.juice_chip_gap
	var count_start := sweep + t.juice_sweep_time
	var count_end := count_start + (t.juice_count_time_big if big else t.juice_count_time)
	var banner := count_end
	var end := banner + (t.juice_banner_hold_big if big else t.juice_banner_hold)
	var cap := t.juice_cap_big if big else t.juice_cap
	var k := 1.0
	if end > cap:
		k = cap / end
	if speed_mode == 1:
		k *= 0.5
	elif speed_mode >= 2:
		k = 0.0
	for i in pips.size():
		pips[i] *= k
	for i in chips.size():
		chips[i] *= k
	return {"pips": pips, "slam": slam * k, "chips": chips, "sweep": sweep * k, "count_start": count_start * k,
		"count_end": count_end * k, "banner": banner * k, "end": end * k, "cap": cap, "big": big}


## The Mult chips of a pot: the combo's mult (with face adds), one per Hot
## Hand (+bonus each), and the mod factor (Hellfire etc.) if not 1.
## [{text, kind: &"mult" / &"hot" / &"factor"}]
static func chips(result: Dictionary, hot_hands: int, per_hot: int) -> Array:
	var out: Array = []
	var hot_total := hot_hands * per_hot
	out.append({"text": "x%d" % (int(result.get("mult", 0)) - hot_total), "kind": &"mult"})
	for k in hot_hands:
		out.append({"text": "+%d HOT" % per_hot, "kind": &"hot"})
	var f := float(result.get("factor", 1.0))
	if not is_equal_approx(f, 1.0):
		out.append({"text": "x%s" % str(snappedf(f, 0.01)), "kind": &"factor"})
	return out
