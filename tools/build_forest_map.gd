extends SceneTree
## Génère la carte « Clairière des gobelins » (maps/foret.tscn) et son tileset.
## Usage : godot --headless --path . -s res://tools/build_forest_map.gd
## Les tuiles viennent du pack « Fantasy tileset - 2D Isometric » (réduites à 128 px dans
## assets/tiles/foret/foret_tiles.png). Pour modifier la carte : changer les listes ci-dessous
## puis relancer le script. Attention : relancer écrase la scène (retouches de l'éditeur perdues).
## Carte symétrique par rapport au centre : (x, y) ↔ (14 - x, 14 - y).

const SIZE := 15
const ATLAS := "res://assets/tiles/foret/foret_tiles.png"
const MARKERS := "res://assets/tiles/foret/placement_markers.png"
const TILESET_PATH := "res://assets/tiles/foret/foret_tileset.tres"
const SCENE_PATH := "res://maps/foret.tscn"

## Ordre des images dans la planche (8 par ligne).
const NAMES := ["Ground A2", "Ground A18", "Ground C4", "Flora A1", "Flora A5", "Flora B1", "Flora B2", "Flora B5",
	"Tree A1", "Tree A2", "Tree A3", "Tree A4", "Tree D1", "Tree D2", "Tree D3", "Tree E2",
	"Tree E5", "Stone A17", "Stone A18", "Stone A19"]
## Tuiles qui bloquent déplacement et ligne de vue (la souche Tree A4 et les touffes ne bloquent pas).
const OBSTACLES := ["Tree A1", "Tree A2", "Tree A3", "Tree D1", "Tree D2", "Tree D3", "Tree E2", "Tree E5",
	"Stone A17", "Stone A18", "Stone A19"]
## Obstacles destructibles et leurs PV : arbres feuillus et troncs couchés (ni les sapins, ni les rochers).
const DESTRUCTIBLE_HP := {"Tree A1": 60, "Tree A2": 60, "Tree A3": 60, "Tree E2": 40, "Tree E5": 80}
const GRASS_TILE := "Ground A2"

## Surcouches posées à plat (herbe sombre en lisière, chemin de terre) : [x, y, tuile].
const DETAILS := [
	[1, 1, "Ground A18"], [2, 0, "Ground A18"], [0, 2, "Ground A18"], [3, 0, "Ground A18"], [1, 3, "Ground A18"],
	[13, 13, "Ground A18"], [12, 14, "Ground A18"], [14, 12, "Ground A18"], [11, 14, "Ground A18"], [13, 11, "Ground A18"],
	[12, 0, "Ground A18"], [14, 2, "Ground A18"], [13, 1, "Ground A18"],
	[2, 14, "Ground A18"], [0, 12, "Ground A18"], [1, 13, "Ground A18"],
	[6, 0, "Ground A18"], [8, 14, "Ground A18"],
	# Chemin de terre d'ouest en est, qui contourne le tronc du centre
	[3, 7, "Ground C4"], [4, 7, "Ground C4"], [5, 7, "Ground C4"], [6, 6, "Ground C4"], [7, 6, "Ground C4"],
	[8, 8, "Ground C4"], [7, 8, "Ground C4"], [9, 7, "Ground C4"], [10, 7, "Ground C4"], [11, 7, "Ground C4"],
	[6, 7, "Ground C4"], [8, 7, "Ground C4"],
]
## Objets (décor) : [x, y, tuile].
const OBJECTS := [
	# Lisière de sapins (indestructibles), dans les coins
	[0, 0, "Tree D3"], [1, 0, "Tree D1"], [0, 1, "Tree D2"],
	[14, 14, "Tree D3"], [13, 14, "Tree D1"], [14, 13, "Tree D2"],
	[13, 0, "Tree D1"], [1, 14, "Tree D1"],
	[14, 1, "Tree D2"], [0, 13, "Tree D2"],
	[5, 0, "Tree D2"], [9, 14, "Tree D2"],
	[0, 4, "Tree D1"], [14, 10, "Tree D1"],
	# Bosquets de feuillus (destructibles)
	[4, 2, "Tree A1"], [5, 3, "Tree A2"], [10, 12, "Tree A1"], [9, 11, "Tree A2"],
	[9, 3, "Tree A3"], [5, 11, "Tree A3"],
	[12, 3, "Tree A1"], [2, 11, "Tree A1"],
	# Rochers (indestructibles)
	[3, 5, "Stone A18"], [11, 9, "Stone A18"],
	[7, 4, "Stone A19"], [7, 10, "Stone A19"],
	[11, 5, "Stone A17"], [3, 9, "Stone A17"],
	# Troncs couchés (destructibles), dont un au centre de la clairière
	[7, 7, "Tree E5"],
	[4, 8, "Tree E2"], [10, 6, "Tree E2"],
	# Souches et touffes (ne bloquent pas)
	[6, 1, "Tree A4"], [8, 13, "Tree A4"],
	[2, 3, "Flora B1"], [12, 11, "Flora B1"],
	[8, 2, "Flora B2"], [6, 12, "Flora B2"],
	[11, 1, "Flora B5"], [3, 13, "Flora B5"],
	[6, 8, "Flora A1"], [8, 6, "Flora A1"],
	[10, 9, "Flora A5"], [4, 5, "Flora A5"],
	[12, 5, "Flora A1"], [2, 9, "Flora A1"],
]
## Zones de départ : équipe 1 à l'ouest de la clairière, équipe 2 à l'est.
const TEAM1 := [[0, 6], [0, 7], [0, 8], [1, 6], [1, 7], [1, 8], [2, 6], [2, 7], [2, 8]]
const TEAM2 := [[12, 6], [12, 7], [12, 8], [13, 6], [13, 7], [13, 8], [14, 6], [14, 7], [14, 8]]


