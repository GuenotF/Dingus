class_name DestructionAnims
extends RefCounted
## Animations d'effondrement des obstacles destructibles (images du pack désert, « Destructible tiles »).
## Chaque planche (assets/destruction/<nom>_<nb images>.png) est une grille de 6 colonnes d'images de 256 px,
## jouées à 12 images par seconde : l'objet explose, puis il reste des gravats (ou rien pour la paille).
## Purement visuel. Pour associer une animation à une tuile, l'ajouter dans ASSIGNMENTS.

const FRAME := 256
const COLUMNS := 6
const FPS := 12.0
## Point de contact au sol dans une image (le tas de gravats y est centré).
const GROUND := Vector2(128, 205)

## nom -> { frames, scale (taille à l'écran), keep (les gravats restent au sol à la fin) }
const SHEETS := {
	"pierre_grand": {"frames": 17, "scale": 1.2, "keep": true},
	"mur_pierre": {"frames": 17, "scale": 0.65, "keep": true},
	"mur_bois": {"frames": 17, "scale": 0.7, "keep": true},
	"bois_petit": {"frames": 17, "scale": 0.9, "keep": true},
	"bois_grand": {"frames": 17, "scale": 0.85, "keep": true},
	"paille": {"frames": 16, "scale": 1.0, "keep": false},
	# Pack « Fantasy tileset - 2D Isometric » (Tree Green Explosion) : arbre feuillu qui éclate en branchages.
	"arbre_vert": {"frames": 16, "scale": 0.6, "keep": true},
}

## TileSet -> { case de l'atlas : nom de planche }
const ASSIGNMENTS := {
	"res://assets/tiles/desert/desert_tileset.tres": {
		Vector2i(0, 2): "pierre_grand", Vector2i(1, 2): "pierre_grand", Vector2i(2, 2): "pierre_grand",
		Vector2i(5, 2): "pierre_grand", Vector2i(2, 3): "mur_pierre",
	},
	"res://assets/tiles/village/barricade_tileset.tres": {
		Vector2i(2, 5): "mur_bois", Vector2i(3, 5): "mur_bois",
		Vector2i(3, 3): "bois_petit", Vector2i(5, 3): "bois_petit", Vector2i(6, 3): "bois_petit",
		Vector2i(7, 3): "bois_grand", Vector2i(4, 3): "bois_grand",
		Vector2i(0, 4): "paille", Vector2i(1, 4): "paille",
	},
	"res://assets/tiles/foret/foret_tileset.tres": {
		Vector2i(0, 1): "arbre_vert", Vector2i(1, 1): "arbre_vert", Vector2i(2, 1): "arbre_vert",
		Vector2i(7, 1): "bois_petit", Vector2i(0, 2): "bois_grand",
	},
}

## Matière de chaque planche : choisit le bruitage (assets/audio/sfx/hit_<matière>, destroy_<matière>).
const MATERIALS := {
	"pierre_grand": "pierre", "mur_pierre": "pierre",
	"mur_bois": "bois", "bois_petit": "bois", "bois_grand": "bois",
	"paille": "paille", "arbre_vert": "bois",
}

static var _cache := {}


## Matière de l'obstacle dont l'animation est `sheet` (pierre quand il n'y a pas d'animation).
static func material_for(sheet: String) -> String:
	return MATERIALS.get(sheet, "pierre")


## Nom de la planche associée à cette tuile, ou "" (alors l'effondrement est dessiné par le code).
static func sheet_for(tileset_path: String, coords: Vector2i) -> String:
	var table: Dictionary = ASSIGNMENTS.get(tileset_path, {})
	return table.get(coords, "")


## Images de l'animation `sheet` (créées une fois puis réutilisées).
static func frames_for(sheet: String) -> SpriteFrames:
	if _cache.has(sheet):
		return _cache[sheet]
	var info: Dictionary = SHEETS[sheet]
	var texture: Texture2D = load("res://assets/destruction/%s_%d.png" % [sheet, info.frames])
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", FPS)
	for i in info.frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((i % COLUMNS) * FRAME, (i / COLUMNS) * FRAME, FRAME, FRAME)
		frames.add_frame("default", atlas)
	_cache[sheet] = frames
	return frames
