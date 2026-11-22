class_name FighterView
extends Node2D
## Pion temporaire : ombre, corps coloré, nom et barre de PV. Origine = centre de la case.

signal move_finished

const TEAM_COLORS: Array[Color] = [Color("e0574f"), Color("4f8fe0")]
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
	queue_redraw()


func refresh() -> void:
	queue_redraw()
	_body.queue_redraw()


## Anime le déplacement case par case le long du chemin.
func play_move(path: Array[Vector2i]) -> void:
	var tween := create_tween()
	for cell in path:
		tween.tween_property(self, "position", Iso.cell_to_world(cell), STEP_DURATION)
	tween.finished.connect(func() -> void: move_finished.emit())


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
	var color := TEAM_COLORS[fighter.team % TEAM_COLORS.size()]
	_body.draw_rect(Rect2(-10, -34, 20, 30), color.darkened(0.15))
	_body.draw_circle(Vector2(0, -40), 11.0, color)

	# Barre de PV
	var bar_pos := Vector2(-BAR_SIZE.x * 0.5, -62)
	var ratio := float(fighter.hp) / float(fighter.max_hp)
	_body.draw_rect(Rect2(bar_pos - Vector2(1, 1), BAR_SIZE + Vector2(2, 2)), Color(0, 0, 0, 0.7))
	var bar_color := Color("5bd16a") if ratio > 0.5 else (Color("e8c547") if ratio > 0.25 else Color("e0574f"))
	_body.draw_rect(Rect2(bar_pos, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), bar_color)

	# Nom
	var font := ThemeDB.fallback_font
	var label := "%s  %d" % [fighter.display_name, fighter.hp]
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	_body.draw_string(font, Vector2(-size.x * 0.5, -68), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
