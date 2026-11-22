extends SceneTree
## Tests de la logique pure, sans fenêtre :
##   godot --headless --path . -s res://tests/test_core.gd

var _failures := 0


func _init() -> void:
	_test_iso_round_trip()
	_test_reachable_respects_pm_and_obstacles()
	_test_path_avoids_occupied_cells()
	_test_move_consumes_pm()
	_test_turn_rotation()
	_test_line_of_sight()
	_test_spell_range_and_los()
	_test_cast_costs_and_limits()
	_test_area_hits_caster_too()
	_test_death_and_victory()
	_test_push_and_collision()
	_test_pull_and_dash()
	_test_heal_capped()
	_test_pm_status_and_cooldown()
	_test_placement()
	_test_class_data_files()
	_test_ai_takes_obvious_kill()
	_test_ai_vs_ai_finishes()
	print("Tests terminés : %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("ÉCHEC : ", label)


func _test_iso_round_trip() -> void:
	for y in 15:
		for x in 15:
			var cell := Vector2i(x, y)
			var center := Iso.cell_to_world(cell)
			_check(Iso.world_to_cell(center) == cell, "iso centre %s" % cell)
			_check(Iso.world_to_cell(center + Vector2(20, 5)) == cell, "iso décalé %s" % cell)


func _test_reachable_respects_pm_and_obstacles() -> void:
	var walls: Array[Vector2i] = [Vector2i(3, 2)]
	var grid := BattleGrid.new(5, 5, walls)
	var zone := grid.reachable_cells(Vector2i(2, 2), 1)
	_check(zone.size() == 3, "1 PM à côté d'un mur = 3 cases (obtenu %d)" % zone.size())
	_check(not zone.has(Vector2i(3, 2)), "le mur n'est pas atteignable")
	_check(grid.reachable_cells(Vector2i(0, 0), 2).size() == 5, "coin avec 2 PM = 5 cases")


func _test_path_avoids_occupied_cells() -> void:
	var grid := BattleGrid.new(5, 1)
	var blocked: Array[Vector2i] = [Vector2i(2, 0)]
	_check(grid.find_path(Vector2i(0, 0), Vector2i(4, 0), blocked).is_empty(), "couloir bloqué par un pion")
	var path := grid.find_path(Vector2i(0, 0), Vector2i(4, 0))
	_check(path.size() == 4 and path[-1] == Vector2i(4, 0), "couloir libre = 4 pas")
	# Le pion ne doit pas rester "solide" après la requête
	_check(grid.find_path(Vector2i(0, 0), Vector2i(4, 0)).size() == 4, "case libérée après la requête")


func _make_state() -> CombatState:
	var state := CombatState.new(BattleGrid.new(10, 10))
	state.add_fighter(Fighter.new(0, "A", 0, Vector2i(0, 0)))
	state.add_fighter(Fighter.new(1, "B", 1, Vector2i(9, 9)))
	state.start()
	return state


func _test_move_consumes_pm() -> void:
	var state := _make_state()
	var a := state.active_fighter()
	_check(state.try_move(Vector2i(2, 0)), "déplacement de 2 cases accepté")
	_check(a.pm == 1 and a.cell == Vector2i(2, 0), "PM restants = 1")
	_check(not state.try_move(Vector2i(4, 0)), "déplacement trop long refusé")


func _test_turn_rotation() -> void:
	var state := _make_state()
	_check(state.active_fighter().id == 0 and state.turn_number == 1, "tour 1 : A")
	state.active_fighter().pm = 0
	state.end_turn()
	_check(state.active_fighter().id == 1 and state.turn_number == 1, "tour 1 : B")
	state.end_turn()
	_check(state.active_fighter().id == 0 and state.turn_number == 2, "tour 2 : A")
	_check(state.active_fighter().pm == 3, "PM rechargés au début du tour")


# --- Phase 2 : sorts ---------------------------------------------------------

func _spell(cost: int, rmin: int, rmax: int, los: bool, dmg: int, casts: int = 3) -> SpellData:
	var s := SpellData.new()
	s.pa_cost = cost
	s.range_min = rmin
	s.range_max = rmax
	s.needs_line_of_sight = los
	var effects: Array[EffectData] = [EffectData.make(EffectData.Kind.DAMAGE, dmg)]
	s.effects = effects
	s.casts_per_turn = casts
	return s


func _effect_spell(cost: int, rmin: int, rmax: int, effects: Array[EffectData]) -> SpellData:
	var s := _spell(cost, rmin, rmax, false, 0)
	s.effects = effects
	s.casts_per_turn = 5
	return s


func _duel(spells: Array[SpellData], a_cell: Vector2i, b_cell: Vector2i, walls: Array[Vector2i] = []) -> CombatState:
	var state := CombatState.new(BattleGrid.new(10, 10, walls), 42)
	var a := Fighter.new(0, "A", 0, a_cell)
	var b := Fighter.new(1, "B", 1, b_cell)
	a.spells = spells
	b.spells = spells
	state.add_fighter(a)
	state.add_fighter(b)
	state.start()
	return state


func _test_line_of_sight() -> void:
	var walls: Array[Vector2i] = [Vector2i(2, 0)]
	var grid := BattleGrid.new(6, 6, walls)
	_check(not grid.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0)), "mur au milieu coupe la vue")
	_check(grid.has_line_of_sight(Vector2i(0, 1), Vector2i(4, 1)), "ligne voisine dégagée")
	_check(grid.has_line_of_sight(Vector2i(0, 0), Vector2i(2, 0)) , "la case cible ne bloque pas")
	var blockers: Array[Vector2i] = [Vector2i(2, 1)]
	_check(not grid.has_line_of_sight(Vector2i(0, 1), Vector2i(4, 1), blockers), "un pion coupe la vue")
	# Stricte : frôler le coin d'un obstacle coupe la vue
	var corner: Array[Vector2i] = [Vector2i(1, 0)]
	var g2 := BattleGrid.new(6, 6, corner)
	_check(not g2.has_line_of_sight(Vector2i(0, 0), Vector2i(2, 2)), "diagonale qui frôle un coin bloquée")
	_check(not g2.has_line_of_sight(Vector2i(2, 2), Vector2i(0, 0)), "idem dans l'autre sens")
	_check(not g2.has_line_of_sight(Vector2i(0, 0), Vector2i(2, 1)), "segment qui traverse l'obstacle bloqué")
	_check(g2.has_line_of_sight(Vector2i(0, 1), Vector2i(2, 2)), "segment qui passe à côté visible")
	var all_cells := BattleGrid.line_cells(Vector2i(0, 0), Vector2i(3, 1))
	_check(all_cells[0] == Vector2i(0, 0) and all_cells[-1] == Vector2i(3, 1), "extrémités en bout de tracé")
	for a in [Vector2i(0, 0), Vector2i(1, 4), Vector2i(5, 2)]:
		for b in [Vector2i(3, 5), Vector2i(5, 0), Vector2i(4, 3)]:
			_check(grid.has_line_of_sight(a, b) == grid.has_line_of_sight(b, a), "symétrie %s %s" % [a, b])


