class_name FighterView
extends Node2D
## Affichage d'un combattant : sprite animé si sa classe en a un (CharacterSprites),
## sinon pion temporaire dessiné en code. Plus le nom, la barre de PV et les statuts.
## Origine = centre de la case (là où sont les pieds).

signal move_finished

const FALLBACK_COLORS: Array[Color] = [Color("e0574f"), Color("4f8fe0")]
const STEP_DURATION := 0.18
const BAR_SIZE := Vector2(44, 6)
const PAWN_HEIGHT := 51.0

var fighter: Fighter
var is_active := false:
	set(value):
		is_active = value
		queue_redraw()
		_ground_marker.queue_redraw()
## Direction de la grille vers laquelle le personnage regarde.
var facing := Vector2i(1, 0)

var _body := Node2D.new() # partie animée (recul, clignotement)
## Cercles au sol, dessinés au niveau du sol (sous le décor et les personnages) pour rester visibles.
var _ground_marker := Node2D.new()
var _sprite: AnimatedSprite2D
var _sprites: CharacterSprites
var _dead := false
## Aperçu du sort visé sur ce personnage (voir CombatState.preview_cast), vide sinon.
var _preview: Dictionary = {}
## Le curseur est sur ce personnage : ses PV s'affichent à côté de son nom.
var _hovered := false


func setup(p_fighter: Fighter) -> void:
	fighter = p_fighter
	position = Iso.cell_to_world(fighter.cell)
	_ground_marker.z_as_relative = false
	_ground_marker.z_index = 1 # sol = 0, effets au sol = 1, personnages = 2
	_ground_marker.draw.connect(_draw_ground_marker)
	add_child(_ground_marker)
	_body.draw.connect(_draw_body)
	add_child(_body)
	if fighter.class_data and fighter.class_data.sprites is CharacterSprites:
		_sprites = fighter.class_data.sprites
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = _sprites.sprite_frames()
		_sprite.centered = false
		_sprite.scale = Vector2.ONE * _sprites.scale
		_sprite.animation_finished.connect(_on_animation_finished)
		_body.add_child(_sprite)
		# Le texte doit passer devant le sprite : on le dessine dans un calque au-dessus.
		var labels := Node2D.new()
		labels.name = "Labels"
		labels.draw.connect(_draw_labels.bind(labels))
		_body.add_child(labels)
	# Au départ, chaque équipe regarde vers l'autre côté de la carte.
	facing = Vector2i(1, 0) if fighter.team == 0 else Vector2i(-1, 0)
	play_anim("idle")
	refresh()


func refresh() -> void:
	queue_redraw()
	_body.queue_redraw()
	if _sprite:
		_body.get_node("Labels").queue_redraw()


## Affiche (ou efface, avec {}) l'aperçu des dégâts / soins du sort visé.
func set_preview(preview: Dictionary) -> void:
	if preview == _preview:
		return
	_preview = preview
	refresh()


## Affiche les PV (chiffre) seulement quand le curseur survole le personnage.
func set_hovered(hovered: bool) -> void:
	if hovered == _hovered:
		return
	_hovered = hovered
	refresh()


func has_sprite() -> bool:
	return _sprite != null


## Point de départ des chiffres de dégâts / soins : au-dessus du nom et des statuts.
func text_anchor() -> Vector2:
	var top := _sprites.height * _sprites.scale if _sprites else PAWN_HEIGHT
	return position + Vector2(0, -top - 40 - 18 * fighter.statuses.size())


func body_color() -> Color:
	if fighter.class_data:
		return fighter.class_data.color
	return FALLBACK_COLORS[fighter.team % FALLBACK_COLORS.size()]


# --- Orientation et animations ---------------------------------------------------

## Tourne le personnage vers une case (axe dominant, comme sur la grille).
func face_cell(cell: Vector2i) -> void:
	var dir := CombatState.push_direction(fighter.cell, cell)
	if dir != Vector2i.ZERO:
		facing = dir


## Joue une animation dans la direction actuelle. Une animation non bouclée
## revient ensuite à « idle ». Sans sprite ou sans cette animation : ne fait rien.
func play_anim(anim_name: String) -> void:
	if _sprite == null or (_dead and anim_name != "die"):
		return
	if not _sprites.has_animation(anim_name):
		anim_name = "idle"
	var key := CharacterSprites.animation_key(anim_name, facing)
	if _sprite.sprite_frames.has_animation(key):
		# Les pieds ne sont pas au même endroit de l'image selon l'orientation.
		_sprite.position = -_sprites.feet_for(facing) * _sprites.scale
		_sprite.play(key)


func _on_animation_finished() -> void:
	if not _dead:
		play_anim("idle")


## Replace instantanément le pion sur sa case (placement).
func snap() -> void:
	position = Iso.cell_to_world(fighter.cell)


