## One thing for sale on the shop counter (HANDOFF_SPEC §5): a die, face mod,
## Seal, rare Seal or the Soul Draught, as plain data read from MapRun so the
## counter (and PR B's card) can draw it without knowing the shop rules.
class_name ShopOffer
extends RefCounted

enum Kind { DIE, MOD, SEAL, RARE_SEAL, SOUL }

var kind: Kind
## Slot index in run.shop_dice / shop_mods / shop_seals (0 for the others).
var index: int = 0
## The die / mod / combo id (the Draught uses &"soul").
var id: StringName = &""
var display_name: String = ""
## Art key, from data only: a die's model body (DiceIds.body_key, so rare dice
## use stand-in bodies until their .glb lands), else mod_/seal_<id> or soul.
var art_key: StringName = &""
## Rare dice (SpecialDieData.rarity) and the rare Seal; PR D draws the chip.
var rare: bool = false
## Lowest and highest price. They differ only for mods (the price depends
## on which die you carve). -1 = can't be bought now (no free face).
var price_lo: int = 0
var price_hi: int = 0


## True when you hold enough Embers for the cheapest price.
func affordable(embers: int) -> bool:
	return price_lo >= 0 and embers >= price_lo


## The price tag text: "18", a mod range "8-12", or "-" when no die has a
## free face for a mod.
func price_text() -> String:
	if price_lo < 0:
		return "-"
	return str(price_lo) if price_lo == price_hi else "%d-%d" % [price_lo, price_hi]


static func _make(kind: Kind, index: int, id: StringName, name: String, art: StringName, lo: int, hi: int = -2) -> ShopOffer:
	var o := ShopOffer.new()
	o.kind = kind; o.index = index; o.id = id; o.display_name = name; o.art_key = art
	o.price_lo = lo
	o.price_hi = lo if hi == -2 else hi  # One price unless a range is given.
	return o


## Every offer on the counter, in shelf order: dice, Soul Draught, mods,
## Seals, the rare Seal. Bought (empty) slots are skipped.
static func list(run: MapRun) -> Array[ShopOffer]:
	var out: Array[ShopOffer] = []
	for i in run.shop_dice.size():
		var d := run.shop_dice[i]
		if d != null:
			var o := _make(Kind.DIE, i, d.id, d.display_name, DiceIds.body_key(d.id), run.die_price(i))
			o.rare = d.is_rare()
			out.append(o)
	if run.data.shop_soul_amount > 0:
		out.append(_make(Kind.SOUL, 0, &"soul", EconomyStrings.shop_soul_button(run.data.shop_soul_amount, run.soul_price()),
			&"soul", run.soul_price()))
	for i in run.shop_mods.size():
		var m := run.shop_mods[i]
		if m != null:
			var r := run.mod_price_range(i)
			out.append(_make(Kind.MOD, i, m.id, m.display_name, StringName("mod_%s" % m.id), r.x, r.y))
	for i in run.shop_seals.size():
		var s := run.shop_seals[i]
		if s != &"":
			out.append(_make(Kind.SEAL, i, s, "%s Seal" % String(s).capitalize(), StringName("seal_%s" % s), run.seal_price(s)))
	if run.shop_premium_seal != &"":
		var s := run.shop_premium_seal
		var o := _make(Kind.RARE_SEAL, 0, s, String(s).capitalize(), StringName("seal_%s" % s), run.premium_seal_price())
		o.rare = true
		out.append(o)
	return out


## Click-to-buy (PR A): the same MapRunShop calls the old text shop used.
## Dice and the Draught buy at once; a mod opens the face picker and a Seal
## that needs a choice opens its picker first. `screen` refreshes after.
func buy(screen: RunScreen) -> void:
	var run := screen.run
	match kind:
		Kind.DIE:
			run.buy_die(index)
		Kind.SOUL:
			run.buy_soul()
		Kind.MOD:
			if not affordable(run.progress.embers):
				return
			var m := run.shop_mods[index]
			screen._pick("Pick a face for the %s" % m.display_name, func(at: Vector2i) -> void: run.buy_mod(index, at); screen.refresh(),
				func(at: Vector2i) -> bool: return run.can_buy_mod_at(index, at),
				func(d: int) -> int: return run.shop_mod_price(m, d))
			return
		Kind.SEAL, Kind.RARE_SEAL:
			if not affordable(run.progress.embers) or not screen._seal_possible(id):
				return
			var i := index
			var premium := kind == Kind.RARE_SEAL
			screen._seal_with_params(id, func(params: Dictionary) -> bool:
				var ok := run.buy_premium_seal(params) if premium else run.buy_seal(i, params)
				screen.refresh()
				return ok)
			return
	screen.refresh()
