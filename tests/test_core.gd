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
	_test_range_always_displayed()
	_test_demo_map()
	_test_water_rules()
	_test_lake_map()
	_test_spell_not_affecting_caster()
	_test_village_map()
	_test_cast_preview()
	_test_drain()
	_test_ai_sacrifice()
	_test_destructibles_grid()
	_test_destructibles_spells()
	_test_desert_destructibles()
	_test_ai_destructibles()
	_test_barricade_map()
	_test_destructibles_test_map()
	_test_steal_pa()
	_test_square_area()
	_test_smoke()
	_test_goblin_ai_finishes()
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
	# Façon Dofus : frôler le coin d'un obstacle en diagonale ne coupe pas la vue
	var corner: Array[Vector2i] = [Vector2i(1, 0)]
	var g2 := BattleGrid.new(6, 6, corner)
	_check(g2.has_line_of_sight(Vector2i(0, 0), Vector2i(2, 2)), "diagonale qui frôle un coin : visible")
	_check(g2.has_line_of_sight(Vector2i(2, 2), Vector2i(0, 0)), "idem dans l'autre sens")
	_check(g2.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 4)), "longue diagonale qui frôle un coin : visible")
	var on_diag: Array[Vector2i] = [Vector2i(1, 1)]
	_check(not BattleGrid.new(6, 6, on_diag).has_line_of_sight(Vector2i(0, 0), Vector2i(2, 2)), "obstacle sur la diagonale : bloqué")
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
	_check(state.range_display(heal).has(Vector2i(1, 0)), "soin : case vide quand même affichée dans la portée")
	_check(not state.try_cast(heal, Vector2i(1, 0)), "soin : lancer sur case vide refusé")
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
	# Chaque personnage de data/classes doit être complet (checklist de création de personnage).
	for file in DirAccess.get_files_at("res://data/classes"):
		var path := "res://data/classes/" + file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var c: ClassData = load(path)
		_check(c != null and c.spells.size() == 4, "%s : 4 sorts" % file)
		if c == null:
			continue
		_check(c.max_hp > 0 and c.max_pa > 0 and c.max_pm > 0, "%s : stats PV/PA/PM" % file)
		var sprites := c.sprites as CharacterSprites
		_check(sprites != null, "%s : a un skin (sprites)" % file)
		for base in ["idle", "walk", "hit", "die"]:
			_check(sprites != null and sprites.has_animation(base), "%s : animation %s" % [file, base])
		for s in c.spells:
			_check(s != null and not s.effects.is_empty(), "%s : %s a des effets" % [file, s.spell_name])
			_check(sprites != null and sprites.has_animation(s.animation), "%s : animation « %s » du sort %s" % [file, s.animation, s.spell_name])
			_check(s.projectile == null or s.projectile is EffectAnimation, "%s : projectile valide (%s)" % [file, s.spell_name])
			_check(s.impact == null or s.impact is EffectAnimation, "%s : impact valide (%s)" % [file, s.spell_name])


func _class_duel(a_cell: Vector2i, b_cell: Vector2i, rng_seed: int) -> CombatState:
	var grid := BattleGrid.new(MapLayouts.TEST_SIZE.x, MapLayouts.TEST_SIZE.y, MapLayouts.TEST_OBSTACLES)
	var state := CombatState.new(grid, rng_seed)
	state.add_fighter(Fighter.new(0, "G", 0, a_cell, load("res://data/classes/guerrier.tres")))
	state.add_fighter(Fighter.new(1, "M", 1, b_cell, load("res://data/classes/mage_feu.tres")))
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


func _test_range_always_displayed() -> void:
	# Bug signalé : Repousser (cible = combattant) n'affichait aucune portée sans ennemi au contact.
	var state := _class_duel(Vector2i(2, 7), Vector2i(12, 7), 1)
	for spell in state.active_fighter().spells:
		_check(not state.range_display(spell).is_empty(), "portée affichée : %s" % spell.spell_name)
	var push: SpellData = state.active_fighter().spells[2]
	_check(state.range_display(push).size() == 4 and state.cells_in_range(push).is_empty(), "Repousser : 4 cases affichées, aucune ciblable")


