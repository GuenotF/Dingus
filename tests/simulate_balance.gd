extends SceneTree
## Équilibrage (options : -- personnage=X adversaire=Y carte=Z parties=N graine=K) : simule 80 combats IA contre IA pour chaque paire de personnages,
## sur chaque carte de maps/ (placements aléatoires, chacun commence une fois sur deux).
##   godot --headless --path . -s res://tests/simulate_balance.gd
## Filtres optionnels (après --) : un personnage et/ou une carte (début du nom suffit), ex.
##   godot --headless --path . -s res://tests/simulate_balance.gd -- personnage=Archer carte=Prairie
## Critères visés : 40 à 60 % de victoires, 6 à 12 tours en moyenne, aucun combat sans fin.

const GAMES_PER_SIDE := 40


func _run(map: BattleMap, a_class: ClassData, b_class: ClassData, a_first: bool, rng_seed: int) -> Dictionary:
	var st := CombatState.new(map.build_grid(), rng_seed)
	var zones := map.placement_zones()
	var a := Fighter.new(0, "A", 0, zones[0][0], a_class)
	var b := Fighter.new(1, "B", 1, zones[1][0], b_class)
	if a_first:
		st.add_fighter(a)
		st.add_fighter(b)
	else:
		b.id = 0
		a.id = 1
		st.add_fighter(b)
		st.add_fighter(a)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = rng_seed * 7919
	a.cell = zones[0][rnd.randi_range(0, zones[0].size() - 1)]
	b.cell = zones[1][rnd.randi_range(0, zones[1].size() - 1)]
	st.start()
	var n := 0
	while not st.is_over and st.turn_number <= 40 and n < 3000:
		n += 1
		var action := AiBrain.next_action(st)
		match action.type:
			"move":
				st.try_move(action.cell)
			"cast":
				st.try_cast(action.spell, action.cell)
			_:
				st.end_turn()
	return {"winner": st.winner_team, "turns": st.turn_number, "first_team": 0 if a_first else 1}


func _init() -> void:
	var only_class := ""
	var only_map := ""
	var only_opponent := ""
	var games := GAMES_PER_SIDE
	var first_seed := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("personnage="):
			only_class = arg.split("=")[1].to_lower()
		elif arg.begins_with("carte="):
			only_map = arg.split("=")[1].to_lower()
		elif arg.begins_with("parties="):
			games = int(arg.split("=")[1])
		elif arg.begins_with("graine="):
			first_seed = int(arg.split("=")[1])
		elif arg.begins_with("adversaire="):
			only_opponent = arg.split("=")[1].to_lower()
	var classes: Array[ClassData] = []
	for file in DirAccess.get_files_at("res://data/classes"):
		if file.trim_suffix(".remap").ends_with(".tres"):
			classes.append(load("res://data/classes/" + file.trim_suffix(".remap")))
	var maps: Array[String] = []
	for file in DirAccess.get_files_at("res://maps"):
		if file.trim_suffix(".remap").ends_with(".tscn"):
			maps.append("res://maps/" + file.trim_suffix(".remap"))
	maps.sort()
	for i in classes.size():
		for j in range(i + 1, classes.size()):
			var a := classes[i]
			var b := classes[j]
			if only_class != "" and not (a.class_label.to_lower().begins_with(only_class) or b.class_label.to_lower().begins_with(only_class)):
				continue
			if only_opponent != "" and not (a.class_label.to_lower().begins_with(only_opponent) or b.class_label.to_lower().begins_with(only_opponent)):
				continue
			print("\n%s contre %s" % [a.class_label, b.class_label])
			for path in maps:
				var map: BattleMap = load(path).instantiate()
				if only_map != "" and not map.map_name.to_lower().begins_with(only_map):
					map.free()
					continue
				var wins := [0, 0]
				var first_wins := 0
				var turns := 0
				var unfinished := 0
				for s in range(first_seed, first_seed + games):
					for a_first in [true, false]:
						var r := _run(map, a, b, a_first, s)
						if r.winner >= 0:
							wins[r.winner] += 1
							turns += r.turns
							if r.winner == r.first_team:
								first_wins += 1
						else:
							unfinished += 1
				var finished: int = wins[0] + wins[1]
				print("  %-9s %s %d%% - %s %d%%   tours moy. %.1f   1er joueur gagne %d%%   sans fin %d" % [
					map.map_name, a.class_label, 100 * wins[0] / max(1, finished), b.class_label, 100 * wins[1] / max(1, finished),
					float(turns) / max(1, finished), 100 * first_wins / max(1, finished), unfinished])
				map.free()
	quit()
