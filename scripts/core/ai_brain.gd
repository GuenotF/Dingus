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
## Valeur d'un obstacle destructible qui nous sépare d'un ennemi (avant pondération par les dégâts infligés).
const OPEN_SHOT_VALUE := 12.0
const OPEN_PATH_VALUE := 10.0
const SHORTCUT_VALUE := 6.0
## Un ennemi pris dans la fumée ne voit plus rien et avance à peine ; se placer dans la sienne coûte autant.
const SMOKE_ENEMY_VALUE := 12.0
const SMOKE_STANDING_PENALTY := 10.0
## Part de la valeur d'un bouclier comptée quand un ennemi peut nous frapper à son tour.
const SHIELD_VALUE := 0.9
## Entailler un bouclier adverse sans passer à travers vaut moins que retirer des PV.
const SHIELD_HIT_VALUE := 0.3
## Entrave : empêcher un tireur de fuir ; clouer un combattant de mêlée à 2 cases (il ne peut plus frapper,
## alors qu'un sort de portée 2 l'atteint) ; gagner du temps quand on est blessé.
const IMMOBILIZE_RANGED_VALUE := 22.0
const IMMOBILIZE_OUT_OF_REACH_VALUE := 20.0
const IMMOBILIZE_DELAY_VALUE := 6.0
## Rester hors de portée d'un ennemi de mêlée entravé qu'on peut, nous, frapper à 2 cases.
const SAFE_FROM_BOUND_VALUE := 8.0


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
static func best_cast_from(state: CombatState, me: Fighter, origin: Vector2i, skip_sacrifice: bool = false) -> Dictionary:
	var best := {"score": 0.0, "spell": null, "cell": origin}
	for spell in me.spells:
		if not state.can_use_spell(spell) or (skip_sacrifice and _is_self_sacrifice(spell)):
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

	if _is_self_sacrifice(spell):
		return _score_sacrifice(state, me, origin, spell)

	var score := 0.0
	if spell.damages_obstacles():
		for cell in spell.affected_cells(target):
			if state.grid.is_destructible(cell):
				score += _obstacle_value(state, me, origin, spell, cell)
	for effect in spell.effects:
		var avg := effect.average()
		match effect.kind:
			EffectData.Kind.DRAIN:
				for v in victims:
					if v.team != me.team:
						score += minf(avg, v.hp) + (40.0 if avg >= v.hp else 0.0)
						# Le vol de vie compte, surtout quand le lanceur est blessé.
						var gain := minf(minf(avg, v.hp) * CombatState.DRAIN_RATIO, float(me.max_hp - me.hp))
						score += gain * (1.5 if me.hp < me.max_hp * 0.5 else 0.6)
					else:
						score -= avg * 1.5
			EffectData.Kind.DAMAGE:
				for v in victims:
					if v.team != me.team:
						var total := avg + CombatState.damage_bonus(effect, v)
						var through := maxf(0.0, total - v.shield)
						score += minf(through, v.hp) + (40.0 if through >= v.hp else 0.0)
						score += minf(total, v.shield) * SHIELD_HIT_VALUE
					else:
						score -= avg * 1.5
			EffectData.Kind.SHIELD:
				for v in victims:
					if v.team == me.team:
						# Utile seulement si un ennemi peut nous frapper à son prochain tour.
						score += avg * SHIELD_VALUE if v.shield == 0 and _is_threatened(state, me, origin) else -5.0
			EffectData.Kind.IMMOBILIZE:
				for v in victims:
					if v.team != me.team:
						score += _immobilize_value(me, origin, v)
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
						# Ralentir un combattant au corps à corps vaut cher pour un personnage à distance.
						var kiting := effect.kind == EffectData.Kind.MOD_PM and me.preferred_range() > 1 and v.preferred_range() <= 1
						score += (6.0 if kiting else 3.0) * -avg
					elif v.team == me.team and avg > 0:
						score += 5.0 * avg if _nearest_enemy_distance(state, me, origin) > 1 else 0.5
			EffectData.Kind.STEAL_PA:
				for v in victims:
					if v.team != me.team and v != me:
						# Un PA volé : un de moins pour lui, un de plus pour nous.
						score += 8.0 * avg
			EffectData.Kind.SMOKE:
				for v in victims:
					score += SMOKE_ENEMY_VALUE if v.team != me.team else -SMOKE_ENEMY_VALUE
			EffectData.Kind.DASH:
				var d := _nearest_enemy_distance(state, me, target)
				if me.preferred_range() <= 1:
					score += 12.0 if d == 1 else maxf(0.0, 4.0 - d)
				else:
					# Un tireur ne roule que pour se dégager, pas « pour rien » en début de combat.
					var before := _nearest_enemy_distance(state, me, origin)
					score += 3.0 * (d - before) if before < me.preferred_range() and d > before else -3.0
	return score - spell.pa_cost * 0.1


## Un ennemi peut-il, à son prochain tour, venir à portée de `cell` et frapper ?
static func _is_threatened(state: CombatState, me: Fighter, cell: Vector2i) -> bool:
	for e in state.enemies_of(me):
		var steps := 0 if e.is_immobilized() else e.max_pm
		if BattleGrid.distance(cell, e.cell) <= steps + _longest_attack_range(e):
			return true
	return false


