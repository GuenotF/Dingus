extends Node2D
## Scène de combat : assemble la logique (core), l'affichage (view) et les contrôleurs
## (joueur humain ou IA), puis gère les entrées.
## Contrôles : survol = aperçu, clic gauche = se déplacer / lancer le sort choisi / se placer,
## 1-4 = choisir un sort, clic droit / Échap = annuler, Espace = fin du tour / prêt.

const AI_STEP_DELAY := 0.35
const AI_MAX_ACTIONS := 30
const ZONE_COLORS: Array[Color] = [Color(0.95, 0.35, 0.3, 0.45), Color(0.3, 0.55, 1.0, 0.45)]

var state: CombatState
var map: BattleMap
var board: BoardView
var entities: Node2D
var hud: Hud
var fighter_views: Dictionary = {} # Fighter.id -> FighterView
var selected_spell: SpellData = null
var busy := false # vrai pendant une animation : on ignore les entrées
var placing_index := 0 # combattant en cours de placement
## Pendant qu'un projectile vole, les conséquences du sort (dégâts, poussées, mort...)
## sont mises en attente et jouées à l'impact.
var _deferring := false
var _deferred: Array[Callable] = []


func _ready() -> void:
	_build_combat()
	_build_scene()
	state.fighter_placed.connect(_on_fighter_placed)
	state.turn_started.connect(_on_turn_started)
	state.fighter_moved.connect(_on_fighter_moved)
	state.spell_cast.connect(_on_spell_cast)
	state.fighter_damaged.connect(_on_fighter_damaged)
	state.fighter_healed.connect(_on_fighter_healed)
	state.fighter_displaced.connect(_on_fighter_displaced)
	state.status_changed.connect(_on_status_changed)
	state.fighter_died.connect(_on_fighter_died)
	state.combat_ended.connect(_on_combat_ended)
	state.begin_placement()
	_begin_placement_of(0)


func _build_combat() -> void:
	# La carte (dessinée dans l'éditeur) fournit la grille, les obstacles et les zones de placement.
	map = load(GameConfig.map_path).instantiate()
	state = CombatState.new(map.build_grid())
	state.placement_zones = map.placement_zones()
	for i in 2:
		var zone: Array = state.placement_zones[i]
		var start: Vector2i = zone[0] if not zone.is_empty() else Vector2i(i * (state.grid.width - 1), 0)
		var f := Fighter.new(i, GameConfig.player_name(i), i, start, GameConfig.class_for(i))
		state.add_fighter(f)


func is_ai(fighter: Fighter) -> bool:
	return fighter != null and GameConfig.player_is_ai[fighter.id]


func _build_scene() -> void:
	RenderingServer.set_default_clear_color(Color("1d2128"))

	# Fond : dégradé teinté par la carte, socle sous le plateau, particules d'ambiance.
	var background := BackgroundView.new()
	add_child(background)
	background.setup(state.grid, map)

	# Carte : les tuiles sont alignées sur la grille du jeu (centre de la case (0, 0) en (0, 0)).
	add_child(map)
	map.position = -map.ground().map_to_local(Vector2i.ZERO) * map.scale
	map.placement().hide() # les zones sont affichées par le plateau pendant le placement

	board = BoardView.new()
	board.draw_ground = false # le sol vient de la carte ; le plateau ne dessine que la grille et les surbrillances
	add_child(board)
	board.setup(state.grid)

	# Décor et personnages dans le même conteneur trié par Y : la profondeur est automatique.
	entities = Node2D.new()
	entities.y_sort_enabled = true
	entities.z_index = 2 # au-dessus des effets au sol (EffectView.Z_GROUND)
	add_child(entities)

	var decor := map.decor()
	map.remove_child(decor)
	entities.add_child(decor)
	decor.scale = map.scale
	decor.position = map.position
	decor.texture_filter = map.texture_filter # pixel art net ou rendu lissé, selon la carte

	for f in state.fighters:
		var view := FighterView.new()
		entities.add_child(view)
		view.setup(f)
		fighter_views[f.id] = view

	var camera := Camera2D.new()
	var last := Vector2i(state.grid.width - 1, state.grid.height - 1)
	camera.position = Iso.cell_to_world(last) * 0.5 + Vector2(0, 20)
	add_child(camera)

	hud = Hud.new()
	add_child(hud)
	hud.main_button_pressed.connect(_on_main_button)
	hud.spell_pressed.connect(_select_spell)
	hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	hud.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))