func _init() -> void:
	var tileset := _build_tileset()
	ResourceSaver.save(tileset, TILESET_PATH)
	tileset = load(TILESET_PATH)

	var root := Node2D.new()
	root.name = "ForestMap"
	root.set_script(load("res://scripts/map/battle_map.gd"))
	root.set("map_name", "Clairière des gobelins")
	root.set("description", "Une clairière bordée de sapins. Bosquets et troncs couchés font des abris qu'on peut abattre ; des rochers solides restent en place.")
	root.set("background_color", Color(0.2, 0.29, 0.21, 1))
	root.set("ambiance", "lucioles")
	root.set("ambience_sound", "foret_nuit")
	root.set("footstep_sound", "pas_herbe")

	var ground := _layer(root, "Sol", tileset)
	var detail := _layer(root, "SolDetail", tileset)
	var decor := _layer(root, "Decor", tileset)
	decor.y_sort_enabled = true
	var placement := _layer(root, "Placement", tileset)

	for y in SIZE:
		for x in SIZE:
			ground.set_cell(Vector2i(x, y), 0, _coords(GRASS_TILE))
	for d in DETAILS:
		detail.set_cell(Vector2i(d[0], d[1]), 0, _coords(d[2]))
	for o in OBJECTS:
		decor.set_cell(Vector2i(o[0], o[1]), 0, _coords(o[2]))
	for c in TEAM1:
		placement.set_cell(Vector2i(c[0], c[1]), 1, Vector2i(0, 0))
	for c in TEAM2:
		placement.set_cell(Vector2i(c[0], c[1]), 1, Vector2i(1, 0))

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
	tiles.resource_name = "Forêt"
	tiles.texture = load(ATLAS)
	tiles.texture_region_size = Vector2i(128, 128)
	ts.add_source(tiles, 0)
	for i in NAMES.size():
		var coords := Vector2i(i % 8, i / 8)
		tiles.create_tile(coords)
		var data := tiles.get_tile_data(coords, 0)
		data.texture_origin = Vector2i(0, 40)
		var tile_name: String = NAMES[i]
		if OBSTACLES.has(tile_name):
			data.set_custom_data("obstacle", true)
		if DESTRUCTIBLE_HP.has(tile_name):
			data.set_custom_data("destructible_hp", DESTRUCTIBLE_HP[tile_name])

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