func _test_demo_map() -> void:
	# La carte de démo (dessinée avec le TileSet) doit rester jouable et cohérente.
	var map: BattleMap = load("res://maps/demo.tscn").instantiate()
	var grid := map.build_grid()
	_check(grid.width == 15 and grid.height == 15, "carte de démo : 15x15")
	var obs := map.obstacles()
	obs.sort()
	var expected := MapLayouts.TEST_OBSTACLES.duplicate()
	expected.sort()
	_check(obs == expected, "carte de démo : obstacles identiques à la carte de test (équilibrage)")
	var zones := map.placement_zones()
	for team in 2:
		_check(zones[team].size() == 6, "carte de démo : 6 cases de placement équipe %d" % team)
		for cell in zones[team]:
			_check(grid.is_walkable(cell), "case de placement libre %s" % cell)
	map.free()


func _test_water_rules() -> void:
	# Rivière verticale en x = 2 sur une grille 6x3.
	var river: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	var none: Array[Vector2i] = []
	var grid := BattleGrid.new(6, 3, none, river)
	_check(not grid.is_walkable(Vector2i(2, 1)), "eau : infranchissable")
	_check(grid.find_path(Vector2i(0, 1), Vector2i(4, 1)).is_empty(), "eau : aucun chemin à travers la rivière")
	_check(not grid.reachable_cells(Vector2i(1, 1), 5).has(Vector2i(3, 1)), "eau : l'autre rive est hors d'atteinte")
	_check(grid.has_line_of_sight(Vector2i(0, 1), Vector2i(4, 1)), "eau : la ligne de vue passe au-dessus")
	_check(not grid.is_obstacle(Vector2i(2, 1)), "eau : n'est pas un obstacle")

	var state := CombatState.new(grid, 5)
	var a := Fighter.new(0, "A", 0, Vector2i(0, 1))
	var b := Fighter.new(1, "B", 1, Vector2i(4, 1))
	var arrow := _spell(3, 2, 6, true, 10)
	var push_fx: Array[EffectData] = [EffectData.make(K.PUSH, 2)]
	var push := _effect_spell(1, 1, 1, push_fx)
	var dash_fx: Array[EffectData] = [EffectData.make(K.DASH, 0)]
	var dash := _effect_spell(1, 2, 3, dash_fx)
	dash.target_rule = SpellData.TargetRule.EMPTY
	dash.line_only = true
	dash.needs_line_of_sight = true
	a.spells = [arrow, push, dash]
	state.add_fighter(a)
	state.add_fighter(b)
	state.start()
	_check(state.try_cast(arrow, b.cell) and b.hp == 90, "eau : on tire par-dessus la rivière")
	_check(not state.cells_in_range(dash).has(Vector2i(2, 1)), "eau : impossible de bondir dans l'eau")
	_check(state.try_cast(dash, Vector2i(3, 1)) and a.cell == Vector2i(3, 1), "eau : le bond traverse la rivière")
	# A est maintenant en (3,1), B en (4,1) : on repousse B vers le bord droit (x = 5 libre, puis bord).
	_check(state.try_cast(push, b.cell) and b.cell == Vector2i(5, 1), "poussée normale sur la rive")

	# Poussée vers l'eau : la cible s'arrête au bord et subit la collision.
	state = CombatState.new(BattleGrid.new(6, 3, none, river), 5)
	a = Fighter.new(0, "A", 0, Vector2i(4, 1))
	b = Fighter.new(1, "B", 1, Vector2i(3, 1))
	a.spells = [push]
	state.add_fighter(a)
	state.add_fighter(b)
	state.start()
	state.try_cast(push, b.cell)
	_check(b.cell == Vector2i(3, 1) and b.hp == 100 - 2 * CombatState.PUSH_DAMAGE_PER_CELL, "eau : poussée bloquée au bord, avec collision")


