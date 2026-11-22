extends SceneTree
## Génère la carte « Le barrage » (maps/barricade.tscn) : un prototype pensé autour des destructibles.
## Usage : godot --headless --path . -s res://tools/build_barricade_map.gd
## Les tuiles sont celles du village ; le tileset est une copie (barricade_tileset.tres) à laquelle on
## ajoute la donnée « destructible_hp », pour ne pas rendre destructible la carte du village.
## Pour modifier la carte : changer les listes ci-dessous puis relancer le script.

const SIZE := 15
const VILLAGE_TILESET := "res://assets/tiles/village/village_tileset.tres"
const TILESET_PATH := "res://assets/tiles/village/barricade_tileset.tres"
const SCENE_PATH := "res://maps/barricade.tscn"

# Sol
const GRASS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const DIRT: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
const COBBLE := Vector2i(1, 1)
# Surcouches posées à plat
const PATCHES: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
const PEBBLES: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
# Objets (tous des obstacles)
const FENCE := Vector2i(3, 5) # palissade, le long de l'axe de la barricade
const STONE_WALLS: Array[Vector2i] = [Vector2i(4, 5), Vector2i(5, 5)]
const CRATE := Vector2i(3, 3)
const CRATES := Vector2i(7, 3)
const BARREL_STACK := Vector2i(4, 3)
const BARRELS: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 3)]
const HAY_TALL := Vector2i(0, 4)
const HAY_SMALL := Vector2i(1, 4)
const TREE := Vector2i(2, 4)
const PINE_SMALL := Vector2i(6, 4)
const PINE := Vector2i(3, 4)

## PV des objets destructibles (palissade, caisses, tonneaux, foin) ; la pierre et les arbres ne le sont pas.
const DESTRUCTIBLE_HP := {
	Vector2i(3, 5): 40, Vector2i(2, 5): 40,
	Vector2i(3, 3): 30, Vector2i(7, 3): 30,
	Vector2i(4, 3): 25, Vector2i(5, 3): 20, Vector2i(6, 3): 20,
	Vector2i(0, 4): 30, Vector2i(1, 4): 25,
}

const WALL_X := 7 # colonne de la barricade
const GATE_Y := 7 # ouverture centrale
const TEAM1_X := [0, 1, 2]
const TEAM2_X := [12, 13, 14]
const TEAM_Y := [6, 7, 8]


func _init() -> void:
	var tileset := _build_tileset()
	ResourceSaver.save(tileset, TILESET_PATH)
	tileset = load(TILESET_PATH)

	var root := Node2D.new()
	root.name = "BarricadeMap"
	root.set_script(load("res://scripts/map/battle_map.gd"))
	root.set("map_name", "Le barrage")
	root.set("description", "Une barricade coupe le terrain : pierre aux extrémités, palissades et caisses au milieu. On peut les détruire pour ouvrir des lignes de tir, ou forcer le passage central.")
	root.set("background_color", Color(0.3, 0.26, 0.2))
	root.set("ambiance", "pollen")

	var ground := _layer(root, "Sol", tileset)
	var detail := _layer(root, "SolDetail", tileset)
	var decor := _layer(root, "Decor", tileset)
	decor.y_sort_enabled = true
	var placement := _layer(root, "Placement", tileset)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261123
	for y in SIZE:
		for x in SIZE:
			var cell := Vector2i(x, y)
			var tile: Vector2i = GRASS[rng.randi() % GRASS.size()]
			# Piste de terre le long de la porte centrale, pavés devant l'ouverture.
			if absi(y - GATE_Y) <= 1 and x >= 4 and x <= 10:
				tile = DIRT[rng.randi() % DIRT.size()]
			if y == GATE_Y and absi(x - WALL_X) <= 1:
				tile = COBBLE
			ground.set_cell(cell, 0, tile)
			if rng.randf() < 0.16:
				detail.set_cell(cell, 0, PATCHES[rng.randi() % PATCHES.size()])
			elif rng.randf() < 0.05:
				detail.set_cell(cell, 0, PEBBLES[rng.randi() % PEBBLES.size()])

	# La barricade : pierre (extrémités), palissade, caisses de part et d'autre de l'ouverture.
	for y in SIZE:
		var tile := Vector2i(-1, -1)
		if y <= 2 or y >= SIZE - 3:
			tile = STONE_WALLS[y % 2]
		elif y == GATE_Y - 1 or y == GATE_Y + 1:
			tile = CRATES if y < GATE_Y else CRATE
		elif y != GATE_Y:
			tile = FENCE
		if tile.x >= 0:
			decor.set_cell(Vector2i(WALL_X, y), 0, tile)
	# Abris de chaque côté : foin, tonneaux, caisses ; arbres dans les coins.
	for c in [[3, 3, HAY_TALL], [3, 11, HAY_SMALL], [11, 3, HAY_SMALL], [11, 11, HAY_TALL],
			[4, 6, BARRELS[0]], [4, 8, BARRELS[1]], [10, 6, BARRELS[1]], [10, 8, BARRELS[0]],
			[5, 4, CRATE], [5, 10, BARREL_STACK], [9, 4, BARREL_STACK], [9, 10, CRATE],
			[1, 1, TREE], [13, 13, TREE], [1, 13, PINE], [13, 1, PINE], [5, 0, PINE_SMALL], [9, 14, PINE_SMALL]]:
		decor.set_cell(Vector2i(c[0], c[1]), 0, c[2])
	for x in TEAM1_X:
		for y in TEAM_Y:
			placement.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
	for x in TEAM2_X:
		for y in TEAM_Y:
			placement.set_cell(Vector2i(x, y), 1, Vector2i(1, 0))

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, SCENE_PATH)
	print("Carte générée : ", SCENE_PATH)
	quit()


func _build_tileset() -> TileSet:
	var ts: TileSet = (load(VILLAGE_TILESET) as TileSet).duplicate(true)
	ts.add_custom_data_layer()
	var layer := ts.get_custom_data_layers_count() - 1
	ts.set_custom_data_layer_name(layer, "destructible_hp")
	ts.set_custom_data_layer_type(layer, TYPE_INT)
	var source := ts.get_source(0) as TileSetAtlasSource
	for coords: Vector2i in DESTRUCTIBLE_HP:
		source.get_tile_data(coords, 0).set_custom_data("destructible_hp", DESTRUCTIBLE_HP[coords])
	return ts


func _layer(root: Node2D, layer_name: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	return layer
