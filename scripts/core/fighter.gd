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

var spells: Array[SpellData] = []
var _casts_this_turn: Dictionary = {} # SpellData -> nombre de lancers


func _init(p_id: int, p_name: String, p_team: int, p_cell: Vector2i) -> void:
	id = p_id
	display_name = p_name
	team = p_team
	cell = p_cell


func reset_turn_points() -> void:
	pa = max_pa
	pm = max_pm
	_casts_this_turn.clear()


func is_alive() -> bool:
	return hp > 0


func casts_this_turn(spell: SpellData) -> int:
	return _casts_this_turn.get(spell, 0)


func register_cast(spell: SpellData) -> void:
	pa -= spell.pa_cost
	_casts_this_turn[spell] = casts_this_turn(spell) + 1


## Applique des dégâts et renvoie les dégâts réellement subis.
func take_damage(amount: int) -> int:
	var dealt := mini(amount, hp)
	hp -= dealt
	return dealt
