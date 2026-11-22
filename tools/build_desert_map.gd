extends SceneTree
## Génère la carte « Ruines du désert » (maps/desert.tscn) et son tileset.
## Usage : godot --headless --path . -s res://tools/build_desert_map.gd
## Les tuiles viennent du pack « 2D Desert Fantasy tileset » (réduites à 128 px dans
## assets/tiles/desert/desert_tiles.png). Pour modifier la carte : changer les listes
## ci-dessous puis relancer le script (ou retoucher la scène dans l'éditeur).

const SIZE := 15
const ATLAS := "res://assets/tiles/desert/desert_tiles.png"
const MARKERS := "res://assets/tiles/desert/placement_markers.png"
const RIPPLES := "res://assets/tiles/desert/water_ripples.png"
const TILESET_PATH := "res://assets/tiles/desert/desert_tileset.tres"
const SCENE_PATH := "res://maps/desert.tscn"

## Ordre des images dans la planche (8 par ligne).
const NAMES := ["Ground A1", "Ground W4", "Ground E1", "Ground A18", "Ground E10", "Ground E11", "Ground E12", "Ground E13", "Ground E14", "Ground E15", "Ground E2", "Ground E3", "Flora C1", "Flora C2", "Flora C3", "Flora C4", "Stone A1", "Stone A12", "Stone A2", "Stone A23", "Stone A24", "Stone A3", "Tree A1", "Tree A2", "Tree A3", "Tree A4", "Wall A6"]
## Préfixes des tuiles qui bloquent déplacement et ligne de vue.
const OBSTACLES := ["Stone", "Wall", "Tree"]
## Obstacles destructibles et leurs PV : rochers et colonnes (ni le sphinx, ni les obélisques, ni les palmiers).
const DESTRUCTIBLE_HP := {"Stone A1": 120, "Stone A12": 120, "Stone A2": 120, "Stone A3": 120, "Wall A6": 80}
const WATER_TILE := "Ground W4"
const SAND_TILE := "Ground A1"

