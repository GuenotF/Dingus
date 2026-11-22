extends SceneTree
## Équilibrage optimisé : matrice de duels IA contre IA, calculée en parallèle, avec alertes chiffrées.
##   godot --headless --path . -s res://tests/balance_matrix.gd
## Options (après --) : personnage=X  carte=Y  parties=N  graine=K  processus=N  rapport=chemin.md  config=chemin.json
##   ex. godot --headless --path . -s res://tests/balance_matrix.gd -- personnage=Archer carte=Prairie
## Les seuils sont dans tests/balance_config.json (à modifier sans toucher au code).
## Code de sortie 1 s'il y a au moins une ALERTE (utile pour une vérification automatique).
##
## Lecture : « ALERTE » = hors de la fourchette avec certitude statistique (intervalle de confiance entièrement
## dehors) ; « attention » = hors fourchette mais l'échantillon ne permet pas de conclure (augmenter parties=).

var cfg := {}
var tasks: Array = []
var results: Array = []


func _init() -> void:
	var only_class := ""
	var only_map := ""
	var cfg_path := "res://tests/balance_config.json"
	var report_path := ""
	var workers := maxi(1, OS.get_processor_count())
	var shard := -1
	var out_path := ""
	var overrides := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"personnage": only_class = kv[1].to_lower()
			"carte": only_map = kv[1].to_lower()
			"parties": overrides["parties_par_cote"] = int(kv[1])
			"graine": overrides["graine_depart"] = int(kv[1])
			"processus": workers = maxi(1, int(kv[1]))
			"tranche": shard = int(kv[1])  # interne : numéro de tranche d'un processus fils
			"sortie": out_path = kv[1]  # interne
			"rapport": report_path = kv[1]
			"config": cfg_path = kv[1]
	cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	for k in overrides:
		cfg[k] = overrides[k]

	var classes: Array[ClassData] = []
	for file in DirAccess.get_files_at("res://data/classes"):
		if file.trim_suffix(".remap").ends_with(".tres"):
			classes.append(load("res://data/classes/" + file.trim_suffix(".remap")))
	var map_paths: Array[String] = []
	for file in DirAccess.get_files_at("res://maps"):
		if file.trim_suffix(".remap").ends_with(".tscn"):
			map_paths.append("res://maps/" + file.trim_suffix(".remap"))
	map_paths.sort()

	# Préparation (fil principal : les nœuds de carte ne sont pas thread-safe).
	var map_names: Array[String] = []
	var pairs: Array = []
	for path in map_paths:
		var map: BattleMap = load(path).instantiate()
		if only_map != "" and not map.map_name.to_lower().begins_with(only_map):
			map.free()
			continue
		var m_index := map_names.size()
		map_names.append(map.map_name)
		var zones := map.placement_zones()
		for i in classes.size():
			for j in range(i + 1, classes.size()):
				var a := classes[i]
				var b := classes[j]
				if only_class != "" and not (a.class_label.to_lower().begins_with(only_class) or b.class_label.to_lower().begins_with(only_class)):
					continue
				var pair_index := pairs.find([i, j])
				if pair_index < 0:
					pairs.append([i, j])
					pair_index = pairs.size() - 1
				for s in range(int(cfg.graine_depart), int(cfg.graine_depart) + int(cfg.parties_par_cote)):
					for a_first in [true, false]:
						var rnd := RandomNumberGenerator.new()
						rnd.seed = s * 7919
						tasks.append({
							"map": m_index, "pair": pair_index, "a": a, "b": b, "a_first": a_first, "seed": s,
							"grid": map.build_grid(),
							"a_cell": zones[0][rnd.randi_range(0, zones[0].size() - 1)],
							"b_cell": zones[1][rnd.randi_range(0, zones[1].size() - 1)],
						})
		map.free()
	results.resize(tasks.size())

	var started := Time.get_ticks_msec()
	if shard >= 0:
		# Processus fils : ne calcule que sa tranche (index modulo nombre de processus) et l'écrit en JSON.
		var mine := {}
		for i in range(shard, tasks.size(), workers):
			_run_task(i)
			mine[str(i)] = results[i]
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(mine))
		quit()
		return
	if workers > 1:
		_run_in_processes(workers, cfg_path, only_class, only_map)
	else:
		for i in tasks.size():
			_run_task(i)
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0

	var report := _report(classes, pairs, map_names, elapsed, workers)
	print(report)
	if report_path != "":
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f:
			f.store_string(report)
	quit(1 if _alerts > 0 else 0)


