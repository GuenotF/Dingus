class_name FighterView
extends Node2D
## Pion temporaire : ombre, corps coloré et nom. Origine = centre de la case.

signal move_finished

const TEAM_COLORS: Array[Color] = [Color("e0574f"), Color("4f8fe0")]
const STEP_DURATION := 0.18

var fighter: Fighter
var is_active := false:
	set(value):
		is_active = value
		queue_redraw()


func setup(p_fighter: Fighter) -> void:
	fighter = p_fighter
	position = Iso.cell_to_world(fighter.cell)
	queue_redraw()


## Anime le déplacement case par case le long du chemin.
func play_move(path: Array[Vector2i]) -> void:
	var tween := create_tween()
	for cell in path:
		tween.tween_property(self, "position", Iso.cell_to_world(cell), STEP_DURATION)
	tween.finished.connect(func() -> void: move_finished.emit())


func _draw() -> void:
	if fighter == null:
		return
	var color := TEAM_COLORS[fighter.team % TEAM_COLORS.size()]
	# Ombre
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))
	if is_active:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(1, 0.9, 0.3), 3.0, true)
	draw_set_transform(Vector2.ZERO)
	# Corps
	draw_rect(Rect2(-10, -34, 20, 30), color.darkened(0.15))
	draw_circle(Vector2(0, -40), 11.0, color)
	# Nom
	var font := ThemeDB.fallback_font
	var label := fighter.display_name
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, Vector2(-size.x * 0.5, -58), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
