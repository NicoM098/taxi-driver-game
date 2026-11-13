class_name StreetEncounter
extends Resource
## One hostile situation that can hit the taxi on the open streets, with or without a fare
## aboard (user request 2026-11-13: "we need more hostile situations"). Data-driven: drop a
## .tres in res://data/events/ and StreetEncounters picks it up. `districts` is the hook for
## neighbourhood-specific trouble.

enum When { ANY, ON_RIDE, FREE_ROAM }

@export var id: StringName = &""
## HUD line when it starts.
@export var title: String = "TROUBLE!"
@export var weight: float = 1.0

@export_group("Conditions")
@export var when: When = When.ANY
## Difficulty level (GameState.shift_number) from which it can happen.
@export var min_level: int = 1
## Only when the player carries at least this much cash.
@export var min_cash: int = 0
## Only after this many enemy cars were destroyed in this run.
@export var min_kills: int = 0
## Only in these districts (zone ids of the map). Empty = anywhere.
@export var districts: Array[StringName] = []

@export_group("Enemies")
## EnemyCarData file; empty = hitman sedan.
@export_file("*.tres") var enemy: String = ""
@export var count: int = 2
## Extra cars per difficulty level after the first (0.5 = +1 every two levels).
@export var extra_per_level: float = 0.0
@export var pattern: SpawnPursuersEvent.Pattern = SpawnPursuersEvent.Pattern.TAIL
@export var heat_delta: int = 0