func _test_lake_map() -> void:
	var map: BattleMap = load("res://maps/lac.tscn").instantiate()
	var grid := map.build_grid()
	_check(map.map_name == "Le lac", "carte du lac : nom")
	_check(grid.get_water().size() == 24, "carte du lac : 24 cases d'eau (obtenu %d)" % grid.get_water().size())
	var zones := map.placement_zones()
	for team in 2:
		for cell in zones[team]:
			_check(grid.is_walkable(cell), "lac : case de placement praticable %s" % cell)
	var path := grid.find_path(zones[0][0], zones[1][0])
	_check(not path.is_empty(), "lac : on peut rejoindre l'autre rive par un pont")
	var crosses_bridge := false
	for cell in path:
		if (cell.x == 7 or cell.x == 8):
			crosses_bridge = crosses_bridge or cell.y == 3 or cell.y == 11
	_check(crosses_bridge, "lac : le chemin passe par un pont")
	_check(grid.has_line_of_sight(Vector2i(5, 7), Vector2i(10, 7)), "lac : on voit par-dessus la rivière")
	_check(not grid.has_line_of_sight(Vector2i(5, 6), Vector2i(10, 6)), "lac : la pierre dans l'eau coupe la vue")
	map.free()
	var all_maps := DirAccess.get_files_at("res://maps")
	_check(all_maps.has("demo.tscn") and all_maps.has("lac.tscn"), "les deux cartes sont dans maps/")



func _test_spell_not_affecting_caster() -> void:
	# Nova de flammes : zone en croix autour du lanceur, sans le toucher, et repousse de 1.
	var nova: SpellData = load("res://data/spells/feu_nova.tres")
	var state := CombatState.new(BattleGrid.new(7, 7), 9)
	var mage := Fighter.new(0, "M", 0, Vector2i(3, 3))
	var foe := Fighter.new(1, "G", 1, Vector2i(4, 3))
	mage.spells = [nova]
	state.add_fighter(mage)
	state.add_fighter(foe)
	state.start()
	_check(state.cells_in_range(nova).keys() == [Vector2i(3, 3)], "nova : se lance sur sa propre case")
	_check(state.try_cast(nova, mage.cell), "nova lancée")
	_check(mage.hp == 100, "nova : le lanceur n'est pas touché")
	var push: int = nova.effects[1].min_value
	_check(foe.hp <= 100 - nova.effects[0].min_value and foe.cell == Vector2i(4 + push, 3), "nova : l'ennemi adjacent est touché et repoussé")


func _test_village_map() -> void:
	var map: BattleMap = load("res://maps/village.tscn").instantiate()
	var grid := map.build_grid()
	_check(map.map_name == "Place du village", "village : nom")
	_check(grid.width == 15 and grid.height == 15, "village : 15x15")
	_check(map.ground_detail() != null, "village : calque SolDetail présent")
	_check(grid.is_obstacle(Vector2i(7, 7)), "village : le puits bloque")
	_check(not grid.is_obstacle(Vector2i(3, 1)), "village : les fleurs se traversent")
	var zones := map.placement_zones()
	for team in 2:
		_check(zones[team].size() == 6, "village : 6 cases de départ équipe %d" % team)
		for cell in zones[team]:
			_check(grid.is_walkable(cell), "village : case de départ praticable %s" % cell)
	_check(not grid.find_path(zones[0][0], zones[1][0]).is_empty(), "village : les deux camps peuvent se rejoindre")
	map.free()


func _test_cast_preview() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.DAMAGE, 5, 7), EffectData.make(K.PUSH, 2)]
	var spell := _effect_spell(1, 1, 3, fx)
	var walls: Array[Vector2i] = [Vector2i(4, 1)]
	var state := _duel([spell], Vector2i(1, 1), Vector2i(2, 1), walls)
	var preview := state.preview_cast(spell, Vector2i(2, 1))
	_check(preview.size() == 1 and preview[0].fighter == state.fighters[1], "aperçu : une cible")
	var bump := CombatState.PUSH_DAMAGE_PER_CELL
	_check(preview[0].damage_min == 5 + bump and preview[0].damage_max == 7 + bump, "aperçu : dégâts + collision")
	_check(state.fighters[1].hp == 100 and state.fighters[1].cell == Vector2i(2, 1), "aperçu sans effet sur le combat")
	_check(state.preview_cast(spell, Vector2i(5, 5)).is_empty(), "aperçu vide hors portée")


