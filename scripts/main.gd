extends Node2D
## Point d'entrée : assemble la logique (core) et l'affichage (view), puis gère les entrées.
## Contrôles : survol = aperçu, clic gauche = se déplacer ou lancer le sort choisi,
## 1-3 = choisir un sort, clic droit / Échap = annuler, Espace = fin du tour.

const SPELL_PATHS: Array[String] = [
	"res://data/spells/coup_epee.tres",
	"res://data/spells/fleche.tres",
	"res://data/spells/bombe.tres",
]

var state: CombatState
var board: BoardView
var entities: Node2D
var hud: Hud
var fighter_views: Dictionary = {} # Fighter.id -> FighterView
var selected_spell: SpellData = null
var busy := false # vrai pendant une animation : on ignore les entrées


func _ready() -> void:
	_build_combat()
	_build_scene()
	state.turn_started.connect(_on_turn_started)
	state.fighter_moved.connect(_on_fighter_moved)
	state.spell_cast.connect(_on_spell_cast)
	state.fighter_damaged.connect(_on_fighter_damaged)
	state.fighter_died.connect(_on_fighter_died)
	state.combat_ended.connect(_on_combat_ended)
	state.start()


func _build_combat() -> void:
	var grid := BattleGrid.new(MapLayouts.TEST_SIZE.x, MapLayouts.TEST_SIZE.y, MapLayouts.TEST_OBSTACLES)
	state = CombatState.new(grid)
	var spells: Array[SpellData] = []
	for path in SPELL_PATHS:
		spells.append(load(path))
	var names := ["Joueur 1", "Joueur 2"]
	for i in 2:
		var f := Fighter.new(i, names[i], i, MapLayouts.TEST_SPAWNS[i])
		f.spells = spells
		state.add_fighter(f)


func _build_scene() -> void:
	RenderingServer.set_default_clear_color(Color("1d2128"))

	board = BoardView.new()
	add_child(board)
	board.setup(state.grid)

	# Obstacles et pions dans le même conteneur trié par Y : la profondeur est automatique.
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	for cell in state.grid.get_obstacles():
		var obstacle := ObstacleView.new()
		obstacle.position = Iso.cell_to_world(cell)
		entities.add_child(obstacle)

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
	hud.end_turn_pressed.connect(_end_turn)
	hud.spell_pressed.connect(_select_spell)
	hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())


# --- Entrées -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_refresh_highlights()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(_mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_spell()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_end_turn()
			KEY_ESCAPE:
				_cancel_spell()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				_select_spell(event.keycode - KEY_1)


func _on_left_click(cell: Vector2i) -> void:
	if busy or state.is_over:
		return
	if selected_spell:
		var spell := selected_spell
		if state.can_cast_at(spell, cell):
			selected_spell = null
			state.try_cast(spell, cell)
	else:
		state.try_move(cell)


func _select_spell(index: int) -> void:
	var f := state.active_fighter()
	if busy or state.is_over or f == null or index < 0 or index >= f.spells.size():
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


func _end_turn() -> void:
	if not busy:
		selected_spell = null
		state.end_turn()


func _mouse_cell() -> Vector2i:
	return Iso.world_to_cell(board.get_local_mouse_position())


# --- Affichage ---------------------------------------------------------------

func _refresh_ui() -> void:
	var f := state.active_fighter()
	if f:
		hud.show_fighter(f, state.turn_number)
	hud.show_spells(state, selected_spell)
	_refresh_highlights()


func _refresh_highlights() -> void:
	var layers: Array[Dictionary] = []
	if busy or state.is_over:
		board.set_layers(layers, Vector2i(-1, -1))
		return
	var hover := _mouse_cell()
	if selected_spell:
		var in_range := state.cells_in_range(selected_spell)
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
		board.set_layers(layers, hover, BoardView.COLOR_HOVER if castable else Color(1, 0.3, 0.3, 0.8))
	else:
		layers.append(BoardView.layer(state.reachable_for_active().keys(), BoardView.COLOR_REACHABLE))
		layers.append(BoardView.layer(state.path_for_active(hover), BoardView.COLOR_PATH, 6.0))
		board.set_layers(layers, hover)


func _set_busy(value: bool) -> void:
	busy = value
	hud.set_input_enabled(not value and not state.is_over)
	_refresh_ui()


# --- Réactions aux événements du combat ---------------------------------------

func _on_turn_started(fighter: Fighter, _turn_number: int) -> void:
	for id in fighter_views:
		fighter_views[id].is_active = (id == fighter.id)
	_refresh_ui()


func _on_fighter_moved(fighter: Fighter, path: Array[Vector2i]) -> void:
	_set_busy(true)
	var view: FighterView = fighter_views[fighter.id]
	view.play_move(path)
	await view.move_finished
	_set_busy(false)


func _on_spell_cast(_caster: Fighter, _spell: SpellData, _target: Vector2i, cells: Array[Vector2i]) -> void:
	board.flash(cells)
	_set_busy(true)
	await get_tree().create_timer(0.45).timeout
	_set_busy(false)


func _on_fighter_damaged(fighter: Fighter, amount: int) -> void:
	var view: FighterView = fighter_views[fighter.id]
	var caster := state.active_fighter()
	view.play_hit(Iso.cell_to_world(caster.cell) if caster != fighter else view.position + Vector2(0, -1))
	FloatingText.spawn(entities.get_parent(), view.position, "-%d" % amount, Color("ff6b5b"))


func _on_fighter_died(fighter: Fighter) -> void:
	fighter_views[fighter.id].play_death()


func _on_combat_ended(winner_team: int) -> void:
	var winner_name := ""
	for f in state.fighters:
		if f.team == winner_team:
			winner_name = f.display_name
	await get_tree().create_timer(1.0).timeout
	_refresh_highlights()
	hud.show_victory(winner_name)
