class_name BattleGrid
extends RefCounted
## Logique pure de la grille : dimensions, obstacles, chemins et zone accessible.
## Aucun nœud graphique ici : ce code sera réutilisé tel quel par le serveur en phase 5.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var width: int
var height: int
var _obstacles: Dictionary = {} # Vector2i -> true
var _astar := AStarGrid2D.new()


func _init(p_width: int, p_height: int, obstacles: Array[Vector2i] = []) -> void:
	width = p_width
	height = p_height
	_astar.region = Rect2i(0, 0, width, height)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for cell in obstacles:
		add_obstacle(cell)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func add_obstacle(cell: Vector2i) -> void:
	if is_inside(cell):
		_obstacles[cell] = true
		_astar.set_point_solid(cell, true)


func is_obstacle(cell: Vector2i) -> bool:
	return _obstacles.has(cell)


func get_obstacles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _obstacles:
		result.append(cell)
	return result


func is_walkable(cell: Vector2i, occupied: Array[Vector2i] = []) -> bool:
	return is_inside(cell) and not is_obstacle(cell) and not occupied.has(cell)


## Cases atteignables depuis `from` en au plus `max_steps` pas (parcours en largeur).
## Renvoie un dictionnaire case -> nombre de PM nécessaires. La case de départ n'est pas incluse.
func reachable_cells(from: Vector2i, max_steps: int, occupied: Array[Vector2i] = []) -> Dictionary:
	var costs: Dictionary = {from: 0}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var cost: int = costs[current]
		if cost >= max_steps:
			continue
		for dir in DIRECTIONS:
			var next: Vector2i = current + dir
			if costs.has(next) or not is_walkable(next, occupied):
				continue
			costs[next] = cost + 1
			frontier.append(next)
	costs.erase(from)
	return costs


## Chemin le plus court (sans la case de départ). Vide si la case est inaccessible.
func find_path(from: Vector2i, to: Vector2i, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or not is_walkable(to, occupied):
		return result
	for cell in occupied:
		_astar.set_point_solid(cell, true)
	var path: Array[Vector2i] = _astar.get_id_path(from, to)
	for cell in occupied:
		if not is_obstacle(cell):
			_astar.set_point_solid(cell, false)
	for i in range(1, path.size()):
		result.append(path[i])
	return result