## Lance `workers` processus Godot (le calcul en fils d'exécution ralentit : état partagé), puis fusionne leurs résultats.
func _run_in_processes(workers: int, cfg_path: String, only_class: String, only_map: String) -> void:
	var pids: Array[int] = []
	var outs: Array[String] = []
	for k in workers:
		var out := OS.get_user_data_dir().path_join("balance_%d.json" % k)
		DirAccess.remove_absolute(out)
		outs.append(out)
		var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/balance_matrix.gd", "--",
			"tranche=%d" % k, "processus=%d" % workers, "sortie=" + out, "config=" + cfg_path,
			"parties=%d" % int(cfg.parties_par_cote), "graine=%d" % int(cfg.graine_depart)]
		if only_class != "":
			args.append("personnage=" + only_class)
		if only_map != "":
			args.append("carte=" + only_map)
		pids.append(OS.create_process(OS.get_executable_path(), args))
	for pid in pids:
		while OS.is_process_running(pid):
			OS.delay_msec(200)
	for out in outs:
		var data = JSON.parse_string(FileAccess.get_file_as_string(out))
		if data == null:
			printerr("Un processus fils a échoué : ", out)
			quit(2)
			return
		for key in data:
			var r: Dictionary = data[key]
			results[int(key)] = {"winner": int(r.winner), "turns": int(r.turns), "first_team": int(r.first_team)}
		DirAccess.remove_absolute(out)


func _run_task(index: int) -> void:
	var t: Dictionary = tasks[index]
	var st := CombatState.new(t.grid, t.seed)
	var a := Fighter.new(0, "A", 0, t.a_cell, t.a)
	var b := Fighter.new(1, "B", 1, t.b_cell, t.b)
	if t.a_first:
		st.add_fighter(a)
		st.add_fighter(b)
	else:
		b.id = 0
		a.id = 1
		st.add_fighter(b)
		st.add_fighter(a)
	st.start()
	var n := 0
	while not st.is_over and st.turn_number <= int(cfg.tours_limite) and n < 3000:
		n += 1
		var action := AiBrain.next_action(st)
		match action.type:
			"move":
				st.try_move(action.cell)
			"cast":
				st.try_cast(action.spell, action.cell)
			_:
				st.end_turn()
	# winner_team : équipe de A = 0, de B = 1 (ids de combattant et équipes suivent l'ordre d'ajout).
	var winner: int = st.winner_team
	results[index] = {"winner": winner, "turns": st.turn_number, "first_team": 0 if t.a_first else 1}


## Intervalle de Wilson à 95 % pour une proportion k/n, en pourcentage [bas, haut].
func _wilson(k: int, n: int) -> Array:
	if n == 0:
		return [0.0, 100.0]
	var z: float = cfg.confiance
	var p := float(k) / n
	var denom := 1.0 + z * z / n
	var centre := (p + z * z / (2.0 * n)) / denom
	var half := z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return [100.0 * (centre - half), 100.0 * (centre + half)]


var _alerts := 0


func _flag(low: float, high: float, value: float, lo_limit: float, hi_limit: float) -> String:
	if high < lo_limit or low > hi_limit:
		_alerts += 1
		return "ALERTE"
	if value < lo_limit or value > hi_limit:
		return "attention"
	return "ok"


