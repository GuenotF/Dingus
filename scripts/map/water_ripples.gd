class_name WaterRipples
extends Node2D
## Ondulations animées posées sur les cases d'eau de la carte (purement visuel :
## aucun effet sur la grille, le déplacement ou la ligne de vue).
##
## À placer comme enfant d'un BattleMap, après les calques de sol. Chaque case d'eau reçoit,
## avec la probabilité `coverage`, une animation de la planche `sheet` (images côte à côte),
## avec une image de départ et une vitesse différentes pour que ça ne bouge pas à l'unisson.

@export var sheet: Texture2D
@export var frame_count: int = 16
@export var frame_size: Vector2i = Vector2i(128, 128)
@export var fps_min: float = 5.0
@export var fps_max: float = 8.0
## Part des cases d'eau qui reçoivent une ondulation (0 à 1).
@export_range(0.0, 1.0) var coverage: float = 0.75
## Décalage de l'image par rapport au centre de la case (même réglage que texture_origin des tuiles).
@export var sprite_offset: Vector2 = Vector2(0, -40)


func _ready() -> void:
	var map := get_parent() as BattleMap
	if map == null or sheet == null:
		return
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 1.0)
	for i in frame_count:
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(Vector2(i * frame_size.x, 0), Vector2(frame_size))
		frames.add_frame("default", tex)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260
	for cell in map.water():
		if rng.randf() > coverage:
			continue
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.position = map.ground().map_to_local(cell) + sprite_offset
		sprite.speed_scale = rng.randf_range(fps_min, fps_max)
		sprite.frame = rng.randi() % frame_count
		sprite.play("default")
		add_child(sprite)
