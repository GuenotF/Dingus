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
