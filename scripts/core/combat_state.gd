class_name CombatState
extends RefCounted
## État d'un combat : grille, combattants, placement, tours, sorts et effets.
## La vue et l'IA n'appellent que les méthodes publiques ; la vue écoute les signaux.
## En multijoueur, le serveur fera tourner exactement ce code pour valider les actions.

enum Phase { SETUP, PLACEMENT, FIGHT, OVER }

## Dégâts subis par case de poussée non parcourue (collision).
const PUSH_DAMAGE_PER_CELL := 8

signal fighter_placed(fighter: Fighter)
signal turn_started(fighter: Fighter, turn_number: int)
signal fighter_moved(fighter: Fighter, path: Array[Vector2i])
signal spell_cast(caster: Fighter, spell: SpellData, target: Vector2i, cells: Array[Vector2i])
signal fighter_damaged(fighter: Fighter, amount: int)
signal fighter_healed(fighter: Fighter, amount: int)
signal fighter_displaced(fighter: Fighter, from: Vector2i, to: Vector2i)
signal status_changed(fighter: Fighter)
signal fighter_died(fighter: Fighter)
signal combat_ended(winner_team: int)

var grid: BattleGrid
var fighters: Array[Fighter] = []
var turn_number: int = 0
var phase: Phase = Phase.SETUP
var winner_team: int = -1
## Cases de placement autorisées, par équipe : placement_zones[team] = Array[Vector2i].
var placement_zones: Array = []
## Générateur à graine : le serveur et les clients tireront les mêmes valeurs.
var rng := RandomNumberGenerator.new()
var _active_index: int = -1

var is_over: bool:
	get:
		return phase == Phase.OVER


func _init(p_grid: BattleGrid, rng_seed: int = 0) -> void:
	grid = p_grid
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func add_fighter(fighter: Fighter) -> void:
	fighters.append(fighter)


func active_fighter() -> Fighter:
	if phase != Phase.FIGHT and phase != Phase.OVER:
		return null
	if _active_index < 0 or _active_index >= fighters.size():
		return null
	return fighters[_active_index]


func fighter_at(cell: Vector2i) -> Fighter:
	for f in fighters:
		if f.is_alive() and f.cell == cell:
			return f
	return null


func enemies_of(fighter: Fighter) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for f in fighters:
		if f.is_alive() and f.team != fighter.team:
			result.append(f)
	return result


## Cases occupées par les autres combattants vivants (bloquent le passage et la vue).
func occupied_cells(except: Fighter = null) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for f in fighters:
		if f != except and f.is_alive():
			cells.append(f.cell)
	return cells


# --- Placement -----------------------------------------------------------------

func begin_placement() -> void:
	phase = Phase.PLACEMENT