## Cases d'eau.
const WATER_CELLS := [[9, 1], [9, 2], [9, 3], [10, 1], [10, 2], [10, 3], [11, 1], [11, 2], [11, 3]]
## Surcouches posées à plat (allée pavée, herbe, graviers) : [x, y, tuile].
const DETAILS := [
	[1, 0, "Ground E10"],
	[2, 0, "Ground E11"],
	[4, 0, "Ground E14"],
	[5, 0, "Ground E3"],
	[7, 0, "Ground E3"],
	[8, 0, "Ground A18"],
	[9, 0, "Ground A18"],
	[10, 0, "Ground A18"],
	[11, 0, "Ground A18"],
	[12, 0, "Ground A18"],
	[13, 0, "Ground E11"],
	[2, 1, "Ground E3"],
	[3, 1, "Ground E14"],
	[4, 1, "Ground E13"],
	[5, 1, "Ground E13"],
	[8, 1, "Ground A18"],
	[12, 1, "Ground A18"],
	[0, 2, "Ground E14"],
	[3, 2, "Ground E10"],
	[8, 2, "Ground A18"],
	[12, 2, "Ground A18"],
	[1, 3, "Ground E13"],
	[3, 3, "Ground E12"],
	[7, 3, "Ground E11"],
	[8, 3, "Ground A18"],
	[12, 3, "Ground A18"],
	[13, 3, "Ground E3"],
	[14, 3, "Ground E15"],
	[0, 4, "Ground E2"],
	[3, 4, "Ground E15"],
	[8, 4, "Ground A18"],
	[9, 4, "Ground A18"],
	[10, 4, "Ground A18"],
	[11, 4, "Ground A18"],
	[12, 4, "Ground A18"],
	[13, 4, "Ground E11"],
	[2, 5, "Ground E12"],
	[6, 5, "Ground E3"],
	[13, 5, "Ground E12"],
	[14, 5, "Ground E14"],
	[0, 6, "Ground E1"],
	[1, 6, "Ground E1"],
	[2, 6, "Ground E1"],
	[3, 6, "Ground E1"],
	[4, 6, "Ground E1"],
	[5, 6, "Ground E1"],
	[6, 6, "Ground E1"],
	[7, 6, "Ground E1"],
	[8, 6, "Ground E1"],
	[9, 6, "Ground E1"],
	[10, 6, "Ground E1"],
	[11, 6, "Ground E1"],
	[12, 6, "Ground E1"],
	[13, 6, "Ground E1"],
	[14, 6, "Ground E1"],
	[0, 7, "Ground E1"],
	[1, 7, "Ground E1"],
	[2, 7, "Ground E1"],
	[3, 7, "Ground E1"],
	[4, 7, "Ground E1"],
	[5, 7, "Ground E1"],
	[6, 7, "Ground E1"],
	[7, 7, "Ground E1"],
	[8, 7, "Ground E1"],
	[9, 7, "Ground E1"],
	[10, 7, "Ground E1"],
	[11, 7, "Ground E1"],
	[12, 7, "Ground E1"],
	[13, 7, "Ground E1"],
	[14, 7, "Ground E1"],
	[0, 8, "Ground E1"],
	[1, 8, "Ground E1"],
	[2, 8, "Ground E1"],
	[3, 8, "Ground E1"],
	[4, 8, "Ground E1"],
	[5, 8, "Ground E1"],
	[6, 8, "Ground E1"],
	[7, 8, "Ground E1"],
	[8, 8, "Ground E1"],
	[9, 8, "Ground E1"],
	[10, 8, "Ground E1"],
	[11, 8, "Ground E1"],
	[12, 8, "Ground E1"],
	[13, 8, "Ground E1"],
	[14, 8, "Ground E1"],
	[3, 9, "Ground E3"],
	[8, 9, "Ground E3"],
	[12, 9, "Ground E11"],
	[13, 9, "Ground E14"],
	[0, 10, "Ground E13"],
	[1, 10, "Ground E10"],
	[2, 10, "Ground E15"],
	[5, 10, "Ground E10"],
	[0, 11, "Ground E14"],
	[2, 11, "Ground E10"],
	[3, 11, "Ground E13"],
	[7, 11, "Ground E14"],
	[9, 11, "Ground E12"],
	[13, 11, "Ground E2"],
	[2, 12, "Ground E11"],
	[8, 12, "Ground E15"],
	[9, 12, "Ground E10"],
	[11, 12, "Ground E11"],
	[13, 12, "Ground E15"],
	[1, 13, "Ground E15"],
	[6, 13, "Ground E14"],
	[9, 13, "Ground E2"],
	[11, 13, "Ground E10"],
	[14, 13, "Ground E15"],
	[5, 14, "Ground E14"],
	[11, 14, "Ground E15"],
	[13, 14, "Ground E11"]
]
## Objets (décor) : [x, y, tuile].
const OBJECTS := [
	[7, 7, "Stone A23"],
	[7, 5, "Stone A24"],
	[7, 9, "Stone A24"],
	[1, 5, "Wall A6"],
	[1, 9, "Wall A6"],
	[4, 5, "Wall A6"],
	[4, 9, "Wall A6"],
	[10, 5, "Wall A6"],
	[10, 9, "Wall A6"],
	[13, 5, "Wall A6"],
	[13, 9, "Wall A6"],
	[7, 2, "Flora C2"],
	[13, 3, "Flora C3"],
	[2, 4, "Flora C1"],
	[3, 3, "Flora C4"],
	[2, 12, "Flora C3"],
	[6, 11, "Flora C2"],
	[13, 12, "Flora C1"],
	[12, 10, "Flora C4"],
	[9, 13, "Flora C3"],
	[1, 6, "Flora C4"],
	[8, 1, "Tree A1"],
	[9, 0, "Tree A2"],
	[12, 2, "Tree A1"],
	[12, 4, "Tree A3"],
	[8, 4, "Tree A4"],
	[1, 12, "Tree A2"],
	[3, 2, "Stone A1"],
	[5, 12, "Stone A2"],
	[11, 12, "Stone A1"],
	[2, 11, "Stone A3"],
	[12, 11, "Stone A2"],
	[4, 3, "Stone A12"],
	[8, 12, "Stone A12"],
	[1, 10, "Stone A1"]
]
## Zones de départ : équipe 1 à l'ouest de l'allée, équipe 2 à l'est.
const TEAM1 := [[0, 6], [0, 7], [0, 8], [1, 6], [1, 7], [1, 8], [2, 6], [2, 7], [2, 8]]
const TEAM2 := [[12, 6], [12, 7], [12, 8], [13, 6], [13, 7], [13, 8], [14, 6], [14, 7], [14, 8]]


