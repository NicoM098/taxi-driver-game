class_name WeaponData
extends Resource
## One weapon type. Files live in res://data/weapons/<id>.tres; a new file is a new gun in the
## shop and the hotbar (slot = number key, 1-8).

@export var id: StringName = &""
@export var display_name: String = "Weapon"
## Fixed hotbar slot (1-8) = the number key that selects it. Weapons are listed in slot order.
@export var slot: int = 1
## One line for the gun shop.
@export var blurb: String = ""

@export_group("Behaviour")
## &"hitscan" (instant rays; also the minigun and the laser), &"rocket" (a projectile that
## explodes on impact) or &"mine" (dropped behind the taxi, explodes under a car). D-086.
@export var kind: StringName = &"hitscan"
## Hitscan only: draw one continuous beam instead of tracers (the laser).
@export var beam: bool = false
## Seconds of holding fire before the first shot (the minigun's barrels spinning up).
@export var spin_up: float = 0.0
## Rocket / mine: explosion radius in metres (full damage at the centre, 35 % at the edge).
@export var blast_radius: float = 0.0
## Rocket: flight speed in m/s.
@export var projectile_speed: float = 0.0

@export_group("Damage")
@export var damage: float = 25.0          # per pellet
@export var pellets: int = 1
@export var weapon_range: float = 150.0
@export var impact_force: float = 4.0     # impulse on physics props (N·s)

@export_group("Handling")
@export var fire_rate: float = 3.0        # shots per second
@export var automatic: bool = false       # hold to fire
## With `reserve_max` 0 the gun never reloads: the "magazine" is everything it carries (the
## mines, D-099), refilled by ammo boxes.
@export var mag_size: int = 6
@export var reserve_max: int = 36
@export var reload_time: float = 1.4

@export_group("Accuracy (degrees)")
@export var spread_aimed: float = 0.4     # base cone half-angle when aiming
@export var spread_hip: float = 3.0       # extra when firing without aiming
@export var spread_per_speed: float = 0.06    # extra per m/s of taxi speed
@export var spread_per_turn: float = 2.0      # extra per rad/s of taxi yaw rate
@export var spread_per_shot: float = 0.0      # bloom added per shot (decays)

@export_group("Recoil (degrees)")
@export var recoil_pitch: float = 2.5
@export var recoil_yaw: float = 0.6

@export_group("Look")
@export var gun_size: Vector3 = Vector3(0.05, 0.09, 0.26)
@export var gun_color: Color = Color(0.2, 0.2, 0.22)

@export_group("Economy")
## Gun shop price (0 = you start with it).
@export var price: int = 0
## Rides delivered in this run before the gun shop will sell it (0 = always on sale). D-085;
## cut ~15 % in D-093.
@export var unlock_rides: int = 0

@export_group("Upgrades")
## False = no upgrade tracks, no special, no perks on it, never a slot-machine prize: it is
## what it is (The Devastator, D-107).
@export var upgradable: bool = true
## Price scale of the upgrade tracks (WeaponUpgrades.price_at, D-093): the first Damage level
## costs this, every level after it x1.35. Every gun uses the same 225 (D-095: 10 % under the
## WeaponUpgrades.REFERENCE_COST the enemy health curve assumes): a cheaper gun would outgrow the
## enemies (and the heavy guns) without limit, a dearer one could never keep up.
@export var upgrade_cost: int = 225
## What the gun gains after WeaponUpgrades.SPECIAL_AT upgrades: &"deadeye" / &"drum" /
## &"incendiary" / &"piercing" / &"big_blast" / &"no_spinup" / &"twin"
## (handled in WeaponUpgrades.apply and WeaponController._fire).
@export var special: StringName = &""
@export var special_name: String = ""
@export var special_text: String = ""


## False for a gun that carries everything in one pool and never reloads (D-099).
func reloads() -> bool:
	return reserve_max > 0


## "12 | 36", or just "8" for a gun that never reloads.
static func ammo_text(w: WeaponData, a: Dictionary) -> String:
	if w != null and not w.reloads():
		return "%d" % int(a["mag"])
	return "%d | %d" % [int(a["mag"]), int(a["reserve"])]

