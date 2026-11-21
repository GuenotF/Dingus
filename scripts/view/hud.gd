class_name Hud
extends CanvasLayer
## Interface minimale : joueur actif, PV/PA/PM, bouton de fin de tour.

signal end_turn_pressed

var _info: Label
var _end_turn: Button


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	box.add_child(_info)

	_end_turn = Button.new()
	_end_turn.text = "Fin du tour (Espace)"
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	box.add_child(_end_turn)


func show_fighter(fighter: Fighter, turn_number: int) -> void:
	_info.text = "Tour %d — %s\nPV %d/%d   PA %d   PM %d" % [
		turn_number, fighter.display_name, fighter.hp, fighter.max_hp, fighter.pa, fighter.pm,
	]


func set_input_enabled(enabled: bool) -> void:
	_end_turn.disabled = not enabled
