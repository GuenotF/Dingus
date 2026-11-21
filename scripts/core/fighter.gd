class_name Fighter
extends RefCounted
## Données d'un combattant. Logique pure, sans affichage.

var id: int
var display_name: String
var team: int
var cell: Vector2i

var max_hp: int = 100
var hp: int = 100
var max_pa: int = 6
var pa: int = 6
var max_pm: int = 3
var pm: int = 3


func _init(p_id: int, p_name: String, p_team: int, p_cell: Vector2i) -> void:
	id = p_id
	display_name = p_name
	team = p_team
	cell = p_cell


func reset_turn_points() -> void:
	pa = max_pa
	pm = max_pm


func is_alive() -> bool:
	return hp > 0
