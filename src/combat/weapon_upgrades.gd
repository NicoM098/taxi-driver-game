class_name WeaponUpgrades
extends RefCounted
## Weapon progression: unlocking by rides delivered (D-085) and the endless stat tracks (D-093).
##
## The .tres in data/weapons/ is always the gun as bought. `apply()` returns an upgraded COPY,
## which is what WeaponController fires; the shop and the hotbar keep reading the base resource.
##
## Four tracks per gun, each bought on its own (GameState.weapon_levels[id][track]):
##   mag     magazine +25 % of the base per level           — 3 levels, then maxed
##   reserve spare ammo +40 % of the base per level         — 3 levels, then maxed
##   damage  damage, ENDLESS: +10 % a level for levels 1-3, +15 % for 4-6, +20 % for 7-9 ...
##   rate    fire rate, ENDLESS: +6 % for 1-3, +9 % for 4-6, +12 % for 7-9 ...
## The steps compound. Prices grow x1.35 a level on the endless tracks, so every new level costs
## more per percent than the last: one gun only stays on top if the money keeps going into it.
## Past RATE_CAP_MULT x its base fire rate (or 30 shots/s) the extra fire rate turns into damage,
## so the DPS keeps the curve without a rocket launcher becoming a machine gun.
## The gun's special (WeaponData.special) is a milestone: SPECIAL_AT upgrades bought, any tracks.
##
## Mines have their own four (D-099, user: "different path upgrade, no reloads and only max
## ammo"): they never reload (one pool, WeaponData.reloads), so instead of Mag and Ammo:
##   capacity  mines carried, +25 % of the base per level  — 4 levels
##   blast     blast radius +15 % per level                 — 3 levels
##   damage    as above, endless
##   rate      "Drop rate": how fast they roll out the back, endless
##
## The other half (D-093): enemy health follows the same curve. `enemy_hp_mult()` is how much
## stronger a gun would be if SCALING_SHARE of every dollar earned this run had gone into its
## damage and fire rate, x ENEMY_HP_SCALE. A gun you pour your money into keeps (since D-095:
## slightly beats) its time-to-kill; spend elsewhere (other guns, the cab) and it falls behind.

const TRACKS: Array[StringName] = [&"mag", &"reserve", &"damage", &"rate"]
const MINE_TRACKS: Array[StringName] = [&"capacity", &"damage", &"blast", &"rate"]
const TRACK_NAME := {&"mag": "Mag", &"reserve": "Ammo", &"damage": "Damage", &"rate": "Fire rate",
		&"capacity": "Capacity", &"blast": "Blast"}
## Levels of the capped tracks. The others never end.
const CAP := {&"mag": 3, &"reserve": 3, &"capacity": 4, &"blast": 3}
const MAG_STEP := 0.25
const AMMO_STEP := 0.4
const CAPACITY_STEP := 0.25
const BLAST_STEP := 0.15
## Endless tracks: step of level n = BASE + RISE x floor((n - 1) / LEVELS_PER_TIER).
const DAMAGE_STEP := 0.10
const DAMAGE_RISE := 0.05
const RATE_STEP := 0.06
const RATE_RISE := 0.03
const LEVELS_PER_TIER := 3
## Fire rate never goes past min(base x RATE_CAP_MULT, max(RATE_CAP, base)); the rest becomes damage.
const RATE_CAP_MULT := 3.0
const RATE_CAP := 30.0

## Prices: WeaponData.upgrade_cost x share x growth^(levels already bought on that track).
const PRICE_SHARE := {&"mag": 0.6, &"reserve": 0.5, &"damage": 1.0, &"rate": 1.1, &"capacity": 0.6, &"blast": 0.8}
const PRICE_GROWTH := 1.35
const CAPPED_GROWTH := 1.6

## Upgrades bought (any tracks) before the gun's special switches on.
const SPECIAL_AT := 8
const DEADEYE_MULT := 2.0          # revolver: aimed shots
const DRUM_MAG := 75               # SMG
const DRUM_RESERVE_MULT := 2.0
const BURN_DPS := 9.0              # sawed-off: per second, per target, x the gun's damage upgrades
const BURN_TIME := 4.0
const PIERCE_TARGETS := 3          # rifle, laser: cars one shot can go through
const BIG_BLAST_MULT := 1.6        # mines

