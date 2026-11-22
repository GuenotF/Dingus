class_name BattleMap
extends Node2D
## Carte de combat dessinée dans l'éditeur de Godot (maps/*.tscn).
##
## Trois calques TileMapLayer :
##   Sol        le terrain ; chaque case peinte fait partie de la grille de combat.
##   Decor      objets posés sur le sol (rochers, troncs, fleurs...).
##   Placement  cases de départ de chaque équipe (visible seulement dans l'éditeur).
##
## Règles lues sur les tuiles (données personnalisées du TileSet) :
##   obstacle        (bool) la case bloque le déplacement et la ligne de vue.
##   placement_team  (int)  1 = équipe 1, 2 = équipe 2 (tuiles du calque Placement).
## Une case de la grille sans tuile de Sol est considérée comme un obstacle (vide).
##
## La carte doit commencer en (0, 0) : la grille va de (0, 0) au coin opposé du Sol.

const OBSTACLE := "obstacle"
const PLACEMENT_TEAM := "placement_team"


func ground() -> TileMapLayer:
	return get_node("Sol")


func decor() -> TileMapLayer:
	return get_node("Decor")


func placement() -> TileMapLayer:
	return get_node("Placement")


func grid_size() -> Vector2i:
	return ground().get_used_rect().end


func build_grid() -> BattleGrid:
	var size := grid_size()
	return BattleGrid.new(size.x, size.y, obstacles())


## Cases bloquantes : tuile marquée « obstacle » (sol ou décor), ou absence de sol.
func obstacles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := grid_size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if ground().get_cell_source_id(cell) == -1 \
					or _is_obstacle(ground(), cell) or _is_obstacle(decor(), cell):
				result.append(cell)
	return result


## Zones de placement : [cases équipe 0, cases équipe 1].
func placement_zones() -> Array:
	var zones: Array = [[], []]
	for cell in placement().get_used_cells():
		var data := placement().get_cell_tile_data(cell)
		if data == null:
			continue
		var team: int = data.get_custom_data(PLACEMENT_TEAM) - 1
		if team >= 0 and team < zones.size():
			zones[team].append(cell)
	for zone in zones:
		zone.sort()
	return zones


func _is_obstacle(layer: TileMapLayer, cell: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data(OBSTACLE)