func _test_drain() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.DRAIN, 20)]
	var spell := _effect_spell(1, 1, 1, fx)
	var state := _duel([spell], Vector2i(1, 1), Vector2i(2, 1))
	var me := state.active_fighter()
	var foe := state.fighters[1]
	me.hp = 50
	var preview := state.preview_cast(spell, foe.cell)
	var gain := int(20 * CombatState.DRAIN_RATIO)
	var mine: Array = preview.filter(func(p: Dictionary) -> bool: return p.fighter == me)
	_check(mine.size() == 1 and mine[0].heal_min == gain and mine[0].heal_max == gain, "vol de vie : aperçu du soin du lanceur")
	_check(state.try_cast(spell, foe.cell), "vol de vie : lancer")
	_check(foe.hp == 80 and me.hp == 50 + gain, "vol de vie : dégâts à la cible, soin au lanceur")
	# Plafonné aux PV max du lanceur, et rien sur une cible qui n'a plus de PV à perdre.
	me.hp = me.max_hp - 3
	state.try_cast(spell, foe.cell)
	_check(me.hp == me.max_hp, "vol de vie : plafonné aux PV max")
	foe.hp = 4
	me.hp = 50
	state.try_cast(spell, foe.cell)
	_check(not foe.is_alive() and me.hp == 50 + int(4 * CombatState.DRAIN_RATIO), "vol de vie : limité aux PV réellement retirés")


func _test_ai_sacrifice() -> void:
	# Un sort qui coûte des PV pour gagner des PA n'est lancé que si l'on peut frapper ensuite.
	var pact := SpellData.new()
	pact.pa_cost = 1
	pact.range_min = 0
	pact.range_max = 0
	var pact_fx: Array[EffectData] = [EffectData.make(K.DAMAGE, 12), EffectData.make(K.MOD_PA, 3)]
	pact.effects = pact_fx
	var hit := _spell(3, 1, 1, false, 15)
	hit.casts_per_turn = 2
	var far := _duel([pact, hit], Vector2i(0, 0), Vector2i(9, 9))
	_check(AiBrain.score_cast(far, far.active_fighter(), Vector2i(0, 0), pact, Vector2i(0, 0)) < AiBrain.MIN_CAST_SCORE, "IA : pas de sacrifice loin de l'ennemi")
	var near := _duel([pact, hit], Vector2i(0, 0), Vector2i(1, 0))
	_check(AiBrain.score_cast(near, near.active_fighter(), Vector2i(0, 0), pact, Vector2i(0, 0)) > 15.0, "IA : sacrifice avant de frapper au contact")
	var weak := near.active_fighter()
	weak.hp = 30
	_check(AiBrain.score_cast(near, weak, Vector2i(0, 0), pact, Vector2i(0, 0)) < 0.0, "IA : pas de sacrifice quand les PV sont bas")


func _test_destructibles_grid() -> void:
	var grid := BattleGrid.new(8, 3)
	grid.add_destructible(Vector2i(3, 1), 50)
	_check(grid.is_obstacle(Vector2i(3, 1)) and grid.is_destructible(Vector2i(3, 1)), "destructible : bloque comme un obstacle")
	_check(grid.destructible_hp(Vector2i(3, 1)) == 50 and grid.destructible_max_hp(Vector2i(3, 1)) == 50, "destructible : PV de départ")
	_check(not grid.has_line_of_sight(Vector2i(0, 1), Vector2i(6, 1)), "destructible intact : coupe la ligne de vue")
	_check(grid.damage_destructible(Vector2i(3, 1), 20) == 20 and grid.destructible_hp(Vector2i(3, 1)) == 30, "dégâts partiels")
	_check(grid.is_obstacle(Vector2i(3, 1)), "encore debout à 30 PV")
	_check(grid.damage_destructible(Vector2i(3, 1), 500) == 30, "les PV perdus sont plafonnés aux PV restants")
	_check(not grid.is_obstacle(Vector2i(3, 1)) and not grid.is_destructible(Vector2i(3, 1)), "détruit : plus d'obstacle")
	_check(grid.is_walkable(Vector2i(3, 1)), "détruit : case praticable")
	_check(grid.has_line_of_sight(Vector2i(0, 1), Vector2i(6, 1)), "détruit : ligne de vue dégagée")
	_check(not grid.find_path(Vector2i(0, 1), Vector2i(6, 1)).is_empty(), "détruit : chemin trouvé à travers la case")
	_check(grid.damage_destructible(Vector2i(3, 1), 10) == 0, "plus de dégâts sur une case détruite")
	var walls: Array[Vector2i] = [Vector2i(5, 1)]
	var solid := BattleGrid.new(8, 3, walls)
	_check(solid.damage_destructible(Vector2i(5, 1), 99) == 0 and solid.is_obstacle(Vector2i(5, 1)), "un obstacle ordinaire est indestructible")


