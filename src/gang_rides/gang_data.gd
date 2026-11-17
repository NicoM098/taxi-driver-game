class_name GangData
extends Resource
## One street gang of the gang-rides mode (D-088). Files in res://data/gangs/<id>.tres.
## Each gang owns a zone of the city (GangRides decides which); its members wait for a cab
## there, and its cars come for the taxi when it carries somebody from a rival gang.

@export var id: StringName = &""
@export var display_name: String = "Gang"
## Members' clothes, the ride card stripe, the minimap later.
@export var color: Color = Color.WHITE
## The gang's car (EnemyCarData).
@export_file("*.tres") var car: String = ""
## Street names of the members: "Tico 'Fang' Reyes".
@export var nicknames: PackedStringArray = []
## What a member says when his rivals show up.
@export var panic_lines: PackedStringArray = []
## What the member says when he gets in (sets the tone).
@export var greeting_lines: PackedStringArray = []