func _test_spell_range_and_los() -> void:
	var arrow := _spell(4, 2, 6, true, 10)
	var walls: Array[Vector2i] = [Vector2i(3, 0)]
	var state := _duel([arrow], Vector2i(0, 0), Vector2i(9, 9), walls)
	var zone := state.cells_in_range(arrow)
	_check(not zone.has(Vector2i(1, 0)), "portée min 2 respectée")
	_check(zone.has(Vector2i(2, 0)) and zone[Vector2i(2, 0)], "case à 2 visible")
	_check(zone.has(Vector2i(5, 0)) and not zone[Vector2i(5, 0)], "case derrière le mur hors ligne de vue")
	_check(not zone.has(Vector2i(4, 3)), "portée max 6 respectée")
	_check(not state.try_cast(arrow, Vector2i(5, 0)), "lancer sans ligne de vue refusé")


func _test_cast_costs_and_limits() -> void:
	var sword := _spell(3, 1, 1, true, 10, 1)
	var state := _duel([sword], Vector2i(0, 0), Vector2i(1, 0))
	var a := state.active_fighter()
	var b := state.fighters[1]
	_check(state.try_cast(sword, Vector2i(1, 0)), "coup au contact accepté")
	_check(a.pa == 3 and b.hp == 90, "PA dépensés et dégâts appliqués")
	_check(not state.try_cast(sword, Vector2i(1, 0)), "limite de 1 lancer par tour")
	state.end_turn()
	state.end_turn()
	_check(state.can_use_spell(sword), "limite réinitialisée au tour suivant")
	var big := _spell(7, 1, 1, true, 10)
	a.spells.append(big)
	_check(not state.try_cast(big, Vector2i(1, 0)), "PA insuffisants refusés")


