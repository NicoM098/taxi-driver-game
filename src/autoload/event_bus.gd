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
## Gang-rides mode (D-088): the ride card that replaces the passenger file. `lines` may hold
## BBCode; `stripe` is the card's colour (the passenger's gang, or yellow).
@warning_ignore("unused_signal")
signal ride_announced(title: String, lines: PackedStringArray, stripe: Color)
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
## A reload started (Phase 11: its sound runs over `reload_time`).
@warning_ignore("unused_signal")
signal weapon_reloading(weapon: Resource)
## Trigger pulled with an empty magazine and nothing left to load: the click.
@warning_ignore("unused_signal")
signal weapon_empty(weapon: Resource)

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
## The driver's life ran out: the taxi blows up and the run is over (main.gd shows game over).
@warning_ignore("unused_signal")
signal player_died
@warning_ignore("unused_signal")
signal passenger_killed
@warning_ignore("unused_signal")
signal enemy_destroyed(enemy: Node, bounty: int)
## Something exploded (camera shake for anyone nearby). strength ~1 = car explosion.
@warning_ignore("unused_signal")
signal explosion(position: Vector3, strength: float)

# Street life
## The taxi ran a pedestrian over.
@warning_ignore("unused_signal")
signal pedestrian_hit(position: Vector3)
## The player destroyed a civilian car (kind &"car"). Witnesses call the police.
@warning_ignore("unused_signal")
signal civilian_killed(position: Vector3, kind: StringName)

## A place the taxi is parked at offers an action on `interact` (E / D-pad up), e.g. a shop
## pad. `text` is the whole prompt line; empty clears it. `source` is who asked, so one shop
## clearing its prompt never wipes another's.
@warning_ignore("unused_signal")
signal interact_prompt(source: Node, text: String)

# Items
## The player drove through a Monstrous Energy can (first-person drink animation, heal flash).
@warning_ignore("unused_signal")
signal energy_drink_consumed
## The taxi drove through an enemy's ammo drop (AmmoPickup, D-094).
@warning_ignore("unused_signal")
signal ammo_picked_up(weapon_id: StringName, rounds: int)

# Style (Phase 11, D-081). Air time, near misses and anything else stunt-like announce themselves
# here with raw points; RideManager turns them into money the same way it does a drift chain, and
# the HUD shows the popup. Drifts keep their own richer signals in DriftChain.
@warning_ignore("unused_signal")
signal style_earned(kind: StringName, label: String, points: float)

# World / time of day (Phase 11, D-064)
## The city switched time of day. `mood` is a Lighting.Mood. Anything that owns its own lights
## (the taxi's headlights, later the enemy cars) listens here instead of polling the city.
@warning_ignore("unused_signal")
signal mood_changed(mood: int)
