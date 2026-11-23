class_name ObstacleView
extends Node2D
## Affichage des obstacles destructibles. Chaque destructible de la carte est retiré du calque
## de décor et remplacé par un sprite : on peut ainsi le secouer, l'assombrir quand il s'abîme,
## le faire s'effondrer, et dessiner sa barre de PV. Purement visuel : la logique est dans
## BattleGrid / CombatState (signaux obstacle_damaged et obstacle_destroyed).

const Z_BAR := 90
const BAR_W := 46.0
const BAR_H := 6.0
const SHOW_AFTER_HIT := 1.6 # secondes pendant lesquelles la barre reste affichée après un coup

## Cases -> { sprite, anchor (haut du sprite, repère monde), hp, max_hp, color (couleur moyenne), shown_until }
var _props: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _preview: Dictionary = {} # case -> dégâts maximum prévus du sort sélectionné
var _ground: Node2D # gravats posés au sol
var _images: Dictionary = {} # texture -> Image (pour mesurer les sprites une seule fois)


## `entities` : conteneur trié par Y des personnages ; `ground_parent` : où poser les gravats.
func setup(grid: BattleGrid, decor: TileMapLayer, detail: TileMapLayer, entities: Node2D, ground_parent: Node2D) -> void:
	z_index = Z_BAR
	_ground = Node2D.new()
	_ground.z_index = EffectView.Z_GROUND
	ground_parent.add_child(_ground)
	for cell in grid.get_destructibles():
		for layer in [decor, detail]:
			if layer != null and _convert(layer, cell, grid, entities):
				break


## Remplace la tuile de `cell` par un sprite. Renvoie false si ce calque n'a pas de tuile ici.
func _convert(layer: TileMapLayer, cell: Vector2i, grid: BattleGrid, entities: Node2D) -> bool:
	if layer.get_cell_source_id(cell) == -1:
		return false
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var data := layer.get_cell_tile_data(cell)
	if source == null or data == null or not data.get_custom_data(BattleMap.OBSTACLE):
		return false
	var region := source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))

	var sprite := Sprite2D.new()
	sprite.texture = source.texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.offset = -Vector2(data.texture_origin)
	sprite.scale = layer.scale
	sprite.texture_filter = layer.texture_filter
	sprite.position = layer.position + layer.map_to_local(cell) * layer.scale
	entities.add_child(sprite)
	var anim := DestructionAnims.sheet_for(layer.tile_set.resource_path, layer.get_cell_atlas_coords(cell))
	layer.erase_cell(cell)

	var info := _measure(source.texture, region)
	var top: float = info.top - region.size.y * 0.5 # haut visible du sprite, par rapport à son centre
	_props[cell] = {
		"sprite": sprite,
		"anchor": sprite.position + (sprite.offset + Vector2(0, top)) * sprite.scale,
		"hp": grid.destructible_hp(cell),
		"max_hp": grid.destructible_max_hp(cell),
		"color": info.color,
		"shown_until": 0.0,
		"anim": anim,
	}
	return true


## Haut visible (première ligne non transparente) et couleur moyenne d'une zone de la texture.
func _measure(texture: Texture2D, region: Rect2) -> Dictionary:
	if not _images.has(texture):
		_images[texture] = texture.get_image()
	var image: Image = _images[texture]
	var part := image.get_region(Rect2i(region))
	var used := part.get_used_rect()
	var sum := Vector3.ZERO
	var count := 0
	for y in range(used.position.y, used.end.y, 2):
		for x in range(used.position.x, used.end.x, 2):
			var c := part.get_pixel(x, y)
			if c.a > 0.5:
				sum += Vector3(c.r, c.g, c.b)
				count += 1
	var avg := Color(0.6, 0.55, 0.5) if count == 0 else Color(sum.x / count, sum.y / count, sum.z / count)
	return {"top": float(used.position.y), "color": avg}


# --- Événements de combat ----------------------------------------------------------

func hit(cell: Vector2i, amount: int, hp_left: int) -> void:
	if not _props.has(cell):
		return
	var prop: Dictionary = _props[cell]
	prop.hp = hp_left
	prop.shown_until = _now() + SHOW_AFTER_HIT
	var sprite: Sprite2D = prop.sprite
	# Plus l'obstacle est abîmé, plus il s'assombrit.
	var wear := 1.0 - float(hp_left) / float(prop.max_hp)
	sprite.modulate = Color.WHITE.lerp(Color(0.62, 0.58, 0.56), wear)
	# Secousse horizontale.
	var x := sprite.position.x
	var tween := sprite.create_tween()
	for dx in [4.0, -4.0, 2.5, -2.0, 0.0]:
		tween.tween_property(sprite, "position:x", x + dx, 0.04)
	_burst(prop.anchor + Vector2(0, 26.0), prop.color, 7)
	FloatingText.spawn(get_parent(), prop.anchor + Vector2(0, -34), "-%d" % amount, Color("f2c879"))
	queue_redraw()


