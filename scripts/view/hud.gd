class_name Hud
extends CanvasLayer
## Interface : joueur actif, barre de sorts, fin de tour, écran de victoire.

signal end_turn_pressed
signal spell_pressed(index: int)
signal restart_pressed

var _info: Label
var _end_turn: Button
var _spell_bar: HBoxContainer
var _spell_buttons: Array[Button] = []
var _spell_info: Label
var _victory: Control
var _victory_label: Label


func _ready() -> void:
	# --- Haut gauche : infos du tour
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
	_end_turn.focus_mode = Control.FOCUS_NONE
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	box.add_child(_end_turn)

	# --- Bas : barre de sorts + description
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -16
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_spell_info = Label.new()
	_spell_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spell_info.add_theme_font_size_override("font_size", 15)
	_spell_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_spell_info.add_theme_constant_override("outline_size", 4)
	bottom.add_child(_spell_info)
	_spell_bar = HBoxContainer.new()
	_spell_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_spell_bar.add_theme_constant_override("separation", 8)
	bottom.add_child(_spell_bar)

	# --- Écran de victoire
	_victory = ColorRect.new()
	_victory.color = Color(0, 0, 0, 0.6)
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.hide()
	add_child(_victory)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	_victory_label = Label.new()
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_victory_label)
	var restart := Button.new()
	restart.text = "Rejouer"
	restart.custom_minimum_size = Vector2(200, 48)
	restart.add_theme_font_size_override("font_size", 22)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	vbox.add_child(restart)


func show_fighter(fighter: Fighter, turn_number: int) -> void:
	_info.text = "Tour %d — %s\nPV %d/%d   PA %d   PM %d" % [
		turn_number, fighter.display_name, fighter.hp, fighter.max_hp, fighter.pa, fighter.pm,
	]


## Reconstruit et met à jour la barre de sorts du combattant actif.
func show_spells(state: CombatState, selected: SpellData) -> void:
	var fighter := state.active_fighter()
	if fighter == null:
		return
	while _spell_buttons.size() < fighter.spells.size():
		var button := Button.new()
		var index := _spell_buttons.size()
		button.custom_minimum_size = Vector2(150, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.pressed.connect(func() -> void: spell_pressed.emit(index))
		_spell_bar.add_child(button)
		_spell_buttons.append(button)
	for i in _spell_buttons.size():
		var button := _spell_buttons[i]
		button.visible = i < fighter.spells.size()
		if not button.visible:
			continue
		var spell := fighter.spells[i]
		button.text = "%d · %s\n%d PA" % [i + 1, spell.spell_name, spell.pa_cost]
		button.disabled = not state.can_use_spell(spell)
		button.set_pressed_no_signal(spell == selected)
	_spell_info.text = _describe(selected) if selected else "Clic : se déplacer   ·   1-3 : choisir un sort"


func _describe(spell: SpellData) -> String:
	var parts: Array[String] = [spell.spell_name]
	parts.append("portée %d-%d" % [spell.range_min, spell.range_max] if spell.range_min != spell.range_max else "portée %d" % spell.range_max)
	parts.append("%d-%d dégâts" % [spell.damage_min, spell.damage_max])
	if spell.area == SpellData.AreaShape.CROSS:
		parts.append("zone en croix")
	if not spell.needs_line_of_sight:
		parts.append("sans ligne de vue")
	parts.append("%d/tour" % spell.casts_per_turn)
	return "  ·  ".join(parts) + "\nClic : lancer   ·   Clic droit / Échap : annuler"


func set_input_enabled(enabled: bool) -> void:
	_end_turn.disabled = not enabled


func show_victory(winner_name: String) -> void:
	_victory_label.text = "%s gagne !" % winner_name if winner_name != "" else "Égalité !"
	_victory.show()
	_end_turn.disabled = true
