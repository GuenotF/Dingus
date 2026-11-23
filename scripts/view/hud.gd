class_name Hud
extends CanvasLayer
## Interface de combat. En bas au centre : orbe de PV, PA / PM, cases de sorts, fin du tour.
## En haut à droite : numéro du tour et ordre de jeu. Infobulle au survol d'un sort.
## L'aperçu des dégâts au survol d'une cible est dessiné par FighterView.
## Mode mobile : pas de survol ; toucher un sort affiche son infobulle (cachée au premier tap sur la carte),
## textes d'aide adaptés au tactile.

signal main_button_pressed # « Fin du tour » ou « Prêt » selon la phase
signal spell_pressed(index: int)
signal restart_pressed
signal menu_pressed


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
var _tooltip: SpellTooltip

var _victory: Control
var _victory_label: Label

# Pause
var _pause_menu: PauseMenu
var _pause_button: Button


func _ready() -> void:
	_build_bottom_bar()
	_build_turn_order()
	_build_tooltip()
	_build_victory()
	_build_pause()


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
	_tooltip = SpellTooltip.new()
	add_child(_tooltip)


func _build_pause() -> void:
	_pause_button = HudWidgets.icon_button(preload("res://assets/ui/icon_settings.svg"), "Menu (Échap)")
	_pause_button.position = Vector2(16, 16)
	_pause_button.pressed.connect(open_pause)
	add_child(_pause_button)
	_pause_menu = PauseMenu.new()
	_pause_menu.restart_requested.connect(func() -> void: restart_pressed.emit())
	_pause_menu.menu_requested.connect(func() -> void: menu_pressed.emit())
	add_child(_pause_menu)


func open_pause() -> void:
	_tooltip.hide()
	_pause_menu.open()


func _build_victory() -> void:
	_victory = ColorRect.new()
	_victory.color = Color(0, 0, 0, 0.6)
	_victory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.hide()
	add_child(_victory)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory.add_child(center)
	# Même habillage que le menu pause : panneau bordé d'or, titre doré, boutons de menu
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HudWidgets.panel_style(HudWidgets.GOLD, 16, 26))
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	_victory_label = Label.new()
	_victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_label.add_theme_font_size_override("font_size", 40)
	_victory_label.add_theme_color_override("font_color", HudWidgets.GOLD)
	vbox.add_child(_victory_label)
	var replay := HudWidgets.menu_button("Rejouer", true)
	replay.pressed.connect(func() -> void: restart_pressed.emit())
	vbox.add_child(replay)
	var menu := HudWidgets.menu_button("Menu principal")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	vbox.add_child(menu)


# --- Mise à jour -----------------------------------------------------------------

func show_placement(fighter: Fighter, is_ai: bool) -> void:
	_stats_box.hide()
	_spell_box.hide()
	for s in _separators:
		s.hide()
	_tooltip.hide()
	_main_button.text = "Prêt" if Settings.mobile else "Prêt\n(Espace)"
	_main_button.disabled = is_ai
	_turn_label.text = "Placement"
	_hint.text = ("%s (%s) : %s sur une case de ta couleur pour t'y placer" % [fighter.display_name, _class_name(fighter), "touche" if Settings.mobile else "clique"]) \
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
	_main_button.text = "Fin du tour" if Settings.mobile else "Fin du tour\n(Espace)"
	_turn_label.text = "Tour %d" % state.turn_number
	_update_chips(state)
	_update_slots(state, fighter, selected, is_ai)
	if is_ai:
		_hint.text = "%s (%s, IA) réfléchit…" % [fighter.display_name, _class_name(fighter)]
	elif selected and Settings.mobile:
		_hint.text = "Touche une case pour viser, puis à nouveau pour lancer   ·   Retour : annuler"
	elif selected:
		_hint.text = "Clic : lancer   ·   Clic droit / Échap : annuler"
	elif Settings.mobile:
		_hint.text = "%s (%s)   ·   Touche une case, puis à nouveau pour t'y déplacer" % [fighter.display_name, _class_name(fighter)]
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
			if Settings.mobile:
				# Toucher un sort montre son infobulle (le sort reste choisi pour viser).
				_hovered_slot = index
				_tooltip_dismissed = false
			else:
				_tooltip_dismissed = true
			spell_pressed.emit(index))
		if not Settings.mobile:
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
	# Mobile : un sort utilisable qu'on vient de désélectionner n'affiche plus son infobulle ;
	# un sort indisponible (recharge, PA...) l'affiche pour expliquer pourquoi.
	if Settings.mobile and slot != null and slot.look == HudWidgets.SpellSlot.Look.READY:
		slot = null
	if fighter == null or slot == null or slot.spell == null or not _spell_box.visible:
		_tooltip.hide()
		_hint.modulate.a = 1.0
		return
	# L'infobulle recouvre la ligne d'aide : elle reprend l'aide utile quand un sort est sélectionné.
	_hint.modulate.a = 0.0
	var spell := slot.spell
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
	_tooltip.show_spell(spell, slot.get_global_rect(), status, color, spell == _selected)


## Mode mobile : cache l'infobulle (premier tap sur la carte), jusqu'au prochain toucher d'un sort.
func dismiss_tooltip() -> void:
	_tooltip_dismissed = true
	_update_tooltip()


func set_input_enabled(enabled: bool) -> void:
	_main_button.disabled = not enabled


func show_victory(winner_name: String) -> void:
	_victory_label.text = "%s gagne !" % winner_name if winner_name != "" else "Égalité !"
	_victory.show()
	_pause_button.hide()
	_tooltip.hide()
	_main_button.disabled = true


func _class_name(fighter: Fighter) -> String:
	return fighter.class_data.class_label if fighter.class_data else "?"
