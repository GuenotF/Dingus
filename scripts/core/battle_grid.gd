class_name BattleGrid
extends RefCounted
## Logique pure de la grille : dimensions, obstacles, eau, chemins et zone accessible.
##   obstacle : bloque le déplacement ET la ligne de vue (rocher, tronc...).
##   eau      : bloque le déplacement mais PAS la ligne de vue (comme sur Dofus).
## Aucun nœud graphique ici : ce code sera réutilisé tel quel par le serveur en phase 5.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var width: int
var height: int
var _obstacles: Dictionary = {} # Vector2i -> true
var _water: Dictionary = {} # Vector2i -> true
var _astar := AStarGrid2D.new()


func _init(p_width: int, p_height: int, obstacles: Array[Vector2i] = [], water: Array[Vector2i] = []) -> void:
	width = p_width
	height = p_height
	_astar.region = Rect2i(0, 0, width, height)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for cell in obstacles:
		add_obstacle(cell)
	for cell in water:
		add_water(cell)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func add_obstacle(cell: Vector2i) -> void:
	if is_inside(cell):
		_obstacles[cell] = true
		_astar.set_point_solid(cell, true)


func is_obstacle(cell: Vector2i) -> bool:
	return _obstacles.has(cell)


## Eau : infranchissable, mais on voit (et on tire) par-dessus.
func add_water(cell: Vector2i) -> void:
	if is_inside(cell) and not is_obstacle(cell):
		_water[cell] = true
		_astar.set_point_solid(cell, true)


func is_water(cell: Vector2i) -> bool:
	return _water.has(cell)


func get_water() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _water:
		result.append(cell)
	return result


func get_obstacles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _obstacles:
		result.append(cell)
	return result


func is_walkable(cell: Vector2i, occupied: Array[Vector2i] = []) -> bool:
	return is_inside(cell) and not is_obstacle(cell) and not is_water(cell) and not occupied.has(cell)


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


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Ligne de vue stricte (façon Dofus) : on trace le segment entre les centres des deux cases.
## Toute case que le segment touche, même en passant exactement par un coin, doit être libre.
## Les obstacles et les cases de `blockers` coupent la vue ; les extrémités ne comptent pas.
## Symétrique par construction.
func has_line_of_sight(from: Vector2i, to: Vector2i, blockers: Array[Vector2i] = []) -> bool:
	for cell in line_cells(from, to):
		if cell == from or cell == to:
			continue
		if is_obstacle(cell) or blockers.has(cell):
			return false
	return true


## Toutes les cases touchées par le segment entre les centres (« supercover »),
## extrémités comprises. Quand le segment passe exactement par un coin,
## les deux cases qui partagent ce coin sont incluses.
static func line_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var nx := absi(to.x - from.x)
	var ny := absi(to.y - from.y)
	var sx := signi(to.x - from.x)
	var sy := signi(to.y - from.y)
	var current := from
	var ix := 0
	var iy := 0
	while ix < nx or iy < ny:
		var decision := (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if decision == 0:
			# Passage exact par un coin : les deux voisines sont touchées.
			cells.append(current + Vector2i(sx, 0))
			cells.append(current + Vector2i(0, sy))
			current += Vector2i(sx, sy)
			ix += 1
			iy += 1
		elif decision < 0:
			current.x += sx
			ix += 1
		else:
			current.y += sy
			iy += 1
		cells.append(current)
	return cells


## Chemin le plus court (sans la case de départ). Vide si la case est inaccessible.
func find_path(from: Vector2i, to: Vector2i, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if from == to or not is_walkable(to, occupied):
		return result
	for cell in occupied:
		_astar.set_point_solid(cell, true)
	var path: Array[Vector2i] = _astar.get_id_path(from, to)
	for cell in occupied:
		if not is_obstacle(cell) and not is_water(cell):
			_astar.set_point_solid(cell, false)
	for i in range(1, path.size()):
		result.append(path[i])
	return result