func placement_cells(team: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if team < placement_zones.size():
		for cell in placement_zones[team]:
			result.append(cell)
	return result


## Place un combattant sur une case de sa zone. Échange avec un allié si la case est prise.
func place(fighter: Fighter, cell: Vector2i) -> bool:
	if phase != Phase.PLACEMENT or not placement_cells(fighter.team).has(cell):
		return false
	var other := fighter_at(cell)
	if other == fighter:
		return true
	if other != null:
		if other.team != fighter.team:
			return false
		other.cell = fighter.cell
		fighter_placed.emit(other)
	fighter.cell = cell
	fighter_placed.emit(fighter)
	return true


# --- Combat --------------------------------------------------------------------

func start() -> void:
	phase = Phase.FIGHT
	turn_number = 0
	_active_index = -1
	winner_team = -1
	end_turn()


# --- Déplacement -----------------------------------------------------------------

func reachable_for_active() -> Dictionary:
	var f := active_fighter()
	if f == null or phase != Phase.FIGHT:
		return {}
	return grid.reachable_cells(f.cell, f.pm, occupied_cells(f))


func path_for_active(target: Vector2i) -> Array[Vector2i]:
	var f := active_fighter()
	var empty: Array[Vector2i] = []
	if f == null or phase != Phase.FIGHT:
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


# --- Sorts -------------------------------------------------------------------------

## Le combattant actif peut-il lancer ce sort (PA, limite de lancers, recharge) ?
func can_use_spell(spell: SpellData) -> bool:
	var f := active_fighter()
	if f == null or phase != Phase.FIGHT or not f.spells.has(spell):
		return false
	return f.pa >= spell.pa_cost \
		and f.casts_this_turn(spell) < spell.casts_per_turn \
		and f.cooldown_left(spell) == 0


## Cases dans la portée du sort pour le combattant actif : case -> true si ciblable.
## false = dans la portée mais sans ligne de vue (affichée en gris).
func cells_in_range(spell: SpellData) -> Dictionary:
	var f := active_fighter()
	if f == null:
		return {}
	return cells_in_range_from(spell, f, f.cell)


## Portée à afficher : toutes les cases à portée, ciblables ou non (case -> ligne de vue ok).
## Contrairement à cells_in_range, ignore la règle de cible (case libre / combattant),
## pour que la portée reste visible même sans cible valide.
func range_display(spell: SpellData) -> Dictionary:
	var f := active_fighter()
	if f == null:
		return {}
	return cells_in_range_from(spell, f, f.cell, false)


## Même calcul, mais comme si `caster` se tenait sur `origin` (utilisé par l'IA).
func cells_in_range_from(spell: SpellData, caster: Fighter, origin: Vector2i, apply_target_rule: bool = true) -> Dictionary:
	var result: Dictionary = {}
	var blockers := occupied_cells(caster)
	for y in range(origin.y - spell.range_max, origin.y + spell.range_max + 1):
		for x in range(origin.x - spell.range_max, origin.x + spell.range_max + 1):
			var cell := Vector2i(x, y)
			if not grid.is_inside(cell) or grid.is_obstacle(cell):
				continue
			var dist := BattleGrid.distance(origin, cell)
			if dist < spell.range_min or dist > spell.range_max:
				continue
			if spell.line_only and cell.x != origin.x and cell.y != origin.y:
				continue
			if apply_target_rule:
				var occupant := fighter_at_from(cell, caster, origin)
				# « Case libre » = une case où l'on peut se tenir (ni occupée, ni dans l'eau).
				if spell.target_rule == SpellData.TargetRule.EMPTY and (occupant != null or grid.is_water(cell)):
					continue
				if spell.target_rule == SpellData.TargetRule.FIGHTER and occupant == null:
					continue
			var has_view := not spell.needs_line_of_sight or grid.has_line_of_sight(origin, cell, blockers)
			result[cell] = has_view
	return result


## Occupant d'une case si `caster` se tenait sur `origin`.
func fighter_at_from(cell: Vector2i, caster: Fighter, origin: Vector2i) -> Fighter:
	if cell == origin:
		return caster
	if cell == caster.cell:
		return null
	return fighter_at(cell)


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

	# Les cibles sont fixées au moment du lancer : une poussée ne les fait pas sortir de la zone.
	var victims: Array[Fighter] = []
	for cell in cells:
		var v := fighter_at(cell)
		if v != null and (spell.affects_caster or v != caster):
			victims.append(v)

	for effect in spell.effects:
		if effect.kind == EffectData.Kind.DASH:
			_apply_dash(caster, target)
			continue
		for victim in victims:
			if victim.is_alive():
				_apply_effect(effect, caster, victim, spell)
	_check_end()
	return true


func _apply_effect(effect: EffectData, caster: Fighter, victim: Fighter, spell: SpellData) -> void:
	match effect.kind:
		EffectData.Kind.DAMAGE:
			_damage(victim, rng.randi_range(effect.min_value, effect.max_value))
		EffectData.Kind.HEAL:
			var healed := victim.heal(rng.randi_range(effect.min_value, effect.max_value))
			fighter_healed.emit(victim, healed)
		EffectData.Kind.PUSH, EffectData.Kind.PULL:
			if victim == caster:
				return
			var dir := push_direction(caster.cell, victim.cell)
			if effect.kind == EffectData.Kind.PULL:
				dir = -dir
			var preview := preview_push(victim, dir, effect.min_value)
			var from := victim.cell
			if preview.cell != from:
				victim.cell = preview.cell
				fighter_displaced.emit(victim, from, victim.cell)
			# Comme sur Dofus : une poussée bloquée blesse, une attraction non.
			if effect.kind == EffectData.Kind.PUSH and preview.blocked > 0:
				_damage(victim, preview.blocked * PUSH_DAMAGE_PER_CELL)
		EffectData.Kind.MOD_PM, EffectData.Kind.MOD_PA:
			var amount := rng.randi_range(effect.min_value, effect.max_value)
			var on_active := victim == active_fighter()
			if effect.duration > 0:
				victim.statuses.append(StatusEffect.new(effect.kind, amount, effect.duration, spell.spell_name, on_active))
			if on_active:
				if effect.kind == EffectData.Kind.MOD_PM:
					victim.pm = maxi(0, victim.pm + amount)
				else:
					victim.pa = maxi(0, victim.pa + amount)
			status_changed.emit(victim)


func _apply_dash(caster: Fighter, target: Vector2i) -> void:
	if fighter_at(target) != null or not grid.is_walkable(target):
		return
	var from := caster.cell
	caster.cell = target
	fighter_displaced.emit(caster, from, target)


func _damage(victim: Fighter, amount: int) -> void:
	var dealt := victim.take_damage(amount)
	fighter_damaged.emit(victim, dealt)
	if not victim.is_alive():
		fighter_died.emit(victim)


## Direction cardinale de `from` vers `to` (axe dominant).
static func push_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))


## Où finirait `fighter` s'il était déplacé de `distance` cases dans `dir`,
## et combien de cases n'ont pas pu être parcourues (obstacle, pion ou bord).
func preview_push(fighter: Fighter, dir: Vector2i, distance: int) -> Dictionary:
	var cell := fighter.cell
	var moved := 0
	if dir != Vector2i.ZERO:
		var occupied := occupied_cells(fighter)
		for i in distance:
			var next := cell + dir
			if not grid.is_walkable(next, occupied):
				break
			cell = next
			moved += 1
	return {"cell": cell, "blocked": distance - moved if dir != Vector2i.ZERO else 0}


func _check_end() -> void:
	var teams_alive: Dictionary = {}
	for f in fighters:
		if f.is_alive():
			teams_alive[f.team] = true
	if teams_alive.size() <= 1:
		phase = Phase.OVER
		winner_team = teams_alive.keys()[0] if teams_alive.size() == 1 else -1
		combat_ended.emit(winner_team)


# --- Tours -------------------------------------------------------------------------

func end_turn() -> void:
	if fighters.is_empty() or phase != Phase.FIGHT:
		return
	var previous := active_fighter()
	if previous != null:
		previous.end_turn()
		status_changed.emit(previous)
	for i in fighters.size():
		_active_index = (_active_index + 1) % fighters.size()
		if fighters[_active_index].is_alive():
			break
	if _active_index == 0 or turn_number == 0:
		turn_number += 1
	var f := active_fighter()
	f.start_turn()
	status_changed.emit(f)
	turn_started.emit(f, turn_number)
