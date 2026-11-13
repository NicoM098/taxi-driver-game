extends Node
## Global signal hub. Holds NO state — systems emit/listen here instead of reaching into each other.
## Types are loose (Resource/RefCounted) until the concrete classes exist (Phases 03-08); tighten then.

# Run (Phase 03). No shift clock: a run ends only when the taxi is wrecked / the driver dies.
@warning_ignore("unused_signal")
signal shift_started(shift_number: int)
@warning_ignore("unused_signal")
signal shift_ended(summary: Dictionary)

# Passenger / dossier / ride (Phases 03-04)
@warning_ignore("unused_signal")
signal passenger_entered(profile: Resource)
@warning_ignore("unused_signal")
signal dossier_opened(passenger: RefCounted)          # PassengerInstance
@warning_ignore("unused_signal")
signal dossier_action_chosen(passenger: RefCounted, action: Resource)   # PassengerInstance, PassengerAction
@warning_ignore("unused_signal")
signal dossier_closed
## The player shot their passenger from the file (camera looks back, red flash).
@warning_ignore("unused_signal")
signal passenger_executed(passenger: RefCounted)
@warning_ignore("unused_signal")
signal ride_started(ride: RefCounted)
@warning_ignore("unused_signal")
signal ride_completed(ride: RefCounted, payout: int)
@warning_ignore("unused_signal")
signal ride_failed(ride: RefCounted, reason: StringName)

# Ride events (Phase 07)
## Subtitle line from the passenger in the back seat.
@warning_ignore("unused_signal")
signal passenger_bark(speaker: String, text: String)
## Urgent prompt with a countdown (e.g. thief counter window). "{kick}" in the text is replaced
## by the key / button of the kick_out action. Empty text = clear it.
@warning_ignore("unused_signal")
signal ride_alert(text: String, seconds: float)
## A passenger gave the driver something. kind: &"heal" / &"cash" / &"ammo".
@warning_ignore("unused_signal")
signal ride_reward(kind: StringName, amount: float)
## Thrown out by the player (from the file or mid-ride).
@warning_ignore("unused_signal")
signal passenger_kicked_out(passenger: RefCounted)

# Economy / threat
@warning_ignore("unused_signal")
signal cash_changed(new_amount: int, delta: int)
@warning_ignore("unused_signal")
signal heat_changed(level: int)

# Combat / damage (Phases 05-06)
@warning_ignore("unused_signal")
signal taxi_damaged(amount: float, hp_left: float)
@warning_ignore("unused_signal")
signal weapon_fired(weapon: Resource)

# Items (Phase 08)
@warning_ignore("unused_signal")
signal item_acquired(item: Resource)

# HUD feedback (any system can pop a message). kind: &"info", &"good", &"bad", &"drift"
@warning_ignore("unused_signal")
signal hud_message(text: String, kind: StringName)

# Shooting feedback (Phase 05): a weapon hit a Hitbox; killed = this hit finished it off.
@warning_ignore("unused_signal")
signal hit_confirmed(killed: bool)

# Damage & enemies (Phase 06)
## The player's taxi was hit (bullets). from = shooter position (Vector3.INF if unknown).
@warning_ignore("unused_signal")
signal player_hit(amount: float, from: Vector3)
## Taxi destroyed or driver killed. reason: &"taxi_destroyed" / &"driver_killed".
@warning_ignore("unused_signal")
signal taxi_wrecked(reason: StringName)
@warning_ignore("unused_signal")
signal passenger_killed
@warning_ignore("unused_signal")
signal enemy_destroyed(enemy: Node, bounty: int)
## Something exploded (camera shake for anyone nearby). strength ~1 = car explosion.
@warning_ignore("unused_signal")
signal explosion(position: Vector3, strength: float)

# Items
## The player drove through a Monstrous Energy can (first-person drink animation, heal flash).
@warning_ignore("unused_signal")
signal energy_drink_consumed
