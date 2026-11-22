class_name FighterView
extends Node2D
## Pion temporaire : ombre, corps à la couleur de la classe, nom, PV et statuts.
## Origine = centre de la case.

signal move_finished

const FALLBACK_COLORS: Array[Color] = [Color("e0574f"), Color("4f8fe0")]
const STEP_DURATION := 0.18
const BAR_SIZE := Vector2(44, 6)

var fighter: Fighter
var is_active := false:
	set(value):
		is_active = value
		queue_redraw()

var _body := Node2D.new() # partie animée (recul, clignotement)


func setup(p_fighter: Fighter) -> void:
	fighter = p_fighter
	position = Iso.cell_to_world(fighter.cell)
	_body.draw.connect(_draw_body)
	add_child(_body)
	refresh()


func refresh() -> void:
	queue_redraw()
	_body.queue_redraw()


func body_color() -> Color:
	if fighter.class_data:
		return fighter.class_data.color
	return FALLBACK_COLORS[fighter.team % FALLBACK_COLORS.size()]


## Replace instantanément le pion sur sa case (placement).
func snap() -> void:
	position = Iso.cell_to_world(fighter.cell)


## Anime le déplacement case par case le long du chemin.
func play_move(path: Array[Vector2i]) -> void:
	var tween := create_tween()
	for cell in path:
		tween.tween_property(self, "position", Iso.cell_to_world(cell), STEP_DURATION)
	tween.finished.connect(func() -> void: move_finished.emit())


## Glissement direct (poussée, attraction, bond).
func play_slide(to_cell: Vector2i, is_jump: bool = false) -> void:
	var tween := create_tween()
	var target := Iso.cell_to_world(to_cell)
	if is_jump:
		tween.tween_property(self, "position", target, 0.3).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(_body, "position:y", -24.0, 0.15).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_body, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN).set_delay(0.15)
	else:
		tween.tween_property(self, "position", target, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Petit recul et clignotement rouge quand le pion est touché.
func play_hit(from_world: Vector2) -> void:
	refresh()
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
	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hide)


func _draw() -> void:
	# Ombre et anneau du joueur actif : ne bougent pas avec le corps
	if fighter == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))
	if is_active:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_body() -> void:
	if fighter == null:
		return
	var color := body_color()
	_body.draw_rect(Rect2(-10, -34, 20, 30), color.darkened(0.2))
	_body.draw_circle(Vector2(0, -40), 11.0, color)
	# Liseré d'équipe sous la tête, pour distinguer deux pions de même classe
	var team_color := FALLBACK_COLORS[fighter.team % FALLBACK_COLORS.size()]
	_body.draw_rect(Rect2(-10, -26, 20, 4), team_color.lightened(0.2))

	# Barre de PV
	var bar_pos := Vector2(-BAR_SIZE.x * 0.5, -62)
	var ratio := float(fighter.hp) / float(fighter.max_hp)
	_body.draw_rect(Rect2(bar_pos - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.7))
	var bar_color := Color("5bd16a") if ratio > 0.5 else (Color("e8c547") if ratio > 0.25 else Color("e0574f"))
	_body.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), bar_color)

	var font := ThemeDB.fallback_font
	# Nom + PV
	var label := "%s  %d" % [fighter.display_name, fighter.hp]
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	_body.draw_string_outline(font, Vector2(-size.x * 0.5, -68), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.8))
	_body.draw_string(font, Vector2(-size.x * 0.5, -68), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

	# Statuts (bonus en vert, malus en orange) au-dessus du nom, pour ne jamais être
	# cachés par un bloc placé devant le pion.
	var y := -86.0
	for s in fighter.statuses:
		var text := s.label()
		var tsize := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var col := Color("7be08a") if s.amount > 0 else Color("ffab5c")
		var rect := Rect2(Vector2(-tsize.x * 0.5 - 4, y - 12), Vector2(tsize.x + 8, 16))
		_body.draw_rect(rect, Color(0, 0, 0, 0.7))
		_body.draw_string(font, Vector2(-tsize.x * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		y -= 18.0