## Enemy health scaling (D-093). Off = enemies keep their .tres health.
static var scale_enemies: bool = true
## Share of the run's earnings the curve follows. Was 0.75 (keep pace, D-093), 0.8 (fares x1.5, D-095);
## 0.35 since D-096 (fares x2.5, bounties x2, user: "it would feel more rewarding if my guns were
## overpowered"): a gun with 40 % of the money is ~1.25-1.45x the enemies, all in 1.4-3x; a gun
## with nothing in it still falls behind.
const SCALING_SHARE := 0.35
## The gun the curve is priced on. The guns' own WeaponData.upgrade_cost is 10 % lower (225, D-095),
## so a gun with all the money in it now pulls ahead of the enemies instead of just keeping pace.
const REFERENCE_COST := 250
## Every enemy's health is multiplied by this on top of the curve (D-095 0.9, D-096 0.85).
const ENEMY_HP_SCALE := 0.85


# --- Levels -----------------------------------------------------------------------------

## The four tracks gun `base` is upgraded on (mines: MINE_TRACKS, D-099).
static func tracks_for(base: WeaponData) -> Array[StringName]:
	if base != null and not base.upgradable:
		return [] as Array[StringName]   # The Devastator (D-107)
	return MINE_TRACKS if base != null and base.kind == &"mine" else TRACKS


## Button name of a track on gun `base` ("Drop rate" for the mines' fire rate).
static func track_name(base: WeaponData, track: StringName) -> String:
	if track == &"rate" and base != null and base.kind == &"mine":
		return "Drop rate"
	return TRACK_NAME.get(track, String(track))


## Levels bought on `track` of gun `id` (0 = as bought).
static func level(id: StringName, track: StringName) -> int:
	var lv: Dictionary = GameState.weapon_levels.get(id, {})
	return int(lv.get(track, 0))


## Every level bought on gun `id`, all tracks together.
static func total(id: StringName) -> int:
	var n := 0
	for t in TRACKS:
		n += level(id, t)
	return n


static func is_capped(track: StringName, lv: int) -> bool:
	return CAP.has(track) and lv >= int(CAP[track])


## Hotbar / shop tag: "+N" upgrades, empty when none.
static func level_name(id: StringName) -> String:
	var n := total(id)
	return "+%d" % n if n > 0 else ""


# --- Stats ------------------------------------------------------------------------------

## The increment of the `n`-th level (1-based) of an endless track: 0.10 = +10 %.
static func step(track: StringName, n: int) -> float:
	var tier := float((maxi(n, 1) - 1) / LEVELS_PER_TIER)
	match track:
		&"damage":
			return DAMAGE_STEP + DAMAGE_RISE * tier
		&"rate":
			return RATE_STEP + RATE_RISE * tier
		&"mag":
			return MAG_STEP
		&"reserve":
			return AMMO_STEP
		&"capacity":
			return CAPACITY_STEP
		&"blast":
			return BLAST_STEP
	return 0.0


## Multiplier of `lv` levels of an endless track (the steps compound).
static func mult(track: StringName, lv: int) -> float:
	var m := 1.0
	for n in range(1, lv + 1):
		m *= 1.0 + step(track, n)
	return m


## Fire rate ceiling of a gun.
static func rate_cap(base: WeaponData) -> float:
	return minf(base.fire_rate * RATE_CAP_MULT, maxf(RATE_CAP, base.fire_rate))


## The gun with the levels of gun `base.id` in GameState, as a new resource (base untouched).
static func apply(base: WeaponData) -> WeaponData:
	var w := base.duplicate() as WeaponData
	if not base.upgradable:
		return w   # untouched by levels and perks alike (D-107)
	var rate_m := mult(&"rate", level(base.id, &"rate"))
	w.fire_rate = minf(base.fire_rate * rate_m, rate_cap(base))
	var overflow := base.fire_rate * rate_m / w.fire_rate   # fire rate past the cap -> damage
	w.damage = base.damage * mult(&"damage", level(base.id, &"damage")) * overflow
	w.mag_size = ceili(base.mag_size * (1.0 + MAG_STEP * level(base.id, &"mag")) - 0.001)
	w.reserve_max = roundi(base.reserve_max * (1.0 + AMMO_STEP * level(base.id, &"reserve")))
	if not base.reloads():   # the mines (D-099): one pool, bigger with Capacity
		w.mag_size = capacity_at(base, level(base.id, &"capacity"))
	w.blast_radius = base.blast_radius * (1.0 + BLAST_STEP * level(base.id, &"blast"))
	if total(base.id) >= SPECIAL_AT:
		match base.special:
			&"drum":
				w.mag_size = maxi(DRUM_MAG, w.mag_size)
				w.reserve_max = roundi(w.reserve_max * DRUM_RESERVE_MULT)
			&"big_blast":
				w.blast_radius *= BIG_BLAST_MULT
			&"no_spinup":
				w.spin_up = 0.0
	# Perks (D-100) last, on top of every cap: Double Tap goes past the fire-rate ceiling.
	w.fire_rate *= CarUpgrades.fire_rate_mult()
	w.reload_time = base.reload_time * CarUpgrades.reload_mult()
	var pockets := CarUpgrades.value(&"ammo_cap")   # Deep Pockets (D-107)
	if pockets > 0.0:
		if w.reloads():
			w.reserve_max = roundi(w.reserve_max * (1.0 + pockets))
		else:
			w.mag_size = ceili(w.mag_size * (1.0 + pockets) - 0.001)
	return w


