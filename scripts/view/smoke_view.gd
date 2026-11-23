class_name SmokeView
extends Node2D
## Affiche les nuages de fumée (CombatState.smoke_added / smoke_removed) : des bouffées grises
## qui flottent doucement sur chaque case, au-dessus des personnages (ils restent entrevus).
## Texture dessinée par le code : aucun fichier image.

const PUFF_ALPHA := 0.62
const FADE_IN := 0.5
const FADE_OUT := 0.45

var _texture: ImageTexture
var _cells: Dictionary = {} # Vector2i -> Array[Sprite2D]


func _ready() -> void:
	z_index = 20 # au-dessus des personnages (2) et des effets au sol (1), sous les projectiles (50)
	_texture = _cloud_texture()


## Fait apparaître la fumée sur ces cases.
func add_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if _cells.has(cell):
			continue
		var puffs: Array = []
		var center := Iso.cell_to_world(cell) + Vector2(0, -6)
		for i in 2:
			var sprite := Sprite2D.new()
			sprite.texture = _texture
			sprite.position = center + Vector2(-9 + i * 18, -3 + i * 6)
			sprite.scale = Vector2(0.95, 0.6) * (1.0 + 0.12 * i)
			sprite.modulate = Color(1, 1, 1, 0)
			add_child(sprite)
			puffs.append(sprite)
			var fade := sprite.create_tween()
			fade.tween_property(sprite, "modulate:a", PUFF_ALPHA, FADE_IN)
			# Dérive lente et infinie pour que le nuage ne soit pas figé.
			var drift := sprite.create_tween().set_loops()
			var base := sprite.position
			var offset := Vector2(4.0 - i * 8.0, 2.5)
			drift.tween_property(sprite, "position", base + offset, 1.4 + 0.3 * i).set_trans(Tween.TRANS_SINE)
			drift.tween_property(sprite, "position", base - offset, 1.4 + 0.3 * i).set_trans(Tween.TRANS_SINE)
		_cells[cell] = puffs


## Fait disparaître la fumée de ces cases.
func remove_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not _cells.has(cell):
			continue
		for sprite in _cells[cell]:
			var fade := (sprite as Sprite2D).create_tween()
			fade.tween_property(sprite, "modulate:a", 0.0, FADE_OUT)
			fade.tween_callback(sprite.queue_free)
		_cells.erase(cell)


## Nuage mou : quelques disques flous superposés, bords transparents.
static func _cloud_texture() -> ImageTexture:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	for i in 7:
		centers.append(Vector2(rng.randf_range(0.32, 0.68), rng.randf_range(0.34, 0.66)) * size)
		radii.append(rng.randf_range(0.2, 0.3) * size)
	for y in size:
		for x in size:
			var density: float = 0.0
			for i in centers.size():
				var d: float = Vector2(x, y).distance_to(centers[i]) / radii[i]
				density = maxf(density, clampf(1.0 - d, 0.0, 1.0))
			var shade: float = 0.74 + 0.1 * density
			img.set_pixel(x, y, Color(shade, shade, shade + 0.02, pow(density, 0.75)))
	return ImageTexture.create_from_image(img)
