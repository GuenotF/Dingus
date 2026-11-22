class_name TileWind
extends RefCounted
## Pose le shader de vent (assets/shaders/vent.gdshader) sur les tuiles de décor qui s'y prêtent
## (arbres, herbes, fleurs) et le shader d'eau sur les tuiles d'eau, via la propriété `material` des tuiles du TileSet.
## Purement visuel. Réglage joueur : Settings.scenery_animation (coupe l'effet).

const SHADER := preload("res://assets/shaders/vent.gdshader")
const WATER_SHADER := preload("res://assets/shaders/eau.gdshader")

## TileSets dont les tuiles d'eau (donnée « water ») scintillent. Le désert a ses propres ondulations.
const WATER_TILESETS := ["res://assets/tiles/terrain_tileset.tres"]

## Par TileSet : liste de { "coords": cases de l'atlas, "amplitude": px, "snap": px (0 = lisse) }.
const CONFIG := {
	"res://assets/tiles/desert/desert_tileset.tres": [
		# Palmiers (Tree A1-A4) puis touffes (Flora C1-C4).
		{"coords": [Vector2i(6, 2), Vector2i(7, 2), Vector2i(0, 3), Vector2i(1, 3)], "amplitude": 5.0, "snap": 0.0},
		{"coords": [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1)], "amplitude": 4.0, "snap": 0.0},
	],
	"res://assets/tiles/village/village_tileset.tres": [
		# Feuillus, puis sapins (plus raides), puis buissons et hautes herbes.
		{"coords": [Vector2i(2, 4), Vector2i(5, 4), Vector2i(7, 4), Vector2i(0, 5)], "amplitude": 4.5, "snap": 0.0},
		{"coords": [Vector2i(3, 4), Vector2i(4, 4), Vector2i(6, 4), Vector2i(1, 5)], "amplitude": 2.5, "snap": 0.0},
		{"coords": [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6)], "amplitude": 5.0, "snap": 0.0},
	],
	"res://assets/tiles/terrain_tileset.tres": [
		# Fleurs et buisson de la prairie (pixel art : mouvement au pixel près).
		{"coords": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)], "amplitude": 1.6, "snap": 1.0},
	],
}

static var _materials: Array[ShaderMaterial] = []
static var _prepared := {}


## À appeler une fois la carte instanciée.
static func apply(map: BattleMap) -> void:
	for layer in [map.ground(), map.ground_detail(), map.decor()]:
		if layer != null and layer.tile_set != null:
			_prepare(layer.tile_set)
	_refresh()
	if not Settings.changed.is_connected(_refresh):
		Settings.changed.connect(_refresh)


static func _prepare(tile_set: TileSet) -> void:
	var path := tile_set.resource_path
	if _prepared.has(path) or not (CONFIG.has(path) or WATER_TILESETS.has(path)):
		return
	_prepared[path] = true
	var source := tile_set.get_source(tile_set.get_source_id(0)) as TileSetAtlasSource
	if source == null or source.texture == null:
		return
	if WATER_TILESETS.has(path):
		_prepare_water(source)
	if not CONFIG.has(path):
		return
	var tex_size := Vector2(source.texture.get_size())
	var cell := Vector2(source.texture_region_size)
	for group in CONFIG[path]:
		for coords: Vector2i in group["coords"]:
			if not source.has_tile(coords):
				continue
			var material := ShaderMaterial.new()
			material.shader = SHADER
			var origin := Vector2(coords) * cell / tex_size
			var size := cell / tex_size
			material.set_shader_parameter("region", Vector4(origin.x, origin.y, size.x, size.y))
			material.set_shader_parameter("amplitude", group["amplitude"])
			material.set_shader_parameter("snap", group["snap"])
			source.get_tile_data(coords, 0).material = material
			_materials.append(material)


## Un seul matériau partagé par toutes les tuiles d'eau de l'atlas.
static func _prepare_water(source: TileSetAtlasSource) -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	for i in source.get_tiles_count():
		var coords := source.get_tile_id(i)
		var data := source.get_tile_data(coords, 0)
		if data.get_custom_data("water"):
			data.material = material
	_materials.append(material)


static func _refresh() -> void:
	var on := 1.0 if Settings.scenery_animation else 0.0
	for material in _materials:
		material.set_shader_parameter("strength", on)
