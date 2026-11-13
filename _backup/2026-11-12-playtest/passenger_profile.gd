class_name PassengerProfile
extends Resource
## Data for one passenger type: ride/fare fields (Phase 03) + the passenger file (Phase 04).
## + ride events (Phase 07). Drop a new .tres in res://data/passengers/ and the spawner
## picks it up automatically.

@export var id: StringName = &""
@export var display_name: String = "Passenger"
@export var color: Color = Color(0.3, 0.5, 0.9)

@export_group("Fare")
@export var fare_base: int = 20
@export var fare_per_100m: int = 8
@export var tip_multiplier: float = 1.0

@export_group("Ride")
@export var min_distance: float = 80.0
@export var max_distance: float = 250.0
## Empty = any district.
@export var destination_districts: Array[StringName] = []
## < 1 = in a hurry (less time), > 1 = relaxed.
@export var time_multiplier: float = 1.0

@export_group("File (dossier)")
@export var occupation: String = "Unknown"
## Random name per passenger; empty = display_name.
@export var name_pool: PackedStringArray = []
@export var age_min: int = 20
@export var age_max: int = 60
## Notes shown in the file. BBCode; wrap examinable details as [url=<examinable id>]text[/url].
@export_multiline var notes: String = ""
@export var examinables: Array[Examinable] = []
## Extra choices (KILL, specials). Drive + Kick out are always there unless overridden by id.
@export var actions: Array[PassengerAction] = []
## Hidden facts, revealed by examining (used by action requirements, later by ride events).
@export var hidden_traits: Array[StringName] = []
enum KickReaction { CALM, ANGRY, RELIEVED }
@export var kick_reaction: KickReaction = KickReaction.CALM
@export var kick_line: String = ""
## Driver damage of an ANGRY kick reaction. < 0 = RideManager default.
@export var kick_damage: float = -1.0

@export_group("Ride events (Phase 07)")
## Building blocks that fire during the ride (see src/events/). The twist of the archetype.
@export var ride_events: Array[RideEvent] = []

@export_group("Spawning")
@export var spawn_weight: float = 1.0
## First shift this passenger can show up in.
@export var min_shift: int = 1
## Where they wait. Empty = anywhere.
@export var districts: Array[StringName] = []