func _test_area_hits_caster_too() -> void:
	var bomb := _spell(5, 1, 4, false, 15)
	bomb.area = SpellData.AreaShape.CROSS
	var state := _duel([bomb], Vector2i(4, 4), Vector2i(6, 4))
	_check(state.try_cast(bomb, Vector2i(5, 4)), "bombe lancée entre les deux")
	_check(state.fighters[0].hp == 85 and state.fighters[1].hp == 85, "la croix touche les deux combattants")


func _test_death_and_victory() -> void:
	var nuke := _spell(1, 1, 1, true, 999)
	var state := _duel([nuke], Vector2i(0, 0), Vector2i(1, 0))
	var ended := [-2]
	state.combat_ended.connect(func(team: int) -> void: ended[0] = team)
	_check(state.try_cast(nuke, Vector2i(1, 0)), "coup fatal")
	_check(not state.fighters[1].is_alive() and state.fighters[1].hp == 0, "B est mort, PV à 0")
	_check(state.is_over and ended[0] == 0, "victoire de l'équipe 0")
	_check(not state.try_move(Vector2i(0, 1)), "plus d'action après la fin")
	_check(state.fighter_at(Vector2i(1, 0)) == null, "un mort ne bloque plus la case")


# --- Phase 3 : effets, statuts, placement, classes, IA ----------------------------

const K := EffectData.Kind


func _test_push_and_collision() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.PUSH, 2)]
	var push := _effect_spell(1, 1, 1, fx)
	var state := _duel([push], Vector2i(1, 1), Vector2i(2, 1))
	_check(state.try_cast(push, Vector2i(2, 1)), "poussée lancée")
	_check(state.fighters[1].cell == Vector2i(4, 1) and state.fighters[1].hp == 100, "poussée libre de 2 cases, sans dégâts")
	var walls: Array[Vector2i] = [Vector2i(4, 1)]
	state = _duel([push], Vector2i(1, 1), Vector2i(2, 1), walls)
	state.try_cast(push, Vector2i(2, 1))
	_check(state.fighters[1].cell == Vector2i(3, 1), "poussée stoppée par le mur")
	_check(state.fighters[1].hp == 100 - CombatState.PUSH_DAMAGE_PER_CELL, "1 case bloquée = dégâts de collision")
	state = _duel([push], Vector2i(8, 1), Vector2i(9, 1))
	state.try_cast(push, Vector2i(9, 1))
	_check(state.fighters[1].hp == 100 - 2 * CombatState.PUSH_DAMAGE_PER_CELL, "bord de carte = 2 cases bloquées")


func _test_pull_and_dash() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.PULL, 2)]
	var pull := _effect_spell(1, 1, 5, fx)
	var state := _duel([pull], Vector2i(0, 0), Vector2i(2, 0))
	state.try_cast(pull, Vector2i(2, 0))
	_check(state.fighters[1].cell == Vector2i(1, 0) and state.fighters[1].hp == 100, "attraction stoppée contre le lanceur, sans dégâts")
	var dash_fx: Array[EffectData] = [EffectData.make(K.DASH, 0)]
	var dash := _effect_spell(1, 2, 3, dash_fx)
	dash.target_rule = SpellData.TargetRule.EMPTY
	state = _duel([dash], Vector2i(0, 0), Vector2i(9, 9))
	_check(state.try_cast(dash, Vector2i(3, 0)) and state.fighters[0].cell == Vector2i(3, 0), "bond sur une case libre")
	state = _duel([dash], Vector2i(0, 0), Vector2i(2, 0))
	_check(not state.try_cast(dash, Vector2i(2, 0)), "bond refusé sur une case occupée")


func _test_heal_capped() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.HEAL, 30)]
	var heal := _effect_spell(1, 0, 3, fx)
	heal.target_rule = SpellData.TargetRule.FIGHTER
	var state := _duel([heal], Vector2i(0, 0), Vector2i(9, 9))
	var me := state.active_fighter()
	me.hp = 80
	_check(not state.cells_in_range(heal).has(Vector2i(1, 0)), "soin : case vide non ciblable")
	_check(state.try_cast(heal, me.cell) and me.hp == 100, "soin sur soi plafonné aux PV max")