## Mines carried by a no-reload gun with `lv` Capacity levels.
static func capacity_at(base: WeaponData, lv: int) -> int:
	return ceili(base.mag_size * (1.0 + CAPACITY_STEP * lv) - 0.001)


## How much of the gun's damage comes from upgrades (1 = none). For effects that scale with
## it, like dragon's breath.
static func damage_scale(w: WeaponData, base: WeaponData) -> float:
	return w.damage / base.damage if base != null and base.damage > 0.0 else 1.0


## Whether the run's weapon `w` has its special.
static func has_special(w: WeaponData, special: StringName) -> bool:
	return w != null and w.special == special and total(w.id) >= SPECIAL_AT


## Upgrades left before the special of gun `id` (0 = it has it).
static func special_in(id: StringName) -> int:
	return maxi(SPECIAL_AT - total(id), 0)


# --- Prices -----------------------------------------------------------------------------

## Price of the next level of `track` when `lv` are bought, or -1 if the track is maxed.
static func price_at(cost: float, track: StringName, lv: int) -> int:
	if is_capped(track, lv):
		return -1
	var growth := CAPPED_GROWTH if CAP.has(track) else PRICE_GROWTH
	var p := cost * float(PRICE_SHARE[track]) * pow(growth, lv)
	return maxi(roundi(p / 5.0) * 5, 5)


static func next_price(base: WeaponData, track: StringName) -> int:
	return price_at(base.upgrade_cost, track, level(base.id, track))


## Short text for a track button / card: what the next level gives.
static func describe_next(base: WeaponData, track: StringName) -> String:
	var lv := level(base.id, track)
	if is_capped(track, lv):
		return "maxed"
	var n := lv + 1
	match track:
		&"mag":
			return "+%d rounds" % (ceili(base.mag_size * (1.0 + MAG_STEP * n) - 0.001)
					- ceili(base.mag_size * (1.0 + MAG_STEP * lv) - 0.001))
		&"reserve":
			return "+%d spare" % (roundi(base.reserve_max * (1.0 + AMMO_STEP * n))
					- roundi(base.reserve_max * (1.0 + AMMO_STEP * lv)))
		&"capacity":
			return "+%d mines" % (capacity_at(base, n) - capacity_at(base, lv))
		&"blast":
			return "+%d%% radius" % roundi(BLAST_STEP * 100.0)
		&"rate":
			var now := base.fire_rate * mult(&"rate", lv)
			if now >= rate_cap(base) - 0.001:
				return "+%d%% as dmg" % roundi(step(track, n) * 100.0)
	return "+%d%%" % roundi(step(track, n) * 100.0)


## The levels at which the next endless step gets bigger (for the shop: "next tier at 7").
static func next_tier_at(lv: int) -> int:
	return (lv / LEVELS_PER_TIER + 1) * LEVELS_PER_TIER + 1


# --- Enemy scaling (D-093) --------------------------------------------------------------

## DPS multiplier a gun priced at `cost` reaches if `budget` dollars all go into its damage and
## fire rate, cheapest level first. The last level is counted in part, so the curve is smooth.
static func dedicated_power(budget: float, cost: float = REFERENCE_COST) -> float:
	var lv := {&"damage": 0, &"rate": 0}
	var power := 1.0
	var left := budget
	for _i in 400:
		var track: StringName = &"damage" if price_at(cost, &"damage", lv[&"damage"]) \
				<= price_at(cost, &"rate", lv[&"rate"]) else &"rate"
		var price := float(price_at(cost, track, lv[track]))
		var gain := 1.0 + step(track, lv[track] + 1)
		if left < price:
			return power * pow(gain, left / price)
		left -= price
		power *= gain
		lv[track] += 1
	return power


## What every enemy's health is multiplied by when it spawns.
static func enemy_hp_mult() -> float:
	if not scale_enemies:
		return 1.0
	return ENEMY_HP_SCALE * dedicated_power(GameState.earned * SCALING_SHARE)


# --- Unlocking by rides -----------------------------------------------------------------

## Rides delivered in this run (ShiftManager counts them; reset with the run).
static func rides_done(tree: SceneTree) -> int:
	var shift := tree.get_first_node_in_group(&"shift_manager") as ShiftManager
	return shift.rides_completed if shift != null else 0


static func is_unlocked(base: WeaponData, tree: SceneTree) -> bool:
	return rides_done(tree) >= base.unlock_rides
