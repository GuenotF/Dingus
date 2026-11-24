class_name BattleMap
extends Node2D
## Carte de combat dessinée dans l'éditeur de Godot (maps/*.tscn).
##
## Trois calques TileMapLayer :
##   Sol        le terrain ; chaque case peinte fait partie de la grille de combat.
##   SolDetail  (optionnel) surcouches posées à plat sur le sol (herbe, gravillons...),
##              toujours sous les personnages.
##   Decor      objets posés sur le sol (rochers, troncs, fleurs...).
##   Placement  cases de départ de chaque équipe (visible seulement dans l'éditeur).
##
## Règles lues sur les tuiles (données personnalisées du TileSet) :
##   obstacle        (bool) la case bloque le déplacement et la ligne de vue.
##   water           (bool) eau : infranchissable mais ne bloque pas la ligne de vue.
##   placement_team  (int)  1 = équipe 1, 2 = équipe 2 (tuiles du calque Placement).
##   destructible_hp (int)  PV d'un obstacle qu'on peut détruire (0 = indestructible).
## Une case de la grille sans tuile de Sol est considérée comme un obstacle (vide).
##
## La carte doit commencer en (0, 0) : la grille va de (0, 0) au coin opposé du Sol.

const OBSTACLE := "obstacle"
const WATER := "water"
const PLACEMENT_TEAM := "placement_team"
## (int) PV d'un obstacle destructible ; 0 ou absent = indestructible.
const DESTRUCTIBLE_HP := "destructible_hp"

## Nom affiché dans le menu.
@export var map_name: String = ""
## Courte description affichée dans le menu.
@export_multiline var description: String = ""

## Ambiance du fond d'écran (voir BackgroundView) : teinte de base du dégradé...
@export var background_color: Color = Color("232830")
## ... et particules qui dérivent derrière la carte.
@export_enum("aucune", "sable", "pollen", "lucioles") var ambiance: String = "aucune"
## Boucle sonore de fond (assets/audio/ambience/).
@export_enum("aucune", "foret_jour", "foret_nuit", "riviere", "vent") var ambience_sound: String = "aucune"
## Bruit de pas des combattants (assets/audio/sfx/).
@export_enum("pas_herbe", "pas_terre", "pas_pierre", "pas_bois") var footstep_sound: String = "pas_herbe"


func ground() -> TileMapLayer:
	return get_node("Sol")


## Calque optionnel de surcouches au sol (null si la carte n'en a pas).
func ground_detail() -> TileMapLayer:
	return get_node_or_null("SolDetail")


func decor() -> TileMapLayer:
	return get_node("Decor")


func placement() -> TileMapLayer:
	return get_node("Placement")


func grid_size() -> Vector2i:
	return ground().get_used_rect().end


func build_grid() -> BattleGrid:
	var size := grid_size()
	var grid := BattleGrid.new(size.x, size.y, obstacles(), water())
	var hp_by_cell := destructibles()
	for cell in hp_by_cell:
		grid.add_destructible(cell, hp_by_cell[cell])
	return grid


## Obstacles destructibles : case -> PV (tuile de sol, de surcouche ou de décor portant `destructible_hp`).
func destructibles() -> Dictionary:
	var result: Dictionary = {}
	for layer: TileMapLayer in [ground(), ground_detail(), decor()]:
		if layer == null or layer.tile_set == null \
				or layer.tile_set.get_custom_data_layer_by_name(DESTRUCTIBLE_HP) == -1:
			continue
		for cell in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null or not data.get_custom_data(OBSTACLE):
				continue
			var hp: int = data.get_custom_data(DESTRUCTIBLE_HP)
			if hp > 0:
				result[cell] = hp
	return result


## Cases bloquantes : tuile marquée « obstacle » (sol ou décor), ou absence de sol.
func obstacles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := grid_size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if ground().get_cell_source_id(cell) == -1 \
					or _is_obstacle(ground(), cell) or _is_obstacle(decor(), cell) \
					or (ground_detail() != null and _is_obstacle(ground_detail(), cell)):
				result.append(cell)
	return result


## Cases d'eau : tuile de sol marquée « water » (et sans obstacle posé dessus).
func water() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var blocked := obstacles()
	for cell in ground().get_used_cells():
		var data := ground().get_cell_tile_data(cell)
		if data != null and data.get_custom_data(WATER) and not blocked.has(cell):
			result.append(cell)
	result.sort()
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
