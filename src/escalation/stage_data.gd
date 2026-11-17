class_name StageData
extends Resource
## One stage of the escalation (D-091): who hunts the taxi, what it takes to reach the boss,
## and the boss fight that ends it. Files in res://data/stages/stage_<n>.tres, played in order.

@export var number: int = 1
@export var title: String = "Stage"
@export_multiline var tagline: String = ""
@export var color: Color = Color(1, 0.8, 0.2)

@export_group("Who answers the heat")
## Replaces the police cruiser (heat >= EnemyDirector.police_heat).
@export_file("*.tres") var law_car: String = ""
## Replaces the gang coupe of the bounty waves (heat >= EnemyDirector.bounty_heat).
@export_file("*.tres") var crime_car: String = ""
## Cars hunting at once (EnemyDirector.max_enemies). Bosses come on top.
@export var max_enemies: int = 5
## The heat never cools below this during the stage.
@export var heat_floor: int = 0
## Mini-bosses during the stage: one of these, every `elite_interval` s from `elite_heat` on.
@export var elite_cars: PackedStringArray = PackedStringArray()
@export var elite_interval: float = 0.0
@export var elite_heat: int = 3

@export_group("To reach the boss")
@export var fares: int = 5
@export var kills: int = 10
## Seconds survived in this stage (driving, not paused).
@export var seconds: float = 240.0

@export_group("Boss fight")
@export var boss_title: String = "Boss"
## Every car here is a boss: all must go down.
@export var boss_cars: PackedStringArray = PackedStringArray()
## Extra ordinary cars that come with them.
@export_file("*.tres") var escort_car: String = ""
@export var escort_count: int = 0
## Paid on top of the bosses' bounties when the stage is cleared.
@export var reward: int = 1000
