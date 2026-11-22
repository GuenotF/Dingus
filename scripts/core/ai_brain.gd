class_name AiBrain
extends RefCounted
## IA simple : à chaque appel, renvoie la meilleure action immédiate pour le combattant actif.
##   { "type": "cast", "spell": SpellData, "cell": Vector2i }
##   { "type": "move", "cell": Vector2i }
##   { "type": "end" }
## Elle passe par les mêmes règles que le joueur (CombatState), elle ne peut donc pas tricher.
## Principe : comparer « lancer un sort d'ici » et « bouger puis lancer », en ajoutant
## une préférence de distance propre à la classe (corps à corps ou distance).

const MIN_CAST_SCORE := 1.0
const MOVE_MARGIN := 0.5


static func next_action(state: CombatState) -> Dictionary:
	var me := state.active_fighter()
	if me == null or state.phase != CombatState.Phase.FIGHT:
		return {"type": "end"}

	var now := best_cast_from(state, me, me.cell)
	var now_total: float = now.score + position_score(state, me, me.cell)

	var best_move_cell := me.cell
	var best_move_total := -INF
	var reachable := state.reachable_for_active()
	for cell in reachable:
		var after := best_cast_from(state, me, cell)
		var total: float = maxf(after.score, 0.0) + position_score(state, me, cell) - reachable[cell] * 0.2
		if total > best_move_total:
			best_move_total = total
			best_move_cell = cell

	if best_move_cell != me.cell and best_move_total > maxf(now_total, position_score(state, me, me.cell)) + MOVE_MARGIN:
		return {"type": "move", "cell": best_move_cell}
	if now.score >= MIN_CAST_SCORE:
		return {"type": "cast", "spell": now.spell, "cell": now.cell}
	return {"type": "end"}


## Meilleur sort lançable si `me` se tenait sur `origin` : { score, spell, cell }.
static func best_cast_from(state: CombatState, me: Fighter, origin: Vector2i) -> Dictionary:
	var best := {"score": 0.0, "spell": null, "cell": origin}
	for spell in me.spells:
		if not state.can_use_spell(spell):
			continue
		var cells := state.cells_in_range_from(spell, me, origin)
		for cell in cells:
			if not cells[cell]:
				continue
			var score := score_cast(state, me, origin, spell, cell)
			if score > best.score:
				best = {"score": score, "spell": spell, "cell": cell}
	return best


## Valeur estimée d'un lancer (dégâts aux ennemis, soins utiles, contrôle...).
static func score_cast(state: CombatState, me: Fighter, origin: Vector2i, spell: SpellData, target: Vector2i) -> float:
	var victims: Array[Fighter] = []
	for cell in spell.affected_cells(target):
		var v := state.fighter_at_from(cell, me, origin)
		if v != null and (spell.affects_caster or v != me):
			victims.append(v)

	var score := 0.0
	for effect in spell.effects:
		var avg := effect.average()
		match effect.kind:
			EffectData.Kind.DAMAGE:
				for v in victims:
					if v.team != me.team:
						score += minf(avg, v.hp) + (40.0 if avg >= v.hp else 0.0)
					else:
						score -= avg * 1.5
			EffectData.Kind.HEAL:
				for v in victims:
					var missing := float(v.max_hp - v.hp)
					if v.team == me.team:
						var urgency := 1.5 if v.hp < v.max_hp * 0.5 else 0.6
						score += minf(avg, missing) * urgency
					else:
						score -= minf(avg, missing)
			EffectData.Kind.PUSH:
				for v in victims:
					if v.team != me.team and v != me:
						var dir := CombatState.push_direction(origin, v.cell)
						var preview := state.preview_push(v, dir, effect.min_value)
						score += 2.0 + preview.blocked * CombatState.PUSH_DAMAGE_PER_CELL
						if me.preferred_range() > 1:
							score += 4.0 # éloigner un ennemi arrange un personnage à distance
			EffectData.Kind.PULL:
				for v in victims:
					if v.team != me.team and v != me:
						var dist := BattleGrid.distance(origin, v.cell)
						score += 4.0 if me.preferred_range() <= 1 and dist > 2 else 0.5
			EffectData.Kind.MOD_PM, EffectData.Kind.MOD_PA:
				for v in victims:
					if v.team != me.team and avg < 0:
						score += 3.0 * -avg
					elif v.team == me.team and avg > 0:
						score += 5.0 * avg if _nearest_enemy_distance(state, me, origin) > 1 else 0.5
			EffectData.Kind.DASH:
				var d := _nearest_enemy_distance(state, me, target)
				if me.preferred_range() <= 1:
					score += 12.0 if d == 1 else maxf(0.0, 4.0 - d)
				else:
					score += 3.0 if d >= me.preferred_range() else -3.0
	return score - spell.pa_cost * 0.1


## Préférence de placement : rester à la bonne distance de l'ennemi le plus proche.
static func position_score(state: CombatState, me: Fighter, cell: Vector2i) -> float:
	var d := _nearest_enemy_distance(state, me, cell)
	if d >= 999:
		return 0.0
	var pref := me.preferred_range()
	var score := -absf(d - pref) * 1.5
	if pref > 1:
		if d <= 1:
			score -= 6.0 # un personnage à distance fuit le corps à corps
		# Ne pas finir à portée de déplacement d'un ennemi (il arriverait au contact au tour suivant).
		for e in state.enemies_of(me):
			if BattleGrid.distance(cell, e.cell) <= e.max_pm + 1:
				score -= 4.0
		# Ne pas se laisser coincer : on pénalise les cases avec peu d'issues.
		var exits := 0
		for dir in BattleGrid.DIRECTIONS:
			if state.grid.is_walkable(cell + dir, state.occupied_cells(me)):
				exits += 1
		score -= (4 - exits) * 1.5
	return score


static func _nearest_enemy_distance(state: CombatState, me: Fighter, from: Vector2i) -> int:
	var best := 999
	for e in state.enemies_of(me):
		best = mini(best, BattleGrid.distance(from, e.cell))
	return best
