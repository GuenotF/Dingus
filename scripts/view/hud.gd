class_name Hud
extends CanvasLayer
## Interface de combat. En bas au centre : orbe de PV, PA / PM, cases de sorts, fin du tour.
## En haut à droite : numéro du tour et ordre de jeu. Infobulle au survol d'un sort.
## L'aperçu des dégâts au survol d'une cible est dessiné par FighterView.

signal main_button_pressed # « Fin du tour » ou « Prêt » selon la phase
signal spell_pressed(index: int)
signal restart_pressed
signal menu_pressed

const TOOLTIP_WIDTH := 270


var _state: CombatState
var _selected: SpellData
var _hovered_slot := -1
## Vrai après un clic sur la case survolée : l'infobulle reste cachée jusqu'à ce que la souris en sorte.
var _tooltip_dismissed := false

# Barre du bas
var _bar: PanelContainer
var _orb: HudWidgets.HpOrb
var _pa: HudWidgets.ResourceBadge
var _pm: HudWidgets.ResourceBadge
var _stats_box: Control
var _spell_box: HBoxContainer
var _slots: Array[HudWidgets.SpellSlot] = []
var _separators: Array[Control] = []
var _main_button: Button
var _hint: Label

# Haut droite
var _turn_label: Label
var _chips_box: HBoxContainer
var _chips: Array[HudWidgets.FighterChip] = []

# Infobulle
var _tooltip: PanelContainer
var _tt_name: Label
var _tt_cost: Label
var _tt_range: Label
var _tt_effects: Label
var _tt_status: Label
var _tt_hint: Label

var _victory: Control
var _victory_label: Label


func _ready() -> void:
	_build_bottom_bar()
	_build_turn_order()
	_build_tooltip()
	_build_victory()


# --- Construction ----------------------------------------------------------------

func _build_bottom_bar() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -14
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", HudWidgets.TEXT)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	bottom.add_child(_hint)

	_bar = PanelContainer.new()
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.add_theme_stylebox_override("panel", HudWidgets.panel_style())
	bottom.add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bar.add_child(row)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	row.add_child(stats)
	_stats_box = stats
	_orb = HudWidgets.HpOrb.new()
	stats.add_child(_orb)
	var res := VBoxContainer.new()
	res.alignment = BoxContainer.ALIGNMENT_CENTER
	res.add_theme_constant_override("separation", 8)
	stats.add_child(res)
	_pa = HudWidgets.ResourceBadge.new(true)
	_pm = HudWidgets.ResourceBadge.new(false)
	res.add_child(_pa)
	res.add_child(_pm)

	_separators.append(_separator())
	row.add_child(_separators[-1])
	_spell_box = HBoxContainer.new()
	_spell_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_spell_box.add_theme_constant_override("separation", 10)
	row.add_child(_spell_box)
	_separators.append(_separator())
	row.add_child(_separators[-1])

	_main_button = Button.new()
	_main_button.focus_mode = Control.FOCUS_NONE
	_main_button.custom_minimum_size = Vector2(120, 64)
	_main_button.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.bg_color = {"normal": HudWidgets.GOLD, "hover": HudWidgets.GOLD.lightened(0.15), "pressed": HudWidgets.GOLD.darkened(0.15), "disabled": Color("3a3f4b")}[state]
		_main_button.add_theme_stylebox_override(state, sb)
	_main_button.add_theme_color_override("font_color", Color("1b1408"))
	_main_button.add_theme_color_override("font_hover_color", Color("1b1408"))
	_main_button.add_theme_color_override("font_pressed_color", Color("1b1408"))
	_main_button.add_theme_color_override("font_disabled_color", Color("8a8578"))
	_main_button.pressed.connect(func() -> void: main_button_pressed.emit())
	row.add_child(_main_button)