## Anime le déplacement case par case le long du chemin.
func play_move(path: Array[Vector2i]) -> void:
	var tween := create_tween()
	var previous := Iso.world_to_cell(position)
	for cell in path:
		var dir := cell - previous
		previous = cell
		tween.tween_callback(func() -> void:
			facing = dir
			play_anim("walk"))
		tween.tween_property(self, "position", Iso.cell_to_world(cell), STEP_DURATION)
	tween.tween_callback(func() -> void: play_anim("idle"))
	tween.finished.connect(func() -> void: move_finished.emit())


## Le lanceur se tourne vers sa cible et joue l'animation du sort.
func play_cast(anim_name: String, target: Vector2i) -> void:
	face_cell(target)
	play_anim(anim_name)


## Glissement direct (poussée, attraction, bond).
func play_slide(to_cell: Vector2i, is_jump: bool = false) -> void:
	var tween := create_tween()
	var target := Iso.cell_to_world(to_cell)
	if is_jump:
		var dir := CombatState.push_direction(Iso.world_to_cell(position), to_cell)
		if dir != Vector2i.ZERO:
			facing = dir
		play_anim("jump")
		tween.tween_property(self, "position", target, 0.45).set_trans(Tween.TRANS_QUAD)
		if _sprite == null: # le pion temporaire saute « à la main »
			tween.parallel().tween_property(_body, "position:y", -24.0, 0.22).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(_body, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN).set_delay(0.22)
	else:
		play_anim("hit")
		tween.tween_property(self, "position", target, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Recul, clignotement rouge et animation de coup reçu.
func play_hit(from_world: Vector2) -> void:
	refresh()
	if fighter.is_alive():
		play_anim("hit")
	var away := (position - from_world).normalized() * 8.0
	if away == Vector2.ZERO:
		away = Vector2(0, -6)
	var tween := create_tween()
	tween.tween_property(_body, "position", away, 0.06)
	tween.parallel().tween_property(_body, "modulate", Color(1.8, 0.6, 0.6), 0.06)
	tween.tween_property(_body, "position", Vector2.ZERO, 0.14)
	tween.parallel().tween_property(_body, "modulate", Color.WHITE, 0.14)


func play_heal() -> void:
	refresh()
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(0.7, 1.8, 0.8), 0.1)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.3)


func play_death() -> void:
	_dead = true
	var tween := create_tween()
	if _sprite:
		play_anim("die")
		tween.tween_interval(1.6) # on laisse l'animation se jouer
	else:
		tween.tween_interval(0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(hide)


# --- Dessin ------------------------------------------------------------------

func _draw_ground_marker() -> void:
	# Cercles au sol : ne bougent pas avec le corps. Les sprites ont déjà leur ombre.
	if fighter == null:
		return
	var m := _ground_marker
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	if _sprite == null:
		m.draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))
	# Cercle d'équipe, toujours visible : on repère la case de chaque personnage d'un coup d'œil.
	var team_color := FALLBACK_COLORS[fighter.team % FALLBACK_COLORS.size()]
	m.draw_circle(Vector2.ZERO, 21.0, Color(team_color, 0.22))
	m.draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 40, Color(team_color.lightened(0.15), 0.95), 2.5, true)
	# Cercle jaune autour : c'est à ce personnage de jouer.
	if is_active:
		m.draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(1, 0.9, 0.3), 3.0, true)
	m.draw_set_transform(Vector2.ZERO)


func _draw_body() -> void:
	if fighter == null:
		return
	if _sprite == null:
		var color := body_color()
		_body.draw_rect(Rect2(-10, -34, 20, 30), color.darkened(0.2))
		_body.draw_circle(Vector2(0, -40), 11.0, color)
		# Liseré d'équipe sous la tête, pour distinguer deux pions de même classe
		var team_color := FALLBACK_COLORS[fighter.team % FALLBACK_COLORS.size()]
		_body.draw_rect(Rect2(-10, -26, 20, 4), team_color.lightened(0.2))
		_draw_labels(_body)


