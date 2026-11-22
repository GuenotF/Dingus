extends SceneTree
## Simule 80 combats IA contre IA (Guerrier vs Druide, placements aléatoires) sur chaque
## carte de maps/, pour mesurer l'équilibrage après une modification de classe, de sort ou de carte :
##   godot --headless --path . -s res://tests/simulate_balance.gd


func _run(map: BattleMap, first_druid: bool, rng_seed: int) -> int:
	var st := CombatState.new(map.build_grid(), rng_seed)
	var zones := map.placement_zones()
	var g := Fighter.new(0, "G", 0, zones[0][0], load("res://data/classes/guerrier.tres"))
	var d := Fighter.new(1, "D", 1, zones[1][0], load("res://data/classes/druide.tres"))
	if first_druid:
		d.id = 0
		g.id = 1
		st.add_fighter(d)
		st.add_fighter(g)
	else:
		st.add_fighter(g)
		st.add_fighter(d)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = rng_seed * 7919
	g.cell = zones[0][rnd.randi_range(0, zones[0].size() - 1)]
	d.cell = zones[1][rnd.randi_range(0, zones[1].size() - 1)]
	st.start()
	var n := 0
	while not st.is_over and st.turn_number <= 40 and n < 2000:
		n += 1
		var a := AiBrain.next_action(st)
		match a.type:
			"move":
				st.try_move(a.cell)
			"cast":
				st.try_cast(a.spell, a.cell)
			_:
				st.end_turn()
	return st.winner_team


func _init() -> void:
	for path in GameConfig_list_maps():
		var map: BattleMap = load(path).instantiate()
		var wins := [0, 0]
		var turns := 0
		for s in range(1, 41):
			for fd in [false, true]:
				var w := _run(map, fd, s)
				if w >= 0:
					wins[w] += 1
		print("%-10s Victoires Guerrier / Druide sur 80 combats : %s  nuls/longs : %d" % [map.map_name, wins, 80 - wins[0] - wins[1]])
		map.free()
	quit()


## Même liste que le menu (les autoloads ne sont pas chargés en mode script).
func GameConfig_list_maps() -> Array[String]:
	var result: Array[String] = []
	for entry in DirAccess.get_files_at("res://maps"):
		var file := entry.trim_suffix(".remap")
		if file.ends_with(".tscn"):
			result.append("res://maps/" + file)
	result.sort()
	return result