func _separator() -> Control:
	var sep := ColorRect.new()
	sep.color = HudWidgets.PANEL_BORDER
	sep.custom_minimum_size = Vector2(1, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sep


func _build_turn_order() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -16
	box.offset_top = 16
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var turn_panel := PanelContainer.new()
	turn_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	turn_panel.add_theme_stylebox_override("panel", HudWidgets.panel_style(HudWidgets.PANEL_BORDER, 6, 6))
	box.add_child(turn_panel)
	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 16)
	_turn_label.add_theme_color_override("font_color", HudWidgets.GOLD)
	turn_panel.add_child(_turn_label)
	_chips_box = HBoxContainer.new()
	_chips_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	_chips_box.add_theme_constant_override("separation", 8)
	box.add_child(_chips_box)


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	var sb := HudWidgets.panel_style(Color("5a5040"), 8, 12)
	sb.bg_color = Color(0.055, 0.063, 0.082, 0.96)
	_tooltip.add_theme_stylebox_override("panel", sb)
	_tooltip.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.hide()
	add_child(_tooltip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_tooltip.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_tt_name = _label(16, Color("f1e3c2"))
	_tt_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tt_name)
	_tt_cost = _label(14, Color("6fb0f0"))
	head.add_child(_tt_cost)
	_tt_range = _wrapped(_label(12, HudWidgets.TEXT_DIM))
	v.add_child(_tt_range)
	var line := ColorRect.new()
	line.color = HudWidgets.PANEL_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	_tt_effects = _wrapped(_label(14, HudWidgets.TEXT))
	v.add_child(_tt_effects)
	_tt_status = _wrapped(_label(12, Color("8fd3a0")))
	v.add_child(_tt_status)
	_tt_hint = _wrapped(_label(12, HudWidgets.TEXT_DIM))
	_tt_hint.text = "Clic : lancer   ·   Clic droit / Échap : annuler"
	v.add_child(_tt_hint)


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Retour à la ligne dans une largeur fixe (sinon le label se réduit à une colonne).
func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 24, 0)
	return l


func _build_victory() -> void:
	_victory = ColorRect.new()
	_victory.color = Color(0, 0, 0, 0.6)
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.hide()
	add_child(_victory)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	_victory_label = Label.new()
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_victory_label)
	for entry in [["Rejouer", restart_pressed], ["Menu", menu_pressed]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(220, 46)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 20)
		var sig: Signal = entry[1]
		b.pressed.connect(func() -> void: sig.emit())
		vbox.add_child(b)


# --- Mise à jour -----------------------------------------------------------------

func show_placement(fighter: Fighter, is_ai: bool) -> void:
	_stats_box.hide()
	_spell_box.hide()
	for s in _separators:
		s.hide()
	_tooltip.hide()
	_main_button.text = "Prêt\n(Espace)"
	_main_button.disabled = is_ai
	_turn_label.text = "Placement"
	_hint.text = ("%s (%s) : clique sur une case de ta couleur pour t'y placer" % [fighter.display_name, _class_name(fighter)]) \
		if not is_ai else "L'IA se place…"


## Joueur actif, ressources, ordre de jeu et sorts. Appelé à chaque changement visible.
func show_combat(state: CombatState, selected: SpellData, is_ai: bool) -> void:
	var fighter := state.active_fighter()
	if fighter == null:
		return
	_state = state
	_selected = selected
	_stats_box.show()
	_spell_box.show()
	for s in _separators:
		s.show()
	_orb.set_values(fighter.hp, fighter.max_hp)
	_pa.set_value(fighter.pa)
	_pm.set_value(fighter.pm)
	_main_button.text = "Fin du tour\n(Espace)"
	_turn_label.text = "Tour %d" % state.turn_number
	_update_chips(state)
	_update_slots(state, fighter, selected, is_ai)
	if is_ai:
		_hint.text = "%s (%s, IA) réfléchit…" % [fighter.display_name, _class_name(fighter)]
	elif selected:
		_hint.text = "Clic : lancer   ·   Clic droit / Échap : annuler"
	else:
		_hint.text = "%s (%s)   ·   Clic : se déplacer   ·   1-%d : sorts" % [fighter.display_name, _class_name(fighter), fighter.spells.size()]
	_update_tooltip()


func _update_chips(state: CombatState) -> void:
	if _chips.size() != state.fighters.size():
		for c in _chips:
			c.queue_free()
		_chips.clear()
		for f in state.fighters:
			var chip := HudWidgets.FighterChip.new(f)
			_chips_box.add_child(chip)
			_chips.append(chip)
	var active := state.active_fighter()
	for chip in _chips:
		chip.active = chip.fighter == active
		chip.queue_redraw()


func _update_slots(state: CombatState, fighter: Fighter, selected: SpellData, is_ai: bool) -> void:
	while _slots.size() < fighter.spells.size():
		var slot := HudWidgets.SpellSlot.new(_slots.size())
		var index := _slots.size()
		slot.pressed.connect(func() -> void:
			_tooltip_dismissed = true
			spell_pressed.emit(index))
		slot.mouse_entered.connect(func() -> void: _on_slot_hover(index, true))
		slot.mouse_exited.connect(func() -> void: _on_slot_hover(index, false))
		_spell_box.add_child(slot)
		_slots.append(slot)
	for i in _slots.size():
		var slot := _slots[i]
		slot.visible = i < fighter.spells.size()
		if not slot.visible:
			continue
		var spell := fighter.spells[i]
		var cd := fighter.cooldown_left(spell)
		var left := spell.casts_per_turn - fighter.casts_this_turn(spell)
		var look := HudWidgets.SpellSlot.Look.READY
		if cd > 0:
			look = HudWidgets.SpellSlot.Look.COOLDOWN
		elif left <= 0:
			look = HudWidgets.SpellSlot.Look.NO_CASTS
		elif fighter.pa < spell.pa_cost:
			look = HudWidgets.SpellSlot.Look.NO_PA
		elif spell == selected:
			look = HudWidgets.SpellSlot.Look.SELECTED
		elif is_ai:
			look = HudWidgets.SpellSlot.Look.LOCKED
		slot.configure(spell, look, cd, left)
		slot.disabled = is_ai