## Nom, barre de PV et statuts, au-dessus de la tête (le chiffre des PV seulement au survol).
func _draw_labels(canvas: CanvasItem) -> void:
	if fighter == null:
		return
	var top := -(_sprites.height * _sprites.scale if _sprites else PAWN_HEIGHT)
	var font := ThemeDB.fallback_font

	# Liseré d'équipe sous la barre de PV (utile quand deux joueurs ont la même classe)
	var team_color := FALLBACK_COLORS[fighter.team % FALLBACK_COLORS.size()]
	var bar_pos := Vector2(-BAR_SIZE.x * 0.5, top - 11)
	var ratio := float(fighter.hp) / float(fighter.max_hp)
	canvas.draw_rect(Rect2(bar_pos - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.7))
	var bar_color := Color("5bd16a") if ratio > 0.5 else (Color("e8c547") if ratio > 0.25 else Color("e0574f"))
	var dmg_min: int = _preview.get("damage_min", 0)
	var dmg_max: int = _preview.get("damage_max", 0)
	var heal_max: int = _preview.get("heal_max", 0)
	if dmg_max > 0:
		# Part claire = ce que le sort peut retirer ; le reste = PV restants au pire.
		var after := clampf(float(fighter.hp - dmg_max) / float(fighter.max_hp), 0.0, 1.0)
		canvas.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), Color("f2c9c4"))
		canvas.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * after, BAR_SIZE.y)), bar_color)
	elif heal_max > 0:
		var healed := clampf(float(fighter.hp + heal_max) / float(fighter.max_hp), 0.0, 1.0)
		canvas.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * healed, BAR_SIZE.y)), Color("b9f0c3"))
		canvas.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), bar_color)
	else:
		canvas.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), bar_color)
	if _sprite:
		canvas.draw_rect(Rect2(bar_pos + Vector2(0, BAR_SIZE.y + 1), Vector2(BAR_SIZE.x, 2)), team_color)

	# Pastille de PV (au survol seulement) : entre le nom et la barre de vie
	var shift := 0.0
	if _hovered:
		_draw_hp_pill(canvas, font, top - 30.0, bar_color)
		shift = 20.0

	# Nom
	var label := fighter.display_name
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var name_pos := Vector2(-size.x * 0.5, top - 17 - shift)
	canvas.draw_string_outline(font, name_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.8))
	canvas.draw_string(font, name_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	# Statuts (bonus en vert, malus en orange) au-dessus du nom
	var y := top - 35 - shift
	for s in fighter.statuses:
		var text := s.label()
		var tsize := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var col := Color("7be08a") if s.amount > 0 else Color("ffab5c")
		var rect := Rect2(Vector2(-tsize.x * 0.5 - 4, y - 12), Vector2(tsize.x + 8, 16))
		canvas.draw_rect(rect, Color(0, 0, 0, 0.7))
		canvas.draw_string(font, Vector2(-tsize.x * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		y -= 18.0

	# Aperçu du sort visé : dégâts possibles (ou K.O.), soin
	var preview_text := ""
	var preview_color := Color("f08a6a")
	if dmg_max > 0:
		if dmg_min >= fighter.hp:
			preview_text = "K.O."
			preview_color = Color("ff5a4f")
		else:
			preview_text = ("−%d" % dmg_min if dmg_min == dmg_max else "−%d à −%d" % [dmg_min, dmg_max])
			if dmg_max >= fighter.hp:
				preview_text += "  (K.O. possible)"
	elif heal_max > 0:
		var heal_min: int = _preview.get("heal_min", 0)
		preview_text = "+%d" % heal_min if heal_min == heal_max else "+%d à +%d" % [heal_min, heal_max]
		preview_color = Color("7be08a")
	if preview_text != "":
		var psize := font.get_string_size(preview_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var ppos := Vector2(-psize.x * 0.5, y - 2)
		canvas.draw_string_outline(font, ppos, preview_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.85))
		canvas.draw_string(font, ppos, preview_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, preview_color)


## Pastille « ♥ PV / PV max » : fond sombre arrondi, liseré de la couleur de la barre.
## `top` est le haut de la pastille (hauteur 16), centrée sur le personnage.
func _draw_hp_pill(canvas: CanvasItem, font: Font, top: float, accent: Color) -> void:
	var current := str(fighter.hp)
	var maximum := " / %d" % fighter.max_hp
	var fs := 12
	var w_cur := font.get_string_size(current, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w_max := font.get_string_size(maximum, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var heart := 10.0
	var width := heart + 5.0 + w_cur + w_max + 14.0
	var rect := Rect2(Vector2(-width * 0.5, top), Vector2(width, 16))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.88)
	sb.border_color = accent.darkened(0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	canvas.draw_style_box(sb, rect)
	# Petit cœur
	var hc := Vector2(rect.position.x + 7.0 + heart * 0.5, top + 8.0)
	canvas.draw_circle(hc + Vector2(-2.2, -1.5), 2.8, accent)
	canvas.draw_circle(hc + Vector2(2.2, -1.5), 2.8, accent)
	canvas.draw_colored_polygon(PackedVector2Array([hc + Vector2(-4.9, -0.5), hc + Vector2(4.9, -0.5), hc + Vector2(0, 4.6)]), accent)
	# Chiffres : PV actuels en clair, PV max en gris
	var x := rect.position.x + 7.0 + heart + 5.0
	var baseline := top + 12.0
	canvas.draw_string(font, Vector2(x, baseline), current, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent.lightened(0.55))
	canvas.draw_string(font, Vector2(x + w_cur, baseline), maximum, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("a99f8a"))
