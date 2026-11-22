class_name FloatingText
extends Node2D
## Chiffre de dégâts qui monte puis disparaît.

var text := ""
var color := Color.WHITE


static func spawn(parent: Node, world_pos: Vector2, p_text: String, p_color: Color) -> void:
	var ft := FloatingText.new()
	ft.text = p_text
	ft.color = p_color
	ft.position = world_pos + Vector2(0, -80)
	ft.z_index = 100
	parent.add_child(ft)
	var tween := ft.create_tween()
	tween.tween_property(ft, "position:y", ft.position.y - 40, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(ft, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tween.tween_callback(ft.queue_free)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	var pos := Vector2(-size.x * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
