class_name FloatingText
extends Node2D
## Chiffre de dégâts qui monte puis disparaît.

const LINE_HEIGHT := 30.0 # écart vertical entre deux chiffres qui apparaissent au même endroit
const NEAR := 70.0 # distance (px) en dessous de laquelle deux chiffres se gênent

var text := ""
var color := Color.WHITE
var start_pos := Vector2.ZERO # point d'origine demandé (avant décalage)

## Chiffres encore visibles : un nouveau chiffre se place au-dessus de ceux qui sont déjà là,
## pour que deux dégâts simultanés (coup + impact d'une poussée) restent lisibles.
static var _active: Array = []


## `world_pos` : point de départ (au-dessus de la tête, voir FighterView.text_anchor).
static func spawn(parent: Node, world_pos: Vector2, p_text: String, p_color: Color) -> void:
	var ft := FloatingText.new()
	ft.text = p_text
	ft.color = p_color
	var stacked := 0
	for other: FloatingText in _active:
		if is_instance_valid(other) and other.get_parent() == parent and other.start_pos.distance_to(world_pos) < NEAR:
			stacked += 1
	ft.start_pos = world_pos
	ft.position = world_pos - Vector2(0, LINE_HEIGHT * stacked)
	ft.z_index = 100
	parent.add_child(ft)
	_active.append(ft)
	ft.tree_exited.connect(func() -> void: _active.erase(ft))
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
