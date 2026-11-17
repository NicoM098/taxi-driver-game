class_name WeaponUpgrades
extends RefCounted
## Weapon progression (D-085): unlocking by rides delivered, and the Mk I-IV upgrade track.
##
## The .tres in data/weapons/ is always the Mk I gun. `apply()` returns an upgraded COPY, which
## is what WeaponController fires; the gun shop and the hotbar keep reading the base resource.
##   Mk II  — damage +25 %
##   Mk III — magazine +50 %, reload -25 %, spread and recoil -30 %
##   Mk IV  — the weapon's special (WeaponData.special): deadeye / drum / incendiary / piercing /
##            big_blast / no_spinup / twin (D-085, D-086)
## The levels stack. Prices per weapon in WeaponData.upgrade_prices.

const MAX_LEVEL := 4
const NAMES: PackedStringArray = ["", "Mk I", "Mk II", "Mk III", "Mk IV"]

const DAMAGE_MULT := 1.25
const MAG_MULT := 1.5
const RELOAD_MULT := 0.75
const ACCURACY_MULT := 0.7
## Mk IV specials.
const DEADEYE_MULT := 2.0          # revolver: aimed shots
const DRUM_MAG := 75               # SMG
const DRUM_RESERVE_MULT := 2.0
const BURN_DPS := 9.0              # sawed-off: per second, per target, refreshed by every hit
const BURN_TIME := 4.0
const PIERCE_TARGETS := 3          # rifle, laser: cars one shot can go through
const BIG_BLAST_MULT := 1.6        # mines


static func level_name(level: int) -> String:
	return NAMES[clampi(level, 1, MAX_LEVEL)]


## The gun at `level`, as a new resource (the base is never modified).
static func apply(base: WeaponData, level: int) -> WeaponData:
	var w := base.duplicate() as WeaponData
	if level >= 2:
		w.damage = base.damage * DAMAGE_MULT
	if level >= 3:
		w.mag_size = ceili(base.mag_size * MAG_MULT)
		w.reload_time = base.reload_time * RELOAD_MULT
		w.spread_aimed = base.spread_aimed * ACCURACY_MULT
		w.spread_hip = base.spread_hip * ACCURACY_MULT
		w.spread_per_shot = base.spread_per_shot * ACCURACY_MULT
		w.recoil_pitch = base.recoil_pitch * ACCURACY_MULT
		w.recoil_yaw = base.recoil_yaw * ACCURACY_MULT
	if level >= MAX_LEVEL:
		match base.special:
			&"drum":
				w.mag_size = DRUM_MAG
				w.reserve_max = roundi(base.reserve_max * DRUM_RESERVE_MULT)
			&"big_blast":
				w.blast_radius = base.blast_radius * BIG_BLAST_MULT
			&"no_spinup":
				w.spin_up = 0.0
	return w


## Whether the run's current weapon has its Mk IV special.
static func has_special(w: WeaponData, special: StringName) -> bool:
	return w != null and w.special == special and GameState.weapon_level(w.id) >= MAX_LEVEL


## Price of going from `level` to `level + 1`, or -1 if already maxed.
static func next_price(base: WeaponData, level: int) -> int:
	var i := level - 1
	return base.upgrade_prices[i] if level < MAX_LEVEL and i < base.upgrade_prices.size() else -1


## One line for the gun shop: what the next level gives.
static func describe_next(base: WeaponData, level: int) -> String:
	match level + 1:
		2:
			return "Mk II: +25% damage"
		3:
			return "Mk III: bigger mag, faster reload, tighter aim"
		4:
			return "Mk IV — %s: %s" % [base.special_name, base.special_text]
	return "Fully upgraded — %s" % base.special_name


# --- Unlocking by rides ----------------------------------------------------------------

## Rides delivered in this run (ShiftManager counts them; reset with the run).
static func rides_done(tree: SceneTree) -> int:
	var shift := tree.get_first_node_in_group(&"shift_manager") as ShiftManager
	return shift.rides_completed if shift != null else 0


static func is_unlocked(base: WeaponData, tree: SceneTree) -> bool:
	return rides_done(tree) >= base.unlock_rides
