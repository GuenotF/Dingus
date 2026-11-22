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
	s.damage_min = dmg
	s.damage_max = dmg
	s.casts_per_turn = casts
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