func destroy(cell: Vector2i) -> void:
	if not _props.has(cell):
		return
	var prop: Dictionary = _props[cell]
	_props.erase(cell)
	var sprite: Sprite2D = prop.sprite
	if prop.anim != "":
		_play_destruction(prop.anim, sprite)
		return
	_burst(prop.anchor + Vector2(0, 30.0), prop.color, 30)
	_add_rubble(sprite.position, prop.color)
	var tween := sprite.create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y + 8.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "scale:y", sprite.scale.y * 0.55, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(sprite.queue_free)
	queue_redraw()


## Effondrement animé (images du pack) : le sprite d'origine s'efface vite pendant que l'animation démarre,
## puis les gravats passent au sol (ou disparaissent, pour la paille).
func _play_destruction(sheet: String, sprite: Sprite2D) -> void:
	var info: Dictionary = DestructionAnims.SHEETS[sheet]
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = DestructionAnims.frames_for(sheet)
	anim.texture_filter = sprite.texture_filter
	anim.scale = Vector2.ONE * float(info.scale) * sprite.scale.x
	# Le point de contact au sol de l'image est placé sur le pied de l'obstacle.
	anim.offset = Vector2(DestructionAnims.FRAME * 0.5, DestructionAnims.FRAME * 0.5) - DestructionAnims.GROUND
	anim.position = sprite.position
	var entities := sprite.get_parent()
	entities.add_child(anim)
	anim.play("default")
	anim.animation_finished.connect(func() -> void:
		if info.keep:
			anim.reparent(_ground)
		else:
			anim.queue_free())
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.12)
	tween.tween_callback(sprite.queue_free)
	queue_redraw()


## Éclats projetés par un coup ou par l'effondrement.
func _burst(world_pos: Vector2, color: Color, amount: int) -> void:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var p := CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = world_pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([color.lightened(0.15), color, Color(color, 0.0)])
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)


## Quelques éclats au sol à l'emplacement de l'obstacle détruit.
func _add_rubble(world_pos: Vector2, color: Color) -> void:
	var rubble := Rubble.new()
	rubble.position = world_pos + Vector2(0, 0)
	rubble.color = color
	rubble.seed_value = int(world_pos.x * 31.0 + world_pos.y * 17.0)
	_ground.add_child(rubble)


class Rubble extends Node2D:
	var color := Color(0.6, 0.55, 0.5)
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in 9:
			var c := Vector2(rng.randf_range(-22.0, 22.0), rng.randf_range(-9.0, 9.0))
			var r := rng.randf_range(2.0, 5.5)
			var shade := color.darkened(rng.randf_range(0.25, 0.5))
			var chip := PackedVector2Array([
				c + Vector2(-r, 0), c + Vector2(-r * 0.3, -r * 0.7), c + Vector2(r, -r * 0.2),
				c + Vector2(r * 0.6, r * 0.6), c + Vector2(-r * 0.5, r * 0.5)])
			draw_colored_polygon(chip, shade)
			# Contour sombre : les éclats ressortent sur un sol de même teinte.
			chip.append(chip[0])
			draw_polyline(chip, color.darkened(0.7), 1.0)


# --- Survol, aperçu et barre de PV ----------------------------------------------------

## `hover` : case sous la souris ; `preview` : case -> dégâts maximum prévus (sort sélectionné).
func set_hover(hover: Vector2i, preview: Dictionary = {}) -> void:
	if hover == _hover and preview == _preview:
		return
	_hover = hover
	_preview = preview
	queue_redraw()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	# La barre disparaît seule quelque temps après un coup.
	for cell in _props:
		var prop: Dictionary = _props[cell]
		if prop.shown_until > 0.0:
			if _now() > prop.shown_until:
				prop.shown_until = 0.0 # dernier redessin : la barre s'efface
			queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for cell in _props:
		var prop: Dictionary = _props[cell]
		var recent: bool = prop.shown_until > _now()
		if not recent and cell != _hover and not _preview.has(cell):
			continue
		var hp: int = prop.hp
		var max_hp: int = prop.max_hp
		var pos: Vector2 = prop.anchor + Vector2(-BAR_W * 0.5, -14.0)
		var ratio := float(hp) / float(max_hp)
		draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(BAR_W + 3.0, BAR_H + 3.0)), Color(0.05, 0.05, 0.07, 0.9))
		var fill := Color("d8c79a") if ratio > 0.5 else (Color("e39a4a") if ratio > 0.25 else Color("d9534f"))
		draw_rect(Rect2(pos, Vector2(BAR_W * ratio, BAR_H)), fill)
		var label := "%d / %d" % [hp, max_hp]
		if _preview.has(cell):
			# Dégâts prévus : segment rouge à la fin de la barre.
			var dmg: int = mini(_preview[cell], hp)
			var left := float(hp - dmg) / float(max_hp)
			draw_rect(Rect2(pos + Vector2(BAR_W * left, 0), Vector2(BAR_W * (ratio - left), BAR_H)), Color("ff4d3d"))
			label = "%d → %d" % [hp, hp - dmg]
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var text_pos := Vector2(pos.x + BAR_W * 0.5 - size.x * 0.5, pos.y - 4.0)
		draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2ead8"))