# --- Placement ---------------------------------------------------------------

func _placing_fighter() -> Fighter:
	if state.phase != CombatState.Phase.PLACEMENT or placing_index >= state.fighters.size():
		return null
	return state.fighters[placing_index]


func _begin_placement_of(index: int) -> void:
	placing_index = index
	if index >= state.fighters.size():
		state.start()
		return
	var f := _placing_fighter()
	for id in fighter_views:
		fighter_views[id].is_active = (id == f.id)
	hud.show_placement(f, is_ai(f))
	_refresh_highlights()
	if is_ai(f):
		await get_tree().create_timer(0.6, false).timeout
		state.place(f, _ai_placement_cell(f))
		await get_tree().create_timer(0.4, false).timeout
		_begin_placement_of(index + 1)


## L'IA choisit une case de sa zone : au hasard parmi les cases qui ont le plus d'issues.
func _ai_placement_cell(f: Fighter) -> Vector2i:
	var cells := state.placement_cells(f.team)
	cells.shuffle()
	var best := f.cell
	var best_exits := -1
	for cell in cells:
		var occupant := state.fighter_at(cell)
		if occupant != null and occupant != f:
			continue
		var exits := 0
		for dir in BattleGrid.DIRECTIONS:
			if state.grid.is_walkable(cell + dir):
				exits += 1
		if exits > best_exits:
			best_exits = exits
			best = cell
	return best


# --- Entrées -----------------------------------------------------------------