func _test_destructibles_spells() -> void:
	var hit := _spell(2, 1, 6, true, 30, 5)
	var state := _duel([hit], Vector2i(0, 1), Vector2i(9, 9))
	state.grid.add_destructible(Vector2i(3, 1), 70)
	var walls: Array[Vector2i] = [Vector2i(5, 1)]
	for cell in walls:
		state.grid.add_obstacle(cell)
	var zone := state.cells_in_range(hit)
	_check(zone.has(Vector2i(3, 1)) and zone[Vector2i(3, 1)], "un destructible visible est une cible valide")
	_check(not zone.has(Vector2i(5, 1)), "un obstacle ordinaire n'est pas ciblable")
	var preview := state.preview_obstacles(hit, Vector2i(3, 1))
	_check(preview.size() == 1 and preview[0].damage_max == 30 and preview[0].hp == 70, "aperçu des dégâts sur le destructible")
	var log: Array = []
	state.obstacle_damaged.connect(func(cell: Vector2i, amount: int, left: int) -> void: log.append(["dmg", cell, amount, left]))
	state.obstacle_destroyed.connect(func(cell: Vector2i) -> void: log.append(["destroyed", cell]))
	_check(state.try_cast(hit, Vector2i(3, 1)), "sort lancé sur un destructible")
	_check(state.grid.destructible_hp(Vector2i(3, 1)) == 40, "70 - 30 = 40 PV")
	state.try_cast(hit, Vector2i(3, 1))
	state.try_cast(hit, Vector2i(3, 1))
	_check(not state.grid.is_obstacle(Vector2i(3, 1)), "détruit au 3e coup")
	_check(log.size() == 4 and log[2][0] == "dmg" and log[3] == ["destroyed", Vector2i(3, 1)], "signaux : 3 dégâts puis la destruction")
	_check(state.fighters[1].hp == 100, "aucun combattant touché au passage")
	_check(state.cells_in_range(hit).has(Vector2i(5, 1)) == false, "le mur ordinaire reste intouchable")

	# Un sort qui ne fait pas de dégâts, ou qui exige une case libre, ne vise pas les destructibles.
	var heal: Array[EffectData] = [EffectData.make(EffectData.Kind.HEAL, 10)]
	var heal_spell := _effect_spell(1, 1, 5, heal)
	var s2 := _duel([heal_spell], Vector2i(0, 1), Vector2i(9, 9))
	s2.grid.add_destructible(Vector2i(2, 1), 40)
	_check(not s2.cells_in_range(heal_spell).has(Vector2i(2, 1)), "un soin ne vise pas un destructible")
	var empty_rule := _spell(1, 1, 5, false, 10)
	empty_rule.target_rule = SpellData.TargetRule.EMPTY
	var s3 := _duel([empty_rule], Vector2i(0, 1), Vector2i(9, 9))
	s3.grid.add_destructible(Vector2i(2, 1), 40)
	_check(not s3.cells_in_range(empty_rule).has(Vector2i(2, 1)), "« case libre » exclut les destructibles")

	# Zone en croix : touche le combattant ET le destructible voisin.
	var cross := _spell(1, 1, 6, false, 25, 5)
	cross.area = SpellData.AreaShape.CROSS
	cross.area_size = 1
	var s4 := _duel([cross], Vector2i(0, 1), Vector2i(4, 1))
	s4.grid.add_destructible(Vector2i(4, 2), 60)
	s4.try_cast(cross, Vector2i(4, 1))
	_check(s4.fighters[1].hp == 75 and s4.grid.destructible_hp(Vector2i(4, 2)) == 35, "zone : combattant et destructible touchés")

	# Poussée : le choc contre un destructible l'abîme aussi.
	var push_fx: Array[EffectData] = [EffectData.make(EffectData.Kind.PUSH, 2)]
	var push := _effect_spell(1, 1, 1, push_fx)
	var s5 := _duel([push], Vector2i(1, 1), Vector2i(2, 1))
	s5.grid.add_destructible(Vector2i(4, 1), 60)
	s5.try_cast(push, Vector2i(2, 1))
	var expected := CombatState.PUSH_DAMAGE_PER_CELL
	_check(s5.fighters[1].cell == Vector2i(3, 1) and s5.fighters[1].hp == 100 - expected, "poussée stoppée par le destructible")
	_check(s5.grid.destructible_hp(Vector2i(4, 1)) == 60 - expected, "le choc abîme le destructible")