func _test_pm_status_and_cooldown() -> void:
	var slow_fx: Array[EffectData] = [EffectData.make(K.MOD_PM, -1, EffectData.SAME_AS_MIN, 1)]
	var slow := _effect_spell(1, 1, 5, slow_fx)
	var buff_fx: Array[EffectData] = [EffectData.make(K.MOD_PM, 1, EffectData.SAME_AS_MIN, 1)]
	var cry := _effect_spell(1, 0, 0, buff_fx)
	cry.cooldown = 3
	var state := _duel([slow, cry], Vector2i(0, 0), Vector2i(3, 0))
	var a := state.fighters[0]
	var b := state.fighters[1]
	state.try_cast(slow, b.cell)
	_check(b.statuses.size() == 1, "malus posé sur B")
	_check(state.try_cast(cry, a.cell) and a.pm == 4, "Cri : +1 PM immédiat")
	_check(not state.can_use_spell(cry), "Cri en recharge")
	state.end_turn()
	_check(b.pm == 2 and b.statuses.size() == 1, "B commence avec 2 PM, malus visible pendant son tour")
	state.end_turn()
	_check(b.statuses.is_empty(), "le malus expire à la fin du tour de B")
	_check(a.pm == 4 and a.statuses.size() == 1, "le bonus du Cri dure aussi au tour suivant")
	_check(not state.can_use_spell(cry), "recharge : encore indisponible")
	state.end_turn()
	state.end_turn()
	_check(a.pm == 3, "bonus expiré")
	_check(not state.can_use_spell(cry), "recharge 3 : indisponible 2 tours")
	state.end_turn()
	state.end_turn()
	_check(state.can_use_spell(cry), "recharge terminée")


func _test_placement() -> void:
	var state := CombatState.new(BattleGrid.new(10, 10), 7)
	state.placement_zones = [[Vector2i(0, 0), Vector2i(0, 1)], [Vector2i(9, 9)]]
	var a := Fighter.new(0, "A", 0, Vector2i(0, 0))
	var b := Fighter.new(1, "B", 1, Vector2i(9, 9))
	state.add_fighter(a)
	state.add_fighter(b)
	_check(not state.place(a, Vector2i(0, 1)), "placement refusé hors phase")
	state.begin_placement()
	_check(state.place(a, Vector2i(0, 1)) and a.cell == Vector2i(0, 1), "placement dans sa zone")
	_check(not state.place(a, Vector2i(9, 9)), "placement refusé dans la zone adverse")
	_check(not state.place(a, Vector2i(5, 5)), "placement refusé hors zone")
	_check(state.active_fighter() == null and not state.try_move(Vector2i(0, 2)), "pas d'action pendant le placement")
	state.start()
	_check(state.active_fighter() == a, "le combat démarre")


func _test_class_data_files() -> void:
	for path in ["res://data/classes/guerrier.tres", "res://data/classes/druide.tres"]:
		var c: ClassData = load(path)
		_check(c != null and c.spells.size() == 4, "%s : 4 sorts" % path)
		if c:
			for s in c.spells:
				_check(s != null and not s.effects.is_empty(), "%s : sort avec effets" % path)


func _class_duel(a_cell: Vector2i, b_cell: Vector2i, rng_seed: int) -> CombatState:
	var grid := BattleGrid.new(MapLayouts.TEST_SIZE.x, MapLayouts.TEST_SIZE.y, MapLayouts.TEST_OBSTACLES)
	var state := CombatState.new(grid, rng_seed)
	state.add_fighter(Fighter.new(0, "G", 0, a_cell, load("res://data/classes/guerrier.tres")))
	state.add_fighter(Fighter.new(1, "D", 1, b_cell, load("res://data/classes/druide.tres")))
	state.start()
	return state


func _test_ai_takes_obvious_kill() -> void:
	var state := _class_duel(Vector2i(5, 5), Vector2i(6, 5), 3)
	state.fighters[1].hp = 15
	var action := AiBrain.next_action(state)
	_check(action.type == "cast" and action.cell == Vector2i(6, 5), "l'IA achève un ennemi au contact")


func _test_ai_vs_ai_finishes() -> void:
	for rng_seed in [1, 2, 3, 4, 5]:
		var state := _class_duel(MapLayouts.TEST_SPAWNS[0], MapLayouts.TEST_SPAWNS[1], rng_seed)
		var actions := 0
		while not state.is_over and state.turn_number <= 40 and actions < 2000:
			var action := AiBrain.next_action(state)
			actions += 1
			var ok := true
			match action.type:
				"move":
					ok = state.try_move(action.cell)
				"cast":
					ok = state.try_cast(action.spell, action.cell)
				_:
					state.end_turn()
			_check(ok, "action IA valide (%s)" % action.type)
			if not ok:
				state.end_turn()
		_check(state.is_over, "IA contre IA : combat terminé (graine %d, tour %d, PV %d/%d)" % [rng_seed, state.turn_number, state.fighters[0].hp, state.fighters[1].hp])
		print("  graine %d : gagnant %d au tour %d" % [rng_seed, state.winner_team, state.turn_number])