func _on_slot_hover(index: int, entered: bool) -> void:
	if entered:
		_hovered_slot = index
		_tooltip_dismissed = false
	elif _hovered_slot == index:
		_hovered_slot = -1
		_tooltip_dismissed = false
	_update_tooltip()


## Infobulle du sort survolé, cachée dès qu'on clique pour lancer (elle masquerait la carte).
func _update_tooltip() -> void:
	var fighter := _state.active_fighter() if _state else null
	var slot: HudWidgets.SpellSlot = null
	if _hovered_slot >= 0 and _hovered_slot < _slots.size() and _slots[_hovered_slot].visible and not _tooltip_dismissed:
		slot = _slots[_hovered_slot]
	if fighter == null or slot == null or slot.spell == null or not _spell_box.visible:
		_tooltip.hide()
		_hint.modulate.a = 1.0
		return
	# L'infobulle recouvre la ligne d'aide : elle reprend l'aide utile quand un sort est sélectionné.
	_hint.modulate.a = 0.0
	_tt_hint.visible = slot.spell == _selected
	var spell := slot.spell
	_tt_name.text = spell.spell_name
	_tt_cost.text = "%d PA" % spell.pa_cost
	_tt_range.text = _range_text(spell)
	var effects: Array[String] = []
	for e in spell.effects:
		effects.append(e.describe())
	_tt_effects.text = "  ·  ".join(effects)
	var status := ""
	var color := Color("8fd3a0")
	match slot.look:
		HudWidgets.SpellSlot.Look.COOLDOWN:
			status = "Recharge : encore %d tour%s" % [slot.cooldown_left, "s" if slot.cooldown_left > 1 else ""]
			color = Color("e3b866")
		HudWidgets.SpellSlot.Look.NO_CASTS:
			status = "Plus de lancers ce tour"
			color = HudWidgets.TEXT_DIM
		HudWidgets.SpellSlot.Look.NO_PA:
			status = "PA insuffisants (%d / %d)" % [fighter.pa, spell.pa_cost]
			color = Color("f08a6a")
		_:
			if spell.casts_per_turn > 1:
				status = "Encore %d lancer%s ce tour" % [slot.casts_left, "s" if slot.casts_left > 1 else ""]
			else:
				status = "1 lancer par tour"
	if spell.cooldown > 0 and slot.look != HudWidgets.SpellSlot.Look.COOLDOWN:
		status += "  ·  recharge %d tours" % spell.cooldown
	_tt_status.text = status
	_tt_status.add_theme_color_override("font_color", color)
	_tooltip.reset_size()
	_tooltip.show()
	# Au-dessus de la case, sans sortir de l'écran.
	var view := _tooltip.get_viewport_rect().size
	var pos := slot.get_global_rect().position + Vector2(slot.size.x * 0.5 - _tooltip.size.x * 0.5, -_tooltip.size.y - 16)
	pos.x = clampf(pos.x, 8, view.x - _tooltip.size.x - 8)
	_tooltip.position = pos


func _range_text(spell: SpellData) -> String:
	var parts: Array[String] = []
	if spell.range_max == 0:
		parts.append("Sur soi")
	elif spell.range_min == spell.range_max:
		parts.append("Portée %d" % spell.range_max)
	else:
		parts.append("Portée %d–%d" % [spell.range_min, spell.range_max])
	if spell.range_max > 0:
		parts.append("ligne de vue" if spell.needs_line_of_sight else "sans ligne de vue")
	if spell.line_only:
		parts.append("en ligne")
	if spell.area == SpellData.AreaShape.CROSS:
		parts.append("zone en croix" if spell.range_max > 0 else "autour de soi")
	if spell.target_rule == SpellData.TargetRule.EMPTY:
		parts.append("case libre")
	elif spell.target_rule == SpellData.TargetRule.FIGHTER:
		parts.append("sur un personnage")
	return "  ·  ".join(parts)


func set_input_enabled(enabled: bool) -> void:
	_main_button.disabled = not enabled


func show_victory(winner_name: String) -> void:
	_victory_label.text = "%s gagne !" % winner_name if winner_name != "" else "Égalité !"
	_victory.show()
	_tooltip.hide()
	_main_button.disabled = true


func _class_name(fighter: Fighter) -> String:
	return fighter.class_data.class_label if fighter.class_data else "?"