func _test_desert_destructibles() -> void:
	var map: BattleMap = load("res://maps/desert.tscn").instantiate()
	var grid := map.build_grid()
	var destructibles := map.destructibles()
	var columns := 0
	var rocks := 0
	for cell in destructibles:
		_check(grid.is_obstacle(cell) and grid.is_destructible(cell), "désert : destructible %s est aussi un obstacle" % cell)
		if destructibles[cell] == 80:
			columns += 1
		elif destructibles[cell] == 120:
			rocks += 1
	_check(columns == 8, "désert : 8 colonnes destructibles (80 PV), trouvé %d" % columns)
	_check(rocks > 0, "désert : des rochers destructibles (120 PV)")
	_check(not destructibles.has(Vector2i(7, 7)), "désert : le sphinx est indestructible")
	_check(not destructibles.has(Vector2i(7, 5)) and not destructibles.has(Vector2i(7, 9)), "désert : les obélisques sont indestructibles")
	_check(grid.get_obstacles().size() == 25, "désert : toujours 25 obstacles")
	map.free()


## Banc d'essai : chaque destructible animé (9 du village, 5 du désert) est bien présent, avec ses PV et son animation.
func _test_destructibles_test_map() -> void:
	var map: BattleMap = load("res://maps/test_destructibles.tscn").instantiate()
	var grid := map.build_grid()
	var zones := map.placement_zones()
	_check(zones.size() == 2 and zones[0].size() == 9 and zones[1].size() == 9, "banc d'essai : 9 cases de placement par équipe")
	var destructibles := map.destructibles()
	_check(destructibles.size() == 14, "banc d'essai : 14 destructibles (%d)" % destructibles.size())
	for cell in destructibles:
		_check(grid.is_destructible(cell) and destructibles[cell] > 0, "banc d'essai : %s destructible" % cell)
	# Chaque destructible a une animation d'effondrement.
	for layer: TileMapLayer in [map.decor(), map.ground_detail()]:
		for cell in layer.get_used_cells():
			if not destructibles.has(cell):
				continue # arbres, palmiers, touffes : animés par le vent, pas destructibles
			var anim := DestructionAnims.sheet_for(layer.tile_set.resource_path, layer.get_cell_atlas_coords(cell))
			_check(anim != "", "banc d'essai : %s a une animation" % cell)
	map.free()


func _test_barricade_map() -> void:
	var map: BattleMap = load("res://maps/barricade.tscn").instantiate()
	var grid := map.build_grid()
	var zones := map.placement_zones()
	_check(zones.size() == 2 and zones[0].size() == 9 and zones[1].size() == 9, "barrage : 9 cases de placement par équipe")
	var destructibles := map.destructibles()
	_check(destructibles.size() > 10, "barrage : des destructibles (%d)" % destructibles.size())
	for y in 3:
		_check(grid.is_obstacle(Vector2i(7, y)) and not grid.is_destructible(Vector2i(7, y)), "barrage : mur de pierre (7,%d) indestructible" % y)
	_check(not grid.is_obstacle(Vector2i(7, 7)), "barrage : l'ouverture centrale est libre")
	_check(grid.is_destructible(Vector2i(7, 4)), "barrage : la palissade (7,4) est destructible")
	# Une ligne de tir à travers la palissade est coupée, puis rétablie une fois la palissade détruite.
	var from := Vector2i(6, 4)
	var to := Vector2i(8, 4)
	_check(not grid.has_line_of_sight(from, to), "barrage : la palissade bloque la vue")
	grid.damage_destructible(Vector2i(7, 4), 999)
	_check(grid.has_line_of_sight(from, to), "barrage : la vue est ouverte une fois la palissade détruite")
	# Les deux camps peuvent se rejoindre (par l'ouverture).
	var path := grid.find_path(Vector2i(1, 7), Vector2i(13, 7))
	_check(not path.is_empty(), "barrage : un chemin relie les deux camps")
	map.free()


