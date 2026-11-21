extends Node2D
## Point d'entrée : assemble la logique (core) et l'affichage (view), puis gère les entrées.
## Contrôles : survol = aperçu du chemin, clic gauche = se déplacer, Espace = fin du tour.

var state: CombatState
var board: BoardView
var entities: Node2D
var hud: Hud
var fighter_views: Dictionary = {} # Fighter.id -> FighterView
var busy := false # vrai pendant une animation : on ignore les entrées


func _ready() -> void:
	_build_combat()
	_build_scene()
	state.turn_started.connect(_on_turn_started)
	state.fighter_moved.connect(_on_fighter_moved)
	state.start()


func _build_combat() -> void:
	var grid := BattleGrid.new(MapLayouts.TEST_SIZE.x, MapLayouts.TEST_SIZE.y, MapLayouts.TEST_OBSTACLES)
	state = CombatState.new(grid)
	state.add_fighter(Fighter.new(0, "Joueur 1", 0, MapLayouts.TEST_SPAWNS[0]))
	state.add_fighter(Fighter.new(1, "Joueur 2", 1, MapLayouts.TEST_SPAWNS[1]))


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
	camera.position = Iso.cell_to_world(last) * 0.5
	add_child(camera)

	hud = Hud.new()
	add_child(hud)
	hud.end_turn_pressed.connect(_end_turn)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_refresh_highlights()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not busy:
			state.try_move(_mouse_cell())
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_end_turn()


func _mouse_cell() -> Vector2i:
	return Iso.world_to_cell(board.get_local_mouse_position())


func _refresh_highlights() -> void:
	if busy:
		var none: Array[Vector2i] = []
		board.set_highlights({}, none, Vector2i(-1, -1))
		return
	var hover := _mouse_cell()
	board.set_highlights(state.reachable_for_active(), state.path_for_active(hover), hover)


func _end_turn() -> void:
	if not busy:
		state.end_turn()


func _on_turn_started(fighter: Fighter, turn_number: int) -> void:
	for id in fighter_views:
		fighter_views[id].is_active = (id == fighter.id)
	hud.show_fighter(fighter, turn_number)
	_refresh_highlights()


func _on_fighter_moved(fighter: Fighter, path: Array[Vector2i]) -> void:
	busy = true
	hud.set_input_enabled(false)
	hud.show_fighter(fighter, state.turn_number)
	_refresh_highlights()
	var view: FighterView = fighter_views[fighter.id]
	view.play_move(path)
	await view.move_finished
	busy = false
	hud.set_input_enabled(true)
	_refresh_highlights()
