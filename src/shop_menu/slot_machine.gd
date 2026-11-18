class_name SlotMachine
extends RefCounted
## The slot machine (D-106, D-107): the only way to get perks. One slot ticket (GameState.tickets,
## won by beating a boss in a boss fight: 6 in a full run) = one spin, and every spin wins
## something big:
##   a perk         (data/car_upgrades/perk_*.tres: six, one strong level each, never twice) — half
##   +5 levels      of Damage or Fire rate (mines: Drop rate) on your most upgraded
##                  gun or your second most upgraded gun                                    — half
## The machine itself (ticket, lever, reels, the reveal) is SlotMachineScreen.
## Perks share their half evenly, the gun prizes theirs; if one side has nothing left to give,
## the other side gets all of it.

const GUN_LEVELS := 5
const PERK_SHARE := 0.5


## Every prize the machine can pay right now, with its weight:
## {kind: &"perk", id, weight} or {kind: &"gun", gun, track, rank (1 / 2), weight}.
static func prizes(tree: SceneTree) -> Array[Dictionary]:
	var perks: Array[Dictionary] = []
	for u in CarUpgrades.catalogue():
		if CarUpgrades.is_perk(u) and CarUpgrades.level(u.id) < CarUpgrades.max_level(u):
			perks.append({"kind": &"perk", "id": u.id})
	var guns: Array[Dictionary] = []
	var ranked := ranked_guns(tree)
	for rank in mini(ranked.size(), 2):
		for track: StringName in [&"damage", &"rate"]:
			guns.append({"kind": &"gun", "gun": ranked[rank], "track": track, "rank": rank + 1})
	var perk_share := PERK_SHARE if not guns.is_empty() else 1.0
	if perks.is_empty():
		perk_share = 0.0
	var out: Array[Dictionary] = []
	for p in perks:
		p["weight"] = perk_share / perks.size()
		out.append(p)
	for g in guns:
		g["weight"] = (1.0 - perk_share) / guns.size()
		out.append(g)
	return out


## Owned guns, most upgraded first (ties: the dearer gun first).
static func ranked_guns(tree: SceneTree) -> Array[StringName]:
	var wc := tree.get_first_node_in_group(&"weapon_controller") as WeaponController
	var ids: Array[StringName] = []
	if wc == null:
		return ids
	for w in WeaponController.catalogue():
		if wc.owns(w.id) and w.upgradable:   # never The Devastator (D-107)
			ids.append(w.id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ta := WeaponUpgrades.total(a)
		var tb := WeaponUpgrades.total(b)
		if ta != tb:
			return ta > tb
		return WeaponController._base(a).price > WeaponController._base(b).price)
	return ids


## Spends a ticket and pays a prize. Returns the prize ({} + "error" if it could not spin),
## with "text" (for the shop) and "symbol" (what the reels land on).
static func spin(tree: SceneTree, rng: RandomNumberGenerator) -> Dictionary:
	if GameState.tickets <= 0:
		return {"error": "No slot tickets: beat a boss to win one."}
	var pool := prizes(tree)
	if pool.is_empty():
		return {"error": "The machine has nothing left to give."}
	var roll := rng.randf()
	var prize: Dictionary = pool.back()
	for p in pool:
		roll -= float(p["weight"])
		if roll <= 0.0:
			prize = p
			break
	GameState.add_tickets(-1)
	if prize["kind"] == &"perk":
		CarUpgrades.grant_level(tree, prize["id"])
		var u := CarUpgrades.get_upgrade(prize["id"])
		var lv := CarUpgrades.level(u.id)
		prize["symbol"] = symbol_of(prize)
		prize["title"] = u.display_name.to_upper()
		prize["detail"] = CarUpgrades.effect_text(u, lv)
		prize["text"] = "%s%s: %s" % [prize["title"], " %s" % _roman(lv) if CarUpgrades.max_level(u) > 1 else "", prize["detail"]]
		if u.stat == &"ammo_cap":   # Deep Pockets: won full
			var wc := tree.get_first_node_in_group(&"weapon_controller") as WeaponController
			if wc != null:
				wc.refill_all()
	else:
		var wc := tree.get_first_node_in_group(&"weapon_controller") as WeaponController
		var id: StringName = prize["gun"]
		for i in GUN_LEVELS:
			wc.upgrade(id, prize["track"])   # free: the shop is not involved
		var base := WeaponController._base(id)
		prize["symbol"] = symbol_of(prize)
		prize["title"] = "+%d %s" % [GUN_LEVELS, WeaponUpgrades.track_name(base, prize["track"]).to_upper()]
		prize["detail"] = "on your %s — now %s %d" % [base.display_name.to_upper(),
				WeaponUpgrades.track_name(base, prize["track"]), WeaponUpgrades.level(id, prize["track"])]
		prize["text"] = "+%d %s on your %s (%s %d)" % [GUN_LEVELS, WeaponUpgrades.track_name(base, prize["track"]).to_upper(),
				base.display_name.to_upper(), WeaponUpgrades.track_name(base, prize["track"]),
				WeaponUpgrades.level(id, prize["track"])]
	EventBus.hud_message.emit("SLOTS: %s" % prize["text"], &"good")
	return prize


## The reel symbol of a prize (SYMBOLS key).
static func symbol_of(prize: Dictionary) -> String:
	if prize.get("kind", &"") == &"perk":
		var stat := CarUpgrades.get_upgrade(prize["id"]).stat
		for key: String in SYMBOLS:
			if SYMBOLS[key].get("stat", &"") == stat:
				return key
		return "7"
	return "DMG" if prize.get("track", &"") == &"damage" else "RATE"


## The reel symbols: a short label and a colour each (the perks by their stat, the gun prizes,
## and a lucky 7 that is only ever passed on the way).
const SYMBOLS := {
	"x2": {"label": "x2", "color": Color(1.0, 0.45, 0.2), "stat": &"double_tap"},
	"RLD": {"label": "RLD", "color": Color(0.35, 0.75, 1.0), "stat": &"fast_reload"},
	"TAXI": {"label": "TAXI", "color": Color(1.0, 0.82, 0.1), "stat": &"rolling_pickup"},
	"HP": {"label": "HP+", "color": Color(0.35, 0.9, 0.45), "stat": &"max_hp"},
	"VAMP": {"label": "VAMP", "color": Color(0.85, 0.15, 0.25), "stat": &"lifesteal"},
	"AMMO": {"label": "AMMO", "color": Color(0.75, 0.65, 0.35), "stat": &"ammo_cap"},
	"ANGEL": {"label": "ANGEL", "color": Color(0.55, 0.85, 1.0), "stat": &"guardian_angel"},
	"DMG": {"label": "DMG", "color": Color(1.0, 0.3, 0.3)},
	"RATE": {"label": "RATE", "color": Color(0.8, 0.5, 1.0)},
	"7": {"label": "7", "color": Color(1.0, 0.15, 0.15)},
}
## The order the symbols sit on every reel strip.
const REEL_SYMBOLS: Array[String] = ["7", "x2", "DMG", "HP", "RLD", "ANGEL", "RATE", "VAMP", "TAXI", "AMMO"]


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