func _test_ai_destructibles() -> void:
	# Couloir : seul un destructible sépare les deux combattants, l'IA doit le casser pour tirer.
	var hit := _spell(2, 1, 12, true, 30, 5)
	var state := CombatState.new(BattleGrid.new(10, 1), 7)
	var a := Fighter.new(0, "A", 0, Vector2i(0, 0))
	var b := Fighter.new(1, "B", 1, Vector2i(9, 0))
	var spells: Array[SpellData] = [hit]
	a.spells = spells
	b.spells = spells
	state.add_fighter(a)
	state.add_fighter(b)
	state.grid.add_destructible(Vector2i(4, 0), 60)
	state.start()
	var action := _first_ai_cast(state)
	_check(action.get("type") == "cast" and action.cell == Vector2i(4, 0), "IA : casse le destructible qui masque l'ennemi (couloir)")
	# Un obstacle ordinaire au même endroit : aucune idée de tir inutile.
	var walls: Array[Vector2i] = [Vector2i(4, 0)]
	var plain := CombatState.new(BattleGrid.new(10, 1, walls), 7)
	var c := Fighter.new(0, "A", 0, Vector2i(0, 0))
	var d := Fighter.new(1, "B", 1, Vector2i(9, 0))
	c.spells = spells
	d.spells = spells
	plain.add_fighter(c)
	plain.add_fighter(d)
	plain.start()
	var plain_cast := _first_ai_cast(plain)
	_check(plain_cast.is_empty() or plain_cast.cell != Vector2i(4, 0), "IA : ne vise pas un obstacle indestructible")
	# Un destructible qui ne gêne personne est ignoré, l'ennemi visible reste la priorité.
	var open := CombatState.new(BattleGrid.new(10, 3), 7)
	var e := Fighter.new(0, "A", 0, Vector2i(0, 1))
	var f := Fighter.new(1, "B", 1, Vector2i(6, 1))
	e.spells = spells
	f.spells = spells
	open.add_fighter(e)
	open.add_fighter(f)
	open.grid.add_destructible(Vector2i(3, 0), 60)
	open.start()
	var shot := _first_ai_cast(open)
	_check(shot.get("type") == "cast" and shot.cell == Vector2i(6, 1), "IA : tire sur l'ennemi visible plutôt que sur un obstacle hors de propos")
	# Le combat finit : l'IA enchaîne coups sur l'obstacle puis tire (aucune boucle infinie).
	var guard := 0
	while not state.is_over and guard < 200:
		var act := AiBrain.next_action(state)
		match act.type:
			"cast":
				state.try_cast(act.spell, act.cell)
			"move":
				state.try_move(act.cell)
			_:
				state.end_turn()
		guard += 1
	_check(state.is_over, "IA : combat dans le couloir terminé après destruction (%d actions)" % guard)


## Joue les déplacements de l'IA jusqu'à son premier sort et renvoie cette action (vide si elle ne lance rien).
func _first_ai_cast(state: CombatState) -> Dictionary:
	for i in 10:
		var action := AiBrain.next_action(state)
		match action.type:
			"cast":
				return action
			"move":
				state.try_move(action.cell)
			_:
				return {}
	return {}


# --- Gobelin : vol de PA, zone carrée, fumée -------------------------------------

func _test_steal_pa() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.STEAL_PA, 1, EffectData.SAME_AS_MIN, 1)]
	var steal := _effect_spell(3, 1, 1, fx)
	var state := _duel([steal], Vector2i(0, 0), Vector2i(1, 0))
	var a := state.fighters[0]
	var b := state.fighters[1]
	_check(state.try_cast(steal, b.cell), "vol de PA lancé")
	_check(a.pa == 6 - 3 + 1, "le lanceur gagne le PA volé tout de suite")
	_check(b.statuses.size() == 1, "malus de PA posé sur la victime")
	state.end_turn()
	_check(b.pa == 5, "la victime a 1 PA de moins à son tour")
	state.end_turn()
	_check(b.statuses.is_empty(), "le malus expire après le tour de la victime")
	state.end_turn()
	_check(b.pa == 6, "PA rendus au tour suivant")


