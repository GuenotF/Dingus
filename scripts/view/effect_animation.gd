class_name EffectAnimation
extends Resource
## Effet visuel animé (projectile ou impact) : une planche d'images sur une seule ligne
## (data/effects/*.tres). Utilisé par les champs `projectile` et `impact` des sorts.

@export var texture: Texture2D
@export var frames: int = 15
@export var fps: float = 30.0
@export var loop: bool = false
## Point de l'image (en pixels) placé sur la position de l'effet :
## la tête d'un projectile, le centre d'un impact.
@export var origin: Vector2 = Vector2.ZERO
## Échelle d'affichage. Un impact peut être aplati (y plus petit) pour suivre la vue isométrique.
@export var scale: Vector2 = Vector2.ONE
## Effet au sol (zone, explosion) : dessiné sous les personnages. Sinon au-dessus.
@export var on_ground: bool = false
## Mélange additif : idéal pour le feu et la magie (lumineux, laisse voir le sol).
@export var additive: bool = true
## Pour un projectile : vitesse en pixels par seconde.
@export var speed: float = 900.0

var _cache: SpriteFrames


func frame_size() -> Vector2:
	return Vector2(texture.get_width() / float(frames), texture.get_height())


func sprite_frames() -> SpriteFrames:
	if _cache:
		return _cache
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	var size := frame_size()
	for i in frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * size.x, 0, size.x, size.y)
		sf.add_frame("default", atlas)
	_cache = sf
	return sf
