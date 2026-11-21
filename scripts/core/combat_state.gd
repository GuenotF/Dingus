class_name CombatState
extends RefCounted
## État d'un combat : grille, combattants, tour en cours.
## La vue n'appelle que les méthodes publiques et écoute les signaux.
## En multijoueur, le serveur fera tourner exactement ce code pour valider les actions.

signal turn_started(fighter: Fighter, turn_number: int)
signal fighter_moved(fighter: Fighter, path: Array[Vector2i])

var grid: BattleGrid
var fighters: Array[Fighter] = []
var turn_number: int = 0
var _active_index: int = -1


func _init(p_grid: BattleGrid) -> void:
	grid = p_grid


func add_fighter(fighter: Fighter) -> void:
	fighters.append(fighter)


func start() -> void:
	turn_number = 0
	_active_index = -1
	end_turn()


func active_fighter() -> Fighter:
	if _active_index < 0 or _active_index >= fighters.size():
		return null
	return fighters[_active_index]


func fighter_at(cell: Vector2i) -> Fighter:
	for f in fighters:
		if f.is_alive() and f.cell == cell:
			return f
	return null


## Cases occupées par les autres combattants vivants (bloquent le passage).
func occupied_cells(except: Fighter = null) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for f in fighters:
		if f != except and f.is_alive():
			cells.append(f.cell)
	return cells


func reachable_for_active() -> Dictionary:
	var f := active_fighter()
	if f == null:
		return {}
	return grid.reachable_cells(f.cell, f.pm, occupied_cells(f))


func path_for_active(target: Vector2i) -> Array[Vector2i]:
	var f := active_fighter()
	var empty: Array[Vector2i] = []
	if f == null:
		return empty
	var path := grid.find_path(f.cell, target, occupied_cells(f))
	if path.size() > f.pm:
		return empty
	return path


## Déplace le combattant actif. Renvoie false si l'action est refusée.
func try_move(target: Vector2i) -> bool:
	var f := active_fighter()
	var path := path_for_active(target)
	if f == null or path.is_empty():
		return false
	f.pm -= path.size()
	f.cell = target
	fighter_moved.emit(f, path)
	return true


func end_turn() -> void:
	if fighters.is_empty():
		return
	for i in fighters.size():
		_active_index = (_active_index + 1) % fighters.size()
		if fighters[_active_index].is_alive():
			break
	if _active_index == 0 or turn_number == 0:
		turn_number += 1
	var f := active_fighter()
	f.reset_turn_points()
	turn_started.emit(f, turn_number)