## Intérêt d'entraver `v` depuis `origin`. Inutile s'il l'est déjà, ou sur un combattant de mêlée
## déjà au contact : il n'a pas besoin de bouger pour frapper.
static func _immobilize_value(me: Fighter, origin: Vector2i, v: Fighter) -> float:
	if v.is_immobilized():
		return 0.0
	if v.preferred_range() > 1:
		return IMMOBILIZE_RANGED_VALUE
	var d := BattleGrid.distance(origin, v.cell)
	if d <= 1:
		return 0.0
	if d == 2 and _longest_attack_range(v) < 2:
		return IMMOBILIZE_OUT_OF_REACH_VALUE
	return IMMOBILIZE_DELAY_VALUE if me.hp < me.max_hp * 0.5 else 0.5


## Intérêt de casser un obstacle destructible : il nous masque un ennemi à portée de tir,
## ou barre la route (ou l'allonge beaucoup). Pondéré par la part de ses PV que le sort enlève,
## avec un minimum pour que l'IA s'acharne sur un obstacle déjà entamé.
static func _obstacle_value(state: CombatState, me: Fighter, origin: Vector2i, spell: SpellData, cell: Vector2i) -> float:
	var hp := state.grid.destructible_hp(cell)
	if hp <= 0:
		return 0.0
	var damage := 0.0
	for effect in spell.effects:
		if effect.kind == EffectData.Kind.DAMAGE or effect.kind == EffectData.Kind.DRAIN:
			damage += effect.average()
	var gain := 0.0
	var blockers := state.occupied_cells(me)
	var reach := _longest_attack_range(me)
	for e in state.enemies_of(me):
		if BattleGrid.distance(origin, e.cell) <= reach \
				and not state.grid.has_line_of_sight(origin, e.cell, blockers) \
				and state.grid.has_line_of_sight_without(origin, e.cell, cell, blockers):
			gain = maxf(gain, OPEN_SHOT_VALUE)
		var before := state.grid.find_path(origin, e.cell).size()
		var after := state.grid.path_length_without(origin, e.cell, cell)
		if after > 0 and before == 0:
			gain = maxf(gain, OPEN_PATH_VALUE)
		elif after > 0 and before - after >= 3:
			gain = maxf(gain, SHORTCUT_VALUE)
	return gain * (0.3 + 0.7 * minf(1.0, damage / hp))


static func _longest_attack_range(me: Fighter) -> int:
	var best := 0
	for spell in me.spells:
		for effect in spell.effects:
			if effect.kind == EffectData.Kind.DAMAGE or effect.kind == EffectData.Kind.DRAIN:
				best = maxi(best, spell.range_max)
	return best


## Sort sur soi qui coûte des PV pour gagner des PA (ex. Pacte de sang).
static func _is_self_sacrifice(spell: SpellData) -> bool:
	if spell.range_max != 0 or not spell.affects_caster:
		return false
	var hurts := false
	var gains_pa := false
	for e in spell.effects:
		if e.kind == EffectData.Kind.DAMAGE:
			hurts = true
		elif e.kind == EffectData.Kind.MOD_PA and e.average() > 0:
			gains_pa = true
	return hurts and gains_pa


## Le sacrifice vaut le coup quand on peut frapper tout de suite depuis cette case, que les PA en plus
## serviront et qu'il reste assez de PV : on l'ouvre avant de frapper. Jamais « pour rien ».
static func _score_sacrifice(state: CombatState, me: Fighter, origin: Vector2i, spell: SpellData) -> float:
	var damage := 0.0
	var pa_gain := 0.0
	for e in spell.effects:
		if e.kind == EffectData.Kind.DAMAGE:
			damage += e.average()
		elif e.kind == EffectData.Kind.MOD_PA:
			pa_gain += e.average()
	if me.hp <= damage * 3.0:
		return -100.0
	var engaged: bool = best_cast_from(state, me, origin, true).score >= MIN_CAST_SCORE * 5.0
	var pa_left := me.pa - spell.pa_cost + pa_gain
	if not engaged or pa_left < 3.0 or pa_gain - spell.pa_cost < 1.0:
		return -5.0
	return 30.0 - damage * 0.2


## Préférence de placement : rester à la bonne distance de l'ennemi le plus proche.
static func position_score(state: CombatState, me: Fighter, cell: Vector2i) -> float:
	var d := _nearest_enemy_distance(state, me, cell)
	if d >= 999:
		return 0.0
	var pref := me.preferred_range()
	if pref <= 1:
		# Au corps à corps, ce qui compte est le chemin à parcourir : un rocher entre les deux
		# ne doit pas donner l'impression d'être déjà au contact (sinon l'IA reste plantée).
		d = maxi(d, _nearest_enemy_walk(state, me, cell))
	var score := -absf(d - pref) * 1.5
	if pref <= 1 and _longest_attack_range(me) >= 2:
		for e in state.enemies_of(me):
			if e.is_immobilized() and _longest_attack_range(e) < 2 and BattleGrid.distance(cell, e.cell) == 2:
				score += SAFE_FROM_BOUND_VALUE
	if state.is_smoked(cell):
		score -= SMOKE_STANDING_PENALTY # aveugle et ralenti : on n'y reste pas
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


## Nombre de pas pour rejoindre l'ennemi le plus proche (0 si aucun chemin : on garde la distance à vol d'oiseau).
static func _nearest_enemy_walk(state: CombatState, me: Fighter, from: Vector2i) -> int:
	var best := 0
	for e in state.enemies_of(me):
		var path := state.grid.find_path(from, e.cell)
		if not path.is_empty() and (best == 0 or path.size() < best):
			best = path.size()
	return best


static func _nearest_enemy_distance(state: CombatState, me: Fighter, from: Vector2i) -> int:
	var best := 999
	for e in state.enemies_of(me):
		best = mini(best, BattleGrid.distance(from, e.cell))
	return best
