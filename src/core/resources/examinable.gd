class_name Examinable
extends Resource
## A detail in a passenger's file that can be examined (Papers, Please style).
## Shown highlighted in the notes ([url=<id>]...[/url]) and as an "Examine" button.

@export var id: StringName = &""
@export var label: String = "something"          # button text: "Examine: <label>"
@export_multiline var reveal_text: String = ""   # appended to the file once examined
@export var time_cost: float = 3.0               # seconds taken off this passenger's ride clock
@export var reveals_traits: Array[StringName] = []
