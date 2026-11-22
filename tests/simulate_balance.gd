extends SceneTree
## Simule 80 combats IA contre IA (Guerrier vs Druide, placements aléatoires)
## pour mesurer l'équilibrage après une modification des classes ou des sorts :
##   godot --headless --path . -s res://tests/simulate_balance.gd

func _run(first_druid: bool, rng_seed: int, verbose: bool) -> int:
	var grid := BattleGrid.new(MapLayouts.TEST_SIZE.x, MapLayouts.TEST_SIZE.y, MapLayouts.TEST_OBSTACLES)
	var st := CombatState.new(grid, rng_seed)
	var g := Fighter.new(0, "G", 0, MapLayouts.TEST_SPAWNS[0], load("res://data/classes/guerrier.tres"))
	var d := Fighter.new(1, "D", 1, MapLayouts.TEST_SPAWNS[1], load("res://data/classes/druide.tres"))
	if first_druid:
		d.id = 0; g.id = 1
		st.add_fighter(d); st.add_fighter(g)
	else:
		st.add_fighter(g); st.add_fighter(d)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = rng_seed * 7919
	g.cell = MapLayouts.TEST_PLACEMENT[0][rnd.randi_range(0, 5)]
	d.cell = MapLayouts.TEST_PLACEMENT[1][rnd.randi_range(0, 5)]
	st.start()
	var n := 0
	while not st.is_over and st.turn_number <= 40 and n < 2000:
		n += 1
		var me := st.active_fighter()
		var a := AiBrain.next_action(st)
		if verbose:
			var desc: String = a.type
			if a.type == "cast": desc += " " + a.spell.spell_name + " " + str(a.cell)
			if a.type == "move": desc += " " + str(a.cell)
			print("T%d %s %s  [G %d PV %s | D %d PV %s]" % [st.turn_number, me.display_name, desc, g.hp, g.cell, d.hp, d.cell])
		match a.type:
			"move": st.try_move(a.cell)
			"cast": st.try_cast(a.spell, a.cell)
			_: st.end_turn()
	return st.winner_team
func _init() -> void:
	var wins := [0, 0]
	for s in range(1, 41):
		for fd in [false, true]:
			var w := _run(fd, s, false)
			if w >= 0: wins[w] += 1
	print("Victoires Guerrier / Druide sur 80 combats : ", wins, "  nuls/longs : ", 80 - wins[0] - wins[1])
	quit()