func _report(classes: Array[ClassData], pairs: Array, map_names: Array[String], elapsed: float, workers: int) -> String:
	# Agrégation : par (carte, paire) puis par paire (toutes cartes confondues).
	var per := {} # "m|p" -> {wa, wb, turns, first, unfinished}
	var per_pair := {}
	for i in tasks.size():
		var t: Dictionary = tasks[i]
		var r: Dictionary = results[i]
		for key in ["%d|%d" % [t.map, t.pair], "|%d" % t.pair]:
			var d: Dictionary = per.get(key, {"wa": 0, "wb": 0, "turns": 0, "first": 0, "unfinished": 0})
			# winner est exprimé en équipe : équipe 0 = A, équipe 1 = B (les équipes ne dépendent pas de l'ordre de jeu).
			if r.winner < 0:
				d.unfinished += 1
			else:
				if r.winner == 0:
					d.wa += 1
				else:
					d.wb += 1
				d.turns += r.turns
				if r.winner == r.first_team:
					d.first += 1
			per[key] = d
	var lines: Array[String] = []
	lines.append("# Équilibrage — %d combats, %d processus, %.1f s" % [tasks.size(), workers, elapsed])
	lines.append("Seuils : victoires %d–%d %%, tours %.0f–%.0f, avantage du 1er joueur ≤ %d %%, sans fin ≤ %d (config : tests/balance_config.json)\n" % [
		cfg.victoires_min, cfg.victoires_max, cfg.tours_min, cfg.tours_max, cfg.premier_joueur_max, cfg.sans_fin_max])

	lines.append("## Matrice globale (victoires du premier nommé, toutes cartes)")
	lines.append("| Duel | Victoires | IC 95 % | Tours moy. | 1er joueur | Sans fin | Verdict |")
	lines.append("|---|---|---|---|---|---|---|")
	var class_wins := {}
	var class_games := {}
	for p in pairs.size():
		var d: Dictionary = per["|%d" % p]
		var a := classes[pairs[p][0]]
		var b := classes[pairs[p][1]]
		lines.append(_row("%s / %s" % [a.class_label, b.class_label], d, false))
		for c in [[a.class_label, d.wa], [b.class_label, d.wb]]:
			class_wins[c[0]] = class_wins.get(c[0], 0) + c[1]
			class_games[c[0]] = class_games.get(c[0], 0) + d.wa + d.wb
	lines.append("\n## Taux de victoire par personnage (contre tous les autres)")
	for name in class_wins:
		var n: int = class_games[name]
		var w: Array = _wilson(class_wins[name], n)
		lines.append("- %s : %d %% (IC %d–%d)" % [name, round(100.0 * class_wins[name] / max(1, n)), round(w[0]), round(w[1])])

	lines.append("\n## Détail par carte")
	for m in map_names.size():
		lines.append("\n### %s" % map_names[m])
		lines.append("| Duel | Victoires | IC 95 % | Tours moy. | 1er joueur | Sans fin | Verdict |")
		lines.append("|---|---|---|---|---|---|---|")
		for p in pairs.size():
			var d: Dictionary = per["%d|%d" % [m, p]]
			lines.append(_row("%s / %s" % [classes[pairs[p][0]].class_label, classes[pairs[p][1]].class_label], d))
	lines.append("\n**Bilan : %d alerte(s).**" % _alerts)
	return "\n".join(lines)


func _row(label: String, d: Dictionary, counted := true) -> String:
	var before := _alerts
	var finished: int = d.wa + d.wb
	var win_pct: float = 100.0 * d.wa / max(1, finished)
	var w := _wilson(d.wa, finished)
	var turns: float = float(d.turns) / max(1, finished)
	var first_pct: float = 100.0 * d.first / max(1, finished)
	var verdicts: Array[String] = []
	var v := _flag(w[0], w[1], win_pct, cfg.victoires_min, cfg.victoires_max)
	if v != "ok":
		verdicts.append("victoires %s" % v)
	if turns < cfg.tours_min or turns > cfg.tours_max:
		verdicts.append("durée attention")
	var fw := _wilson(d.first, finished)
	if fw[0] > cfg.premier_joueur_max:
		_alerts += 1
		verdicts.append("1er joueur ALERTE")
	elif first_pct > cfg.premier_joueur_max:
		verdicts.append("1er joueur attention")
	if d.unfinished > cfg.sans_fin_max:
		_alerts += 1
		verdicts.append("sans fin ALERTE")
	if not counted:
		_alerts = before  # la matrice globale résume ; seules les lignes par carte comptent dans le bilan
	return "| %s | %d %% | %d–%d | %.1f | %d %% | %d | %s |" % [
		label, round(win_pct), round(w[0]), round(w[1]), turns, round(first_pct), d.unfinished,
		"ok" if verdicts.is_empty() else ", ".join(verdicts)]