func _test_square_area() -> void:
	var s := SpellData.new()
	s.area = SpellData.AreaShape.SQUARE
	s.area_size = 1
	var cells := s.affected_cells(Vector2i(4, 4))
	_check(cells.size() == 9 and cells.has(Vector2i(3, 3)) and cells.has(Vector2i(5, 5)) and cells.has(Vector2i(4, 4)), "zone carrée 3×3 centrée sur la case visée")
	_check(not cells.has(Vector2i(6, 4)) and not cells.has(Vector2i(4, 2)), "zone carrée : rien au-delà du rayon")


func _test_smoke() -> void:
	var fx: Array[EffectData] = [EffectData.make(K.SMOKE, 0)]
	var smoke := _effect_spell(3, 2, 6, fx)
	smoke.area = SpellData.AreaShape.SQUARE
	smoke.area_size = 1
	smoke.cooldown = 3
	var arrow := _spell(1, 1, 8, true, 10, 5)
	var state := _duel([smoke, arrow], Vector2i(0, 1), Vector2i(5, 1))
	var a := state.fighters[0]
	var b := state.fighters[1]
	_check(state.try_cast(smoke, Vector2i(4, 1)), "fumigène lancé")
	_check(state.is_smoked(Vector2i(3, 0)) and state.is_smoked(Vector2i(5, 2)) and not state.is_smoked(Vector2i(2, 1)), "nuage 3×3 centré sur la case visée")
	_check(state.is_smoked(b.cell), "B est dans la fumée")
	_check(a.cooldown_left(smoke) == 3, "recharge du fumigène : 3 tours")
	# Depuis l'extérieur : on voit jusqu'au bord du nuage, pas à travers.
	var zone := state.cells_in_range(arrow)
	_check(zone[Vector2i(2, 1)] and zone[Vector2i(3, 1)], "hors du nuage : on voit la case d'avant et le bord du nuage")
	_check(not zone[Vector2i(5, 1)], "le nuage fait écran derrière lui")
	_check(not state.smoke_blocks_view(Vector2i(5, 1), Vector2i(5, 1)), "on peut toujours viser sa propre case")
	# Dedans : ralenti et aveugle.
	state.end_turn()
	_check(b.pm == 1 and b.statuses.size() == 1, "commencer son tour dans la fumée : −2 PM")
	var blind := state.cells_in_range(arrow)
	var any_visible := false
	for cell in blind:
		if blind[cell]:
			any_visible = true
	_check(not any_visible, "dans la fumée : aucune case visible")
	_check(not state.can_cast_at(arrow, Vector2i(4, 1)), "dans la fumée : même une case voisine est refusée")
	# Le nuage dure un tour : il disparaît au début du tour de son lanceur.
	state.end_turn()
	_check(state.smokes.is_empty() and not state.is_smoked(b.cell), "la fumée disparaît au début du tour du lanceur")
	_check(a.pm == 3, "le lanceur n'est pas ralenti par sa propre fumée")
	state.end_turn()
	_check(b.pm == 3 and b.statuses.is_empty(), "le ralentissement ne dure qu'un tour")


func _test_goblin_ai_finishes() -> void:
	for opponent in ["guerrier", "archer", "mage_feu", "chevalier_maudit"]:
		var grid := BattleGrid.new(MapLayouts.TEST_SIZE.x, MapLayouts.TEST_SIZE.y, MapLayouts.TEST_OBSTACLES)
		var state := CombatState.new(grid, 5)
		state.add_fighter(Fighter.new(0, "G", 0, MapLayouts.TEST_SPAWNS[0], load("res://data/classes/gobelin.tres")))
		state.add_fighter(Fighter.new(1, "O", 1, MapLayouts.TEST_SPAWNS[1], load("res://data/classes/%s.tres" % opponent)))
		state.start()
		var actions := 0
		var smoked := false
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
			_check(ok, "gobelin contre %s : action IA valide (%s)" % [opponent, action.type])
			if not ok:
				state.end_turn()
			smoked = smoked or not state.smokes.is_empty()
		_check(state.is_over, "gobelin contre %s : combat terminé (tour %d)" % [opponent, state.turn_number])
		print("  gobelin contre %s : gagnant %d au tour %d, fumée utilisée : %s" % [opponent, state.winner_team, state.turn_number, smoked])