func _input_locked() -> bool:
	if busy or state.is_over:
		return true
	if state.phase == CombatState.Phase.PLACEMENT:
		return is_ai(_placing_fighter())
	return is_ai(state.active_fighter())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_refresh_highlights()
		return
	# Échap : annule le sort choisi, sinon ouvre le menu pause (même pendant le tour de l'IA).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if selected_spell != null and not _input_locked():
			_cancel_spell()
		elif not state.is_over:
			hud.open_pause()
		get_viewport().set_input_as_handled()
		return
	if _input_locked():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(_mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_spell()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_main_button()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				_select_spell(event.keycode - KEY_1)


func _on_left_click(cell: Vector2i) -> void:
	if state.phase == CombatState.Phase.PLACEMENT:
		state.place(_placing_fighter(), cell)
		_refresh_highlights()
	elif selected_spell:
		var spell := selected_spell
		if state.can_cast_at(spell, cell):
			selected_spell = null
			state.try_cast(spell, cell)
	else:
		state.try_move(cell)


func _on_main_button() -> void:
	if _input_locked():
		return
	if state.phase == CombatState.Phase.PLACEMENT:
		_begin_placement_of(placing_index + 1)
	else:
		selected_spell = null
		state.end_turn()


func _select_spell(index: int) -> void:
	var f := state.active_fighter()
	if _input_locked() or f == null or index < 0 or index >= f.spells.size():
		return
	var spell := f.spells[index]
	if selected_spell == spell or not state.can_use_spell(spell):
		selected_spell = null
	else:
		selected_spell = spell
	_refresh_ui()


func _cancel_spell() -> void:
	selected_spell = null
	_refresh_ui()


func _mouse_cell() -> Vector2i:
	return Iso.world_to_cell(board.get_local_mouse_position())


# --- IA ------------------------------------------------------------------------

func _run_ai_turn(fighter: Fighter) -> void:
	for i in AI_MAX_ACTIONS:
		await get_tree().create_timer(AI_STEP_DELAY, false).timeout
		await _wait_idle()
		if state.is_over or state.active_fighter() != fighter:
			return
		var action := AiBrain.next_action(state)
		match action.type:
			"move":
				state.try_move(action.cell)
			"cast":
				# On montre brièvement la cible, comme le ferait un joueur.
				selected_spell = action.spell
				_refresh_ui(action.cell)
				await get_tree().create_timer(0.45, false).timeout
				selected_spell = null
				state.try_cast(action.spell, action.cell)
			_:
				break
		await _wait_idle()
	if not state.is_over and state.active_fighter() == fighter:
		state.end_turn()


func _wait_idle() -> void:
	while busy:
		await get_tree().process_frame


# --- Affichage ---------------------------------------------------------------

func _refresh_ui(forced_hover: Vector2i = Vector2i(-1, -1)) -> void:
	var f := state.active_fighter()
	if f and state.phase == CombatState.Phase.FIGHT:
		hud.show_combat(state, selected_spell, is_ai(f))
	_refresh_highlights(forced_hover)


func _refresh_highlights(forced_hover: Vector2i = Vector2i(-1, -1)) -> void:
	var layers: Array[Dictionary] = []
	var hover := forced_hover if forced_hover != Vector2i(-1, -1) else _mouse_cell()
	for fighter in state.fighters:
		fighter_views[fighter.id].set_hovered(fighter.cell == hover)

	if state.phase == CombatState.Phase.PLACEMENT:
		var placer := _placing_fighter()
		for team in state.placement_zones.size():
			var color: Color = ZONE_COLORS[team % ZONE_COLORS.size()]
			if placer == null or team != placer.team:
				color.a *= 0.35
			layers.append(BoardView.layer(state.placement_cells(team), color))
		board.set_layers(layers, hover)
		return

	if busy or state.is_over or not selected_spell:
		_show_previews([])
	if busy or state.is_over:
		board.set_layers(layers, Vector2i(-1, -1))
		return

	if selected_spell:
		# Toute la portée est affichée ; seules les cibles valides sont lançables.
		var in_range := state.range_display(selected_spell)
		var seen: Array[Vector2i] = []
		var blocked: Array[Vector2i] = []
		for cell in in_range:
			if in_range[cell]:
				seen.append(cell)
			else:
				blocked.append(cell)
		layers.append(BoardView.layer(blocked, BoardView.COLOR_NO_LOS))
		layers.append(BoardView.layer(seen, BoardView.COLOR_RANGE))
		var castable := state.can_cast_at(selected_spell, hover)
		if castable:
			layers.append(BoardView.layer(selected_spell.affected_cells(hover), BoardView.COLOR_AREA, 6.0))
		_show_previews(state.preview_cast(selected_spell, hover) if castable else [])
		board.set_layers(layers, hover, BoardView.COLOR_HOVER if castable else Color(1, 0.3, 0.3, 0.8))
	else:
		layers.append(BoardView.layer(state.reachable_for_active().keys(), BoardView.COLOR_REACHABLE))
		if not is_ai(state.active_fighter()):
			layers.append(BoardView.layer(state.path_for_active(hover), BoardView.COLOR_PATH, 6.0))
		board.set_layers(layers, hover)


## Aperçu des dégâts / soins sur la barre de PV des personnages touchés par le sort visé.
func _show_previews(previews: Array) -> void:
	var by_id: Dictionary = {}
	for p in previews:
		by_id[p.fighter.id] = p
	for id in fighter_views:
		fighter_views[id].set_preview(by_id.get(id, {}))


func _set_busy(value: bool) -> void:
	busy = value
	hud.set_input_enabled(not value and not state.is_over and not is_ai(state.active_fighter()))
	_refresh_ui()


# --- Réactions aux événements du combat -----------------------------------------

func _on_fighter_placed(fighter: Fighter) -> void:
	fighter_views[fighter.id].snap()


func _on_turn_started(fighter: Fighter, turn_number: int) -> void:
	if turn_number == 1:
		Sound.play_voice(_voice(fighter), "greet", fighter.id) # chacun se présente à son premier tour
	selected_spell = null
	for id in fighter_views:
		fighter_views[id].is_active = (id == fighter.id)
	hud.set_input_enabled(not is_ai(fighter))
	_refresh_ui()
	if is_ai(fighter):
		_run_ai_turn(fighter)


func _on_fighter_moved(fighter: Fighter, path: Array[Vector2i]) -> void:
	_set_busy(true)
	var view: FighterView = fighter_views[fighter.id]
	view.play_move(path)
	await view.move_finished
	_set_busy(false)


func _on_spell_cast(caster: Fighter, spell: SpellData, target: Vector2i, cells: Array[Vector2i]) -> void:
	var caster_view: FighterView = fighter_views[caster.id]
	caster_view.play_cast(spell.animation, target)
	Sound.play_voice(_voice(caster), CharacterVoice.moment_for_animation(spell.animation), caster.id)
	_set_busy(true)
	if spell.projectile is EffectAnimation or spell.impact is EffectAnimation:
		_deferring = true
		await get_tree().create_timer(spell.cast_delay, false).timeout
		if spell.projectile is EffectAnimation:
			var from := caster_view.position + Vector2(0, -40)
			var to := Iso.cell_to_world(target) + Vector2(0, -28)
			var fx := EffectView.projectile(self, spell.projectile, from, to)
			await fx.arrived
		if spell.impact is EffectAnimation:
			EffectView.impact(self, spell.impact, Iso.cell_to_world(target))
		board.flash(cells)
		_flush_deferred()
		await get_tree().create_timer(0.45, false).timeout
	else:
		board.flash(cells)
		await get_tree().create_timer(0.5, false).timeout
	_set_busy(false)


## Voix du combattant (CharacterVoice de sa classe), ou null.
func _voice(fighter: Fighter) -> Resource:
	return fighter.class_data.voice if fighter.class_data else null


## Met une conséquence de sort en attente si un projectile est en vol. Renvoie true si mise en attente.
func _defer(action: Callable) -> bool:
	if _deferring:
		_deferred.append(action)
	return _deferring


func _flush_deferred() -> void:
	_deferring = false
	var actions := _deferred.duplicate()
	_deferred.clear()
	for action in actions:
		action.call()


func _on_fighter_damaged(fighter: Fighter, amount: int) -> void:
	if _defer(_on_fighter_damaged.bind(fighter, amount)):
		return
	var view: FighterView = fighter_views[fighter.id]
	var caster := state.active_fighter()
	view.play_hit(Iso.cell_to_world(caster.cell) if caster != fighter else view.position + Vector2(0, -1))
	FloatingText.spawn(self, view.text_anchor(), "-%d" % amount, Color("ff6b5b"))
	var voice := _voice(fighter) as CharacterVoice
	if voice and fighter.is_alive():
		var big := amount >= fighter.max_hp * voice.big_hurt_ratio
		Sound.play_voice(voice, "big_hurt" if big else "hurt", fighter.id)


func _on_fighter_healed(fighter: Fighter, amount: int) -> void:
	if _defer(_on_fighter_healed.bind(fighter, amount)):
		return
	var view: FighterView = fighter_views[fighter.id]
	view.play_heal()
	FloatingText.spawn(self, view.text_anchor(), "+%d" % amount, Color("6be07a"))


func _on_fighter_displaced(fighter: Fighter, _from: Vector2i, to: Vector2i) -> void:
	if _defer(_on_fighter_displaced.bind(fighter, _from, to)):
		return
	# Le lanceur qui se déplace lui-même = bond ; sinon poussée / attraction.
	fighter_views[fighter.id].play_slide(to, fighter == state.active_fighter())


func _on_status_changed(fighter: Fighter) -> void:
	fighter_views[fighter.id].refresh()


func _on_fighter_died(fighter: Fighter) -> void:
	if _defer(_on_fighter_died.bind(fighter)):
		return
	fighter_views[fighter.id].play_death()
	Sound.play_voice(_voice(fighter), "death", fighter.id)


func _on_combat_ended(winner_team: int) -> void:
	if _defer(_on_combat_ended.bind(winner_team)):
		return
	var winner_name := ""
	for f in state.fighters:
		if f.team == winner_team:
			winner_name = "%s (%s)" % [f.display_name, f.class_data.class_label if f.class_data else "?"]
	await get_tree().create_timer(1.0, false).timeout
	_refresh_highlights()
	hud.show_victory(winner_name)
	for f in state.fighters:
		if f.team == winner_team and f.is_alive():
			Sound.play_voice(_voice(f), "victory", f.id)
			break
