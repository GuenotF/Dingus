class_name CombatState
extends RefCounted
## État d'un combat : grille, combattants, tour en cours, sorts.
## La vue n'appelle que les méthodes publiques et écoute les signaux.
## En multijoueur, le serveur fera tourner exactement ce code pour valider les actions.

signal turn_started(fighter: Fighter, turn_number: int)
signal fighter_moved(fighter: Fighter, path: Array[Vector2i])
signal spell_cast(caster: Fighter, spell: SpellData, target: Vector2i, cells: Array[Vector2i])
signal fighter_damaged(fighter: Fighter, amount: int)
signal fighter_died(fighter: Fighter)
signal combat_ended(winner_team: int)

var grid: BattleGrid
var fighters: Array[Fighter] = []
var turn_number: int = 0
var is_over: bool = false
var winner_team: int = -1
## Générateur à graine : le serveur et les clients tireront les mêmes dégâts.
var rng := RandomNumberGenerator.new()
var _active_index: int = -1


func _init(p_grid: BattleGrid, rng_seed: int = 0) -> void:
	grid = p_grid
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func add_fighter(fighter: Fighter) -> void:
	fighters.append(fighter)


func start() -> void:
	turn_number = 0
	_active_index = -1
	is_over = false
	winner_team = -1
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


## Cases occupées par les autres combattants vivants (bloquent le passage et la vue).
func occupied_cells(except: Fighter = null) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for f in fighters:
		if f != except and f.is_alive():
			cells.append(f.cell)
	return cells


# --- Déplacement -----------------------------------------------------------

func reachable_for_active() -> Dictionary:
	var f := active_fighter()
	if f == null or is_over:
		return {}
	return grid.reachable_cells(f.cell, f.pm, occupied_cells(f))


func path_for_active(target: Vector2i) -> Array[Vector2i]:
	var f := active_fighter()
	var empty: Array[Vector2i] = []
	if f == null or is_over:
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


# --- Sorts -----------------------------------------------------------------

## Le combattant actif peut-il lancer ce sort (PA, limite de lancers) ?
func can_use_spell(spell: SpellData) -> bool:
	var f := active_fighter()
	if f == null or is_over or not f.spells.has(spell):
		return false
	return f.pa >= spell.pa_cost and f.casts_this_turn(spell) < spell.casts_per_turn


## Cases dans la portée du sort : case -> true si la ligne de vue est dégagée.
func cells_in_range(spell: SpellData) -> Dictionary:
	var result: Dictionary = {}
	var f := active_fighter()
	if f == null:
		return result
	var blockers := occupied_cells(f)
	for y in range(f.cell.y - spell.range_max, f.cell.y + spell.range_max + 1):
		for x in range(f.cell.x - spell.range_max, f.cell.x + spell.range_max + 1):
			var cell := Vector2i(x, y)
			if not grid.is_inside(cell) or grid.is_obstacle(cell):
				continue
			var dist := BattleGrid.distance(f.cell, cell)
			if dist < spell.range_min or dist > spell.range_max:
				continue
			if spell.line_only and cell.x != f.cell.x and cell.y != f.cell.y:
				continue
			var has_view := not spell.needs_line_of_sight or grid.has_line_of_sight(f.cell, cell, blockers)
			result[cell] = has_view
	return result


func can_cast_at(spell: SpellData, target: Vector2i) -> bool:
	if not can_use_spell(spell):
		return false
	return cells_in_range(spell).get(target, false)


## Lance un sort du combattant actif. Renvoie false si l'action est refusée.
func try_cast(spell: SpellData, target: Vector2i) -> bool:
	if not can_cast_at(spell, target):
		return false
	var caster := active_fighter()
	caster.register_cast(spell)
	var cells: Array[Vector2i] = []
	for cell in spell.affected_cells(target):
		if grid.is_inside(cell):
			cells.append(cell)
	spell_cast.emit(caster, spell, target, cells)

	for cell in cells:
		var victim := fighter_at(cell)
		if victim == null:
			continue
		var dealt := victim.take_damage(rng.randi_range(spell.damage_min, spell.damage_max))
		fighter_damaged.emit(victim, dealt)
		if not victim.is_alive():
			fighter_died.emit(victim)
	_check_end()
	return true


func _check_end() -> void:
	var teams_alive: Dictionary = {}
	for f in fighters:
		if f.is_alive():
			teams_alive[f.team] = true
	if teams_alive.size() <= 1:
		is_over = true
		winner_team = teams_alive.keys()[0] if teams_alive.size() == 1 else -1
		combat_ended.emit(winner_team)


# --- Tours -----------------------------------------------------------------

func end_turn() -> void:
	if fighters.is_empty() or is_over:
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