func _init() -> void:
	var tileset := _build_tileset()
	ResourceSaver.save(tileset, TILESET_PATH)
	tileset = load(TILESET_PATH)

	var root := Node2D.new()
	root.name = "DesertMap"
	root.set_script(load("res://scripts/map/battle_map.gd"))
	root.set("map_name", "Ruines du désert")
	root.set("description", "Une allée pavée mène au sphinx, bordée de colonnes ; une oasis à l'est, quelques rochers : des abris au centre, des tirs dégagés ailleurs.")

	var ground := _layer(root, "Sol", tileset)
	var detail := _layer(root, "SolDetail", tileset)
	var decor := _layer(root, "Decor", tileset)
	decor.y_sort_enabled = true
	var placement := _layer(root, "Placement", tileset)

	for y in SIZE:
		for x in SIZE:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, 0, _coords(WATER_TILE if WATER_CELLS.has([x, y]) else SAND_TILE))
	for d in DETAILS:
		detail.set_cell(Vector2i(d[0], d[1]), 0, _coords(d[2]))
	for o in OBJECTS:
		decor.set_cell(Vector2i(o[0], o[1]), 0, _coords(o[2]))
	for c in TEAM1:
		placement.set_cell(Vector2i(c[0], c[1]), 1, Vector2i(0, 0))
	for c in TEAM2:
		placement.set_cell(Vector2i(c[0], c[1]), 1, Vector2i(1, 0))

	var ripples := Node2D.new()
	ripples.name = "EauAnimee"
	ripples.set_script(load("res://scripts/map/water_ripples.gd"))
	ripples.set("sheet", load(RIPPLES))
	root.add_child(ripples)
	ripples.owner = root
	# l'ondulation passe sous le décor : on la place juste après les surcouches du sol
	root.move_child(ripples, detail.get_index() + 1)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, SCENE_PATH)
	print("Carte générée : ", SCENE_PATH)
	quit()


func _layer(root: Node2D, layer_name: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	return layer


func _coords(tile: String) -> Vector2i:
	var i: int = NAMES.find(tile)
	assert(i >= 0, "Tuile inconnue : " + tile)
	return Vector2i(i % 8, i / 8)


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "obstacle")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, "placement_team")
	ts.set_custom_data_layer_type(1, TYPE_INT)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(2, "water")
	ts.set_custom_data_layer_type(2, TYPE_BOOL)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(3, "destructible_hp")
	ts.set_custom_data_layer_type(3, TYPE_INT)

	var tiles := TileSetAtlasSource.new()
	tiles.resource_name = "Désert"
	tiles.texture = load(ATLAS)
	tiles.texture_region_size = Vector2i(128, 128)
	ts.add_source(tiles, 0)
	for i in NAMES.size():
		var coords := Vector2i(i % 8, i / 8)
		tiles.create_tile(coords)
		var data := tiles.get_tile_data(coords, 0)
		data.texture_origin = Vector2i(0, 40)
		var tile_name: String = NAMES[i]
		for prefix in OBSTACLES:
			if tile_name.begins_with(prefix):
				data.set_custom_data("obstacle", true)
		if DESTRUCTIBLE_HP.has(tile_name):
			data.set_custom_data("destructible_hp", DESTRUCTIBLE_HP[tile_name])
		if tile_name == WATER_TILE:
			data.set_custom_data("water", true)

	var markers := TileSetAtlasSource.new()
	markers.resource_name = "Placement"
	markers.texture = load(MARKERS)
	markers.texture_region_size = Vector2i(128, 128)
	ts.add_source(markers, 1)
	for team in 2:
		markers.create_tile(Vector2i(team, 0))
		var data := markers.get_tile_data(Vector2i(team, 0), 0)
		data.texture_origin = Vector2i(0, 40)
		data.set_custom_data("placement_team", team + 1)
	return ts
