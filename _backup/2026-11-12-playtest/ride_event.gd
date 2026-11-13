class_name RideEvent
extends Resource
## Base class for ride-event building blocks (Phase 07). A PassengerProfile lists RideEvents
## in `ride_events`; the RideEventRunner fires each one when its trigger is met.
## A new passenger is data (combine blocks in the .tres); only a new *kind of block* is code.
##
## Blocks hold NO per-ride state (the resource is shared by every passenger of that type):
## per-ride state lives in the `state` Dictionary the runner hands to start/tick/on_kick.

enum Trigger {
	ON_START,        ## when the ride begins
	AFTER_SECONDS,   ## trigger_value = seconds into the ride
	AFTER_DISTANCE,  ## trigger_value = metres driven
	AFTER_PROGRESS,  ## trigger_value = metres driven / straight-line ride distance (0.5 ~ halfway)
	ON_ARRIVAL,      ## when the passenger is delivered (before the payout is computed)
	ON_KICKED_OUT,   ## when the player throws the passenger out mid-ride
}

@export var trigger: Trigger = Trigger.ON_START
@export var trigger_value: float = 0.0
## Adds 0..this (random per ride) to trigger_value.
@export var trigger_random: float = 0.0
## Rolled once when the ride starts.
@export_range(0.0, 1.0) var chance: float = 1.0

@export_group("Conditions")
## Only if the ride was started with this file action (e.g. &"bribe"). Empty = any.
@export var requires_action: StringName = &""
## Not if the ride was started with this file action.
@export var unless_action: StringName = &""
## Waits until another event has set this flag (e.g. &"hijacked").
@export var requires_flag: StringName = &""
## Set on the ride when this event fires.
@export var sets_flag: StringName = &""


## Fires the event. Return true to stay active (tick() is then called every physics frame).
func start(_ctx: RideContext, _state: Dictionary) -> bool:
	return false


## Called while active. Return false when the event is over.
func tick(_ctx: RideContext, _state: Dictionary, _delta: float) -> bool:
	return false


## The player kicks the passenger out while this event is active. Return true if the event
## dealt with it (the default kick reaction of the profile is then skipped).
func on_kick(_ctx: RideContext, _state: Dictionary) -> bool:
	return false
