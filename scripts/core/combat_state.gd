class_name CombatState
extends RefCounted
## État d'un combat : grille, combattants, placement, tours, sorts et effets.
## La vue et l'IA n'appellent que les méthodes publiques ; la vue écoute les signaux.
## En multijoueur, le serveur fera tourner exactement ce code pour valider les actions.

enum Phase { SETUP, PLACEMENT, FIGHT, OVER }

## Dégâts subis par case de poussée non parcourue (collision).
const PUSH_DAMAGE_PER_CELL := 8
## Part des dégâts d'un effet DRAIN que le lanceur récupère en PV.
const DRAIN_RATIO := 0.5
## PM perdus par un combattant qui commence son tour dans un nuage de fumée.
const SMOKE_PM_MALUS := 2

signal fighter_placed(fighter: Fighter)
signal turn_started(fighter: Fighter, turn_number: int)
signal fighter_moved(fighter: Fighter, path: Array[Vector2i])
signal spell_cast(caster: Fighter, spell: SpellData, target: Vector2i, cells: Array[Vector2i])
signal fighter_damaged(fighter: Fighter, amount: int)
signal fighter_healed(fighter: Fighter, amount: int)
## Un bouclier a absorbé tout ou partie d'un coup.
signal shield_absorbed(fighter: Fighter, amount: int)
signal fighter_displaced(fighter: Fighter, from: Vector2i, to: Vector2i)
signal status_changed(fighter: Fighter)
signal fighter_died(fighter: Fighter)
## Un obstacle destructible encaisse des dégâts (`hp_left` > 0) ou est détruit (signal suivant).
signal obstacle_damaged(cell: Vector2i, amount: int, hp_left: int)
signal obstacle_destroyed(cell: Vector2i)
signal combat_ended(winner_team: int)
## Un nuage de fumée apparaît / disparaît (cases concernées).
signal smoke_added(cells: Array[Vector2i])
signal smoke_removed(cells: Array[Vector2i])

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
## Nuages de fumée en cours : { "cells": Array[Vector2i], "owner": Fighter }.
## Un nuage dure un tour : il disparaît au début du tour de son lanceur.
var smokes: Array[Dictionary] = []

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
			if not grid.is_inside(cell):
				continue
			# Un destructible est une cible valide pour les sorts de dégâts ; les autres obstacles non.
			if grid.is_obstacle(cell) and not (grid.is_destructible(cell) and spell.damages_obstacles()):
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
			var visible := not spell.needs_line_of_sight or has_view(origin, cell, blockers)
			result[cell] = visible
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
## Aperçu d'un lancer, sans rien modifier : pour chaque combattant touché,
## { "fighter": Fighter, "damage_min", "damage_max", "heal_min", "heal_max" }.
## Les dégâts de collision d'une poussée bloquée sont comptés. Les dégâts annoncés sont les PV perdus :
## le bouclier est déduit ("absorbed" = part maximale absorbée ; "shield" = bouclier que le sort donne).
func preview_cast(spell: SpellData, target: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var caster := active_fighter()
	if caster == null or not can_cast_at(spell, target):
		return result
	var drain_min := 0
	var drain_max := 0
	for cell in spell.affected_cells(target):
		var v := fighter_at(cell)
		if v == null or (v == caster and not spell.affects_caster):
			continue
		var p := {"fighter": v, "damage_min": 0, "damage_max": 0, "heal_min": 0, "heal_max": 0}
		for effect in spell.effects:
			match effect.kind:
				EffectData.Kind.DAMAGE:
					var bonus := damage_bonus(effect, v)
					p.damage_min += effect.min_value + bonus
					p.damage_max += effect.max_value + bonus
				EffectData.Kind.SHIELD:
					p["shield"] = effect.min_value
				EffectData.Kind.DRAIN:
					p.damage_min += effect.min_value
					p.damage_max += effect.max_value
					if v != caster:
						drain_min += int(clampi(effect.min_value - v.shield, 0, v.hp) * DRAIN_RATIO)
						drain_max += int(clampi(effect.max_value - v.shield, 0, v.hp) * DRAIN_RATIO)
				EffectData.Kind.HEAL:
					p.heal_min += effect.min_value
					p.heal_max += effect.max_value
				EffectData.Kind.PUSH:
					if v != caster:
						var push := preview_push(v, push_direction(caster.cell, v.cell), effect.min_value)
						p.damage_min += push.blocked * PUSH_DAMAGE_PER_CELL
						p.damage_max += push.blocked * PUSH_DAMAGE_PER_CELL
		if v.shield > 0 and p.damage_max > 0:
			p["absorbed"] = mini(v.shield, p.damage_max)
			p.damage_min = maxi(0, p.damage_min - v.shield)
			p.damage_max = maxi(0, p.damage_max - v.shield)
		if p.damage_max > 0 or p.heal_max > 0 or p.has("absorbed") or p.has("shield"):
			result.append(p)
	# Vol de vie : le soin du lanceur (sans dépasser ses PV maximum).
	var missing := caster.max_hp - caster.hp
	if drain_max > 0 and missing > 0:
		var gain_min := mini(drain_min, missing)
		var gain_max := mini(drain_max, missing)
		var found := false
		for p in result:
			if p.fighter == caster:
				p.heal_min += gain_min
				p.heal_max += gain_max
				found = true
		if not found:
			result.append({"fighter": caster, "damage_min": 0, "damage_max": 0, "heal_min": gain_min, "heal_max": gain_max})
	return result


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

	# Destructibles dans la zone : fixés eux aussi au moment du lancer.
	var obstacle_cells: Array[Vector2i] = []
	if spell.damages_obstacles():
		for cell in cells:
			if grid.is_destructible(cell):
				obstacle_cells.append(cell)

	for effect in spell.effects:
		if effect.kind == EffectData.Kind.DASH:
			_apply_dash(caster, target)
			continue
		if effect.kind == EffectData.Kind.SMOKE:
			_add_smoke(caster, cells)
			continue
		if effect.kind == EffectData.Kind.DAMAGE or effect.kind == EffectData.Kind.DRAIN:
			for cell in obstacle_cells:
				_damage_obstacle(cell, rng.randi_range(effect.min_value, effect.max_value))
		for victim in victims:
			if victim.is_alive():
				_apply_effect(effect, caster, victim, spell)
	_check_end()
	return true


func _apply_effect(effect: EffectData, caster: Fighter, victim: Fighter, spell: SpellData) -> void:
	match effect.kind:
		EffectData.Kind.DAMAGE:
			_damage(victim, rng.randi_range(effect.min_value, effect.max_value) + damage_bonus(effect, victim))
		EffectData.Kind.SHIELD:
			victim.shield = maxi(victim.shield, effect.min_value)
			status_changed.emit(victim)
		EffectData.Kind.IMMOBILIZE:
			var on_self := victim == active_fighter()
			victim.statuses.append(StatusEffect.new(effect.kind, 0, maxi(1, effect.duration), spell.spell_name, on_self))
			if on_self:
				victim.pm = 0
			status_changed.emit(victim)
		EffectData.Kind.DRAIN:
			var dealt := _damage(victim, rng.randi_range(effect.min_value, effect.max_value))
			if victim != caster and caster.is_alive():
				var gained := caster.heal(int(dealt * DRAIN_RATIO))
				if gained > 0:
					fighter_healed.emit(caster, gained)
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
				# Le choc abîme aussi l'obstacle destructible contre lequel on a été projeté.
				_damage_obstacle(victim.cell + dir, preview.blocked * PUSH_DAMAGE_PER_CELL)
		EffectData.Kind.STEAL_PA:
			if victim == caster:
				return
			var stolen := maxi(1, rng.randi_range(effect.min_value, effect.max_value))
			# La victime est forcément inactive (le lanceur joue) : le malus pèse sur son prochain tour.
			victim.statuses.append(StatusEffect.new(EffectData.Kind.MOD_PA, -stolen, maxi(1, effect.duration), spell.spell_name, false))
			status_changed.emit(victim)
			if caster.is_alive():
				caster.pa += stolen
				status_changed.emit(caster)
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


# --- Fumée ------------------------------------------------------------------------

## Pose un nuage sur ces cases (les obstacles pleins n'en gardent pas).
func _add_smoke(owner: Fighter, cells: Array[Vector2i]) -> void:
	var covered: Array[Vector2i] = []
	for cell in cells:
		if not grid.is_obstacle(cell):
			covered.append(cell)
	if covered.is_empty():
		return
	smokes.append({"cells": covered, "owner": owner})
	smoke_added.emit(covered)


func is_smoked(cell: Vector2i) -> bool:
	for s in smokes:
		if s.cells.has(cell):
			return true
	return false


## Toutes les cases actuellement sous la fumée.
func smoke_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for s in smokes:
		for cell in s.cells:
			if not result.has(cell):
				result.append(cell)
	return result


## La fumée coupe-t-elle la vue de `from` vers `to` ? Aveugle depuis une case de fumée
## (sauf pour viser sa propre case) ; une case de fumée entre les deux fait écran
## (les extrémités ne comptent pas : une cible dans la fumée reste visible depuis une case voisine).
func smoke_blocks_view(from: Vector2i, to: Vector2i) -> bool:
	if smokes.is_empty() or from == to:
		return false
	if is_smoked(from):
		return true
	for cell in BattleGrid.line_cells(from, to):
		if cell != from and cell != to and is_smoked(cell):
			return true
	return false


## Ligne de vue complète : la grille (obstacles, combattants) et la fumée.
func has_view(from: Vector2i, to: Vector2i, blockers: Array[Vector2i] = []) -> bool:
	return grid.has_line_of_sight(from, to, blockers) and not smoke_blocks_view(from, to)


## Les nuages du lanceur qui commence son tour disparaissent (et ceux dont le lanceur est mort).
func _expire_smokes(starting: Fighter) -> void:
	if smokes.is_empty():
		return
	var kept: Array[Dictionary] = []
	for s in smokes:
		if s.owner == starting or not s.owner.is_alive():
			smoke_removed.emit(s.cells)
		else:
			kept.append(s)
	smokes = kept


func _apply_dash(caster: Fighter, target: Vector2i) -> void:
	if fighter_at(target) != null or not grid.is_walkable(target):
		return
	var from := caster.cell
	caster.cell = target
	fighter_displaced.emit(caster, from, target)


## Abîme un obstacle destructible (sans effet sur une case qui n'en contient pas).
func _damage_obstacle(cell: Vector2i, amount: int) -> void:
	if not grid.is_destructible(cell):
		return
	var dealt := grid.damage_destructible(cell, amount)
	obstacle_damaged.emit(cell, dealt, grid.destructible_hp(cell))
	if not grid.is_destructible(cell):
		obstacle_destroyed.emit(cell)


## Aperçu des dégâts d'un lancer sur les destructibles de la zone, sans rien modifier :
## { "cell", "damage_min", "damage_max", "hp" }.
func preview_obstacles(spell: SpellData, target: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if active_fighter() == null or not spell.damages_obstacles() or not can_cast_at(spell, target):
		return result
	for cell in spell.affected_cells(target):
		if not grid.is_destructible(cell):
			continue
		var p := {"cell": cell, "damage_min": 0, "damage_max": 0, "hp": grid.destructible_hp(cell)}
		for effect in spell.effects:
			if effect.kind == EffectData.Kind.DAMAGE or effect.kind == EffectData.Kind.DRAIN:
				p.damage_min += effect.min_value
				p.damage_max += effect.max_value
		result.append(p)
	return result


## Dégâts ajoutés par un effet contre cette cible (bonus contre une cible entravée).
static func damage_bonus(effect: EffectData, victim: Fighter) -> int:
	return effect.bonus_vs_immobilized if victim.is_immobilized() else 0


## Retire des PV (bouclier d'abord) et renvoie les PV réellement perdus.
func _damage(victim: Fighter, amount: int) -> int:
	var shield_before := victim.shield
	var dealt := victim.take_damage(amount)
	var absorbed := shield_before - victim.shield
	if absorbed > 0:
		shield_absorbed.emit(victim, absorbed)
	if dealt > 0 or absorbed == 0:
		fighter_damaged.emit(victim, dealt)
	if not victim.is_alive():
		fighter_died.emit(victim)
	return dealt


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
	_expire_smokes(f)
	f.start_turn()
	if is_smoked(f.cell):
		# Commencer son tour dans la fumée ralentit, pour ce tour seulement.
		f.statuses.append(StatusEffect.new(EffectData.Kind.MOD_PM, -SMOKE_PM_MALUS, 1, "Fumigène"))
		f.pm = maxi(0, f.pm - SMOKE_PM_MALUS)
	status_changed.emit(f)
	turn_started.emit(f, turn_number)
