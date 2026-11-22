extends Control
## Menu de départ « face à face » : un panneau par joueur (personnage animé sur sa case,
## flèches pour en changer, Humain / IA), la carte au centre avec son aperçu, puis « Lancer ».

const W := preload("res://scripts/view/hud_widgets.gd")
const ICON_HUMAN := preload("res://assets/ui/icon_human.svg")
const ICON_AI := preload("res://assets/ui/icon_ai.svg")
const ICON_EDIT := preload("res://assets/ui/icon_edit.svg")
const ICON_SETTINGS := preload("res://assets/ui/icon_settings.svg")
const ICON_QUIT := preload("res://assets/ui/icon_quit.svg")
const NAME_MAX_LENGTH := 16
const TEAM_NAME_COLORS: Array[Color] = [Color("f2a19d"), Color("9cc6f2")]
## Échelle du personnage dans le menu (les sprites font 128 px).
const PREVIEW_SCALE := 2.6

var _classes: Array[ClassData] = []
var _map_paths: Array[String] = []
var _map_index := 0
var _panels: Array[PlayerPanel] = []
## Infobulle des sorts, la même qu'en combat.
var tooltip: SpellTooltip

var _settings: SettingsPanel
var _map_view: SubViewport
var _map_name: Label
var _map_size: Label
var _map_description: Label
var _map_dots: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for path in GameConfig.CLASS_PATHS:
		_classes.append(load(path))
	_map_paths = GameConfig.list_maps()
	_map_index = maxi(0, _map_paths.find(GameConfig.map_path))

	var bg := ColorRect.new()
	bg.color = Color("15181e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 22)
	center.add_child(page)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	page.add_child(head)
	var title := Label.new()
	title.text = "DINGUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", W.GOLD)
	head.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "COMBAT 1 CONTRE 1"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", W.TEXT_DIM)
	head.add_child(subtitle)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	page.add_child(row)
	for player in 2:
		var panel := PlayerPanel.new(self, player)
		_panels.append(panel)
	row.add_child(_panels[0])
	row.add_child(_build_center())
	row.add_child(_panels[1])
	tooltip = SpellTooltip.new()
	add_child(tooltip)
	_build_corner_buttons()
	_refresh_map()


## Coin haut droit : Paramètres et Quitter.
func _build_corner_buttons() -> void:
	var corner := HBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -18
	corner.offset_top = 18
	corner.add_theme_constant_override("separation", 10)
	add_child(corner)
	var settings_button := W.icon_button(ICON_SETTINGS, "Paramètres")
	corner.add_child(settings_button)
	var quit_button := W.icon_button(ICON_QUIT, "Quitter le jeu")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	corner.add_child(quit_button)
	_settings = SettingsPanel.new()
	add_child(_settings)
	settings_button.pressed.connect(_settings.open)


func _build_center() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 16)
	var vs := Label.new()
	vs.text = "VS"
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.add_theme_font_size_override("font_size", 40)
	vs.add_theme_color_override("font_color", Color("5a5040"))
	col.add_child(vs)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(W.PANEL_BORDER))
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(_small_caps("CARTE"))

	# Aperçu : la vraie scène de la carte, rendue dans une petite fenêtre.
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(330, 186)
	v.add_child(preview)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(container)
	_map_view = SubViewport.new()
	_map_view.transparent_bg = true
	container.add_child(_map_view)
	var prev := _arrow_button(false, "Carte précédente")
	prev.position = Vector2(6, 71)
	prev.pressed.connect(func() -> void: _change_map(-1))
	preview.add_child(prev)
	var next := _arrow_button(true, "Carte suivante")
	next.position = Vector2(330 - 46, 71)
	next.pressed.connect(func() -> void: _change_map(1))
	preview.add_child(next)

	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	_map_name = Label.new()
	_map_name.add_theme_font_size_override("font_size", 20)
	_map_name.add_theme_color_override("font_color", Color("f1e3c2"))
	_map_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_map_name)
	_map_size = Label.new()
	_map_size.add_theme_font_size_override("font_size", 12)
	_map_size.add_theme_color_override("font_color", W.TEXT_DIM)
	name_row.add_child(_map_size)
	_map_description = Label.new()
	_map_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_description.custom_minimum_size = Vector2(330, 54)
	_map_description.add_theme_font_size_override("font_size", 13)
	_map_description.add_theme_color_override("font_color", Color("b5ab96"))
	v.add_child(_map_description)
	_map_dots = HBoxContainer.new()
	_map_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_map_dots)

	var start := Button.new()
	start.text = "Lancer le combat"
	start.custom_minimum_size = Vector2(360, 60)
	start.focus_mode = Control.FOCUS_NONE
	start.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.bg_color = {"normal": W.GOLD, "hover": W.GOLD.lightened(0.15), "pressed": W.GOLD.darkened(0.15)}[state]
		start.add_theme_stylebox_override(state, sb)
		start.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("1b1408"))
	start.pressed.connect(_on_start)
	col.add_child(start)
	var help := Label.new()
	help.text = "Entrée pour lancer · F11 plein écran"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("8a8578"))
	col.add_child(help)
	return col


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_on_start()


func _change_map(step: int) -> void:
	if _map_paths.is_empty():
		return
	_map_index = posmod(_map_index + step, _map_paths.size())
	_refresh_map()


func _refresh_map() -> void:
	for child in _map_view.get_children():
		child.queue_free()
	if _map_paths.is_empty():
		return
	var path := _map_paths[_map_index]
	var info := GameConfig.map_info(path)
	_map_name.text = info.name
	_map_size.text = "%d × %d" % [info.size.x, info.size.y]
	_map_description.text = info.description
	_set_dots(_map_dots, _map_paths.size(), _map_index)

	var map: BattleMap = load(path).instantiate()
	_map_view.add_child(map)
	map.position = -map.ground().map_to_local(Vector2i.ZERO) * map.scale
	map.placement().hide()
	# Cadrage : tout le losange de la carte, plus un peu de marge pour le décor qui dépasse.
	var size: Vector2i = info.size
	var left := Iso.cell_to_world(Vector2i(0, size.y - 1)).x - Iso.TILE_W * 0.5
	var right := Iso.cell_to_world(Vector2i(size.x - 1, 0)).x + Iso.TILE_W * 0.5
	var top := -Iso.TILE_H * 0.5 - 40.0
	var bottom := Iso.cell_to_world(size - Vector2i.ONE).y + Iso.TILE_H * 0.5 + 10.0
	var camera := Camera2D.new()
	camera.position = Vector2((left + right) * 0.5, (top + bottom) * 0.5)
	var view := Vector2(330, 186)
	var z := minf(view.x / (right - left), view.y / (bottom - top))
	camera.zoom = Vector2(z, z)
	_map_view.add_child(camera)
	camera.make_current()


func _on_start() -> void:
	if not _map_paths.is_empty():
		GameConfig.map_path = _map_paths[_map_index]
	for player in 2:
		GameConfig.player_classes[player] = _panels[player].class_index
		GameConfig.player_is_ai[player] = _panels[player].is_ai
		GameConfig.player_names[player] = _panels[player].player_name
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Petits éléments réutilisés ----------------------------------------------------

static func _card_style(border: Color, top_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c2027")
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	if top_color.a > 0:
		sb.border_color = top_color
		sb.border_width_top = 4
		sb.border_width_left = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 18
	return sb


static func _small_caps(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", W.TEXT_DIM)
	return l


static func _arrow_button(right: bool, label: String) -> Button:
	var b := Button.new()
	b.text = "›" if right else "‹"
	b.tooltip_text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 44)
	b.size = b.custom_minimum_size
	b.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(22)
		sb.bg_color = Color(0.07, 0.08, 0.1, 0.85) if state != "hover" else Color("2a2620")
		sb.border_color = Color("5a5040")
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color("f1e3c2"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


static func _set_dots(box: HBoxContainer, count: int, current: int) -> void:
	for c in box.get_children():
		c.queue_free()
	box.add_theme_constant_override("separation", 6)
	for i in count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.bg_color = Color("f1e3c2") if i == current else Color("4a4f5a")
		dot.add_theme_stylebox_override("panel", sb)
		box.add_child(dot)


# --- Panneau d'un joueur -----------------------------------------------------------

class PlayerPanel extends PanelContainer:
	var menu: Node
	var player := 0
	var class_index := 0
	var is_ai := false
	var player_name := ""

	var _stage: CharacterStage
	var _name_label: Label
	var _name_edit: LineEdit
	var _name_button: Button
	var _name: Label
	var _tagline: Label
	var _stats: HBoxContainer
	var _spells: HBoxContainer
	var _dots: HBoxContainer
	var _human_button: Button
	var _ai_button: Button

	func _init(p_menu: Node, p_player: int) -> void:
		menu = p_menu
		player = p_player
		class_index = GameConfig.player_classes[player]
		is_ai = GameConfig.player_is_ai[player]
		player_name = GameConfig.player_name(player)
		var team: Color = W.TEAM_COLORS[player]
		custom_minimum_size = Vector2(380, 540)
		add_theme_stylebox_override("panel", _card_with_top(team))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 12)
		add_child(v)

		# En-tête : nom du joueur + pilule Humain / IA (miroir pour le joueur 2)
		var head := HBoxContainer.new()
		v.add_child(head)
		var title := _build_name_field()
		var pill := _build_pill(team)
		if player == 0:
			head.add_child(title)
			head.add_child(pill)
		else:
			head.add_child(pill)
			head.add_child(title)

		# Le personnage, debout sur sa case, avec les flèches pour en changer
		# Les deux joueurs se regardent. On prend l'orientation « bas gauche » (l'arc de l'Archer
		# y est bien visible) et on la retourne pour le joueur 1, tourné vers la droite.
		_stage = CharacterStage.new(team, player == 0)
		v.add_child(_stage)
		var prev: Button = MenuScript()._arrow_button(false, "Personnage précédent")
		prev.position = Vector2(0, 95)
		prev.pressed.connect(func() -> void: _change_class(-1))
		_stage.add_child(prev)
		var next: Button = MenuScript()._arrow_button(true, "Personnage suivant")
		next.position = Vector2(336 - 40, 95)
		next.pressed.connect(func() -> void: _change_class(1))
		_stage.add_child(next)

		_name = Label.new()
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.add_theme_font_size_override("font_size", 28)
		_name.add_theme_color_override("font_color", Color("f1e3c2"))
		v.add_child(_name)
		_tagline = Label.new()
		_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tagline.add_theme_font_size_override("font_size", 13)
		_tagline.add_theme_color_override("font_color", W.TEXT_DIM)
		v.add_child(_tagline)
		_stats = HBoxContainer.new()
		_stats.alignment = BoxContainer.ALIGNMENT_CENTER
		_stats.add_theme_constant_override("separation", 8)
		v.add_child(_stats)
		_spells = HBoxContainer.new()
		_spells.alignment = BoxContainer.ALIGNMENT_CENTER
		_spells.add_theme_constant_override("separation", 8)
		v.add_child(_spells)
		_dots = HBoxContainer.new()
		_dots.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(_dots)
		_refresh()

	## Nom du joueur, modifiable : crayon (ou double-clic) → champ de saisie, Entrée pour valider.
	func _build_name_field() -> HBoxContainer:
		var box := HBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.alignment = BoxContainer.ALIGNMENT_BEGIN if player == 0 else BoxContainer.ALIGNMENT_END
		box.add_theme_constant_override("separation", 6)
		_name_label = Label.new()
		_name_label.text = player_name
		_name_label.add_theme_font_size_override("font_size", 18)
		_name_label.add_theme_color_override("font_color", TEAM_NAME_COLORS[player])
		_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_name_label.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.double_click:
				_start_edit())
		_name_edit = LineEdit.new()
		_name_edit.max_length = NAME_MAX_LENGTH
		_name_edit.custom_minimum_size = Vector2(150, 32)
		_name_edit.add_theme_font_size_override("font_size", 16)
		_name_edit.placeholder_text = "Joueur %d" % (player + 1)
		_name_edit.hide()
		_name_edit.text_submitted.connect(func(_t: String) -> void: _end_edit())
		_name_edit.focus_exited.connect(_end_edit)
		_name_button = Button.new()
		_name_button.icon = ICON_EDIT
		_name_button.flat = true
		_name_button.focus_mode = Control.FOCUS_NONE
		_name_button.tooltip_text = "Modifier le nom"
		_name_button.custom_minimum_size = Vector2(32, 32)
		_name_button.add_theme_constant_override("icon_max_width", 16)
		_name_button.add_theme_color_override("icon_normal_color", W.TEXT_DIM)
		_name_button.add_theme_color_override("icon_hover_color", Color.WHITE)
		_name_button.pressed.connect(_start_edit)
		if player == 0:
			box.add_child(_name_label)
			box.add_child(_name_edit)
			box.add_child(_name_button)
		else:
			box.add_child(_name_button)
			box.add_child(_name_label)
			box.add_child(_name_edit)
		return box

	func _start_edit() -> void:
		_name_edit.text = player_name
		_name_label.hide()
		_name_button.hide()
		_name_edit.show()
		_name_edit.grab_focus()
		_name_edit.select_all()

	func _end_edit() -> void:
		if not _name_edit.visible:
			return
		var text := _name_edit.text.strip_edges()
		player_name = text if text != "" else "Joueur %d" % (player + 1)
		_name_label.text = player_name
		_name_edit.hide()
		_name_label.show()
		_name_button.show()

	static func MenuScript() -> GDScript:
		return load("res://scripts/menu.gd")

	## Cadre à la couleur de l'équipe, plus épais en haut.
	static func _card_with_top(team: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1c2027")
		sb.border_color = team.darkened(0.1)
		sb.set_border_width_all(1)
		sb.border_width_top = 4
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 18
		sb.content_margin_bottom = 18
		return sb

	func _build_pill(team: Color) -> PanelContainer:
		var pill := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("12141a")
		sb.border_color = Color("3a3f4b")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(20)
		sb.set_content_margin_all(3)
		pill.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 0)
		pill.add_child(h)
		_human_button = _pill_button("Humain", ICON_HUMAN)
		_ai_button = _pill_button("IA", ICON_AI)
		_human_button.pressed.connect(func() -> void: _set_ai(false))
		_ai_button.pressed.connect(func() -> void: _set_ai(true))
		h.add_child(_human_button)
		h.add_child(_ai_button)
		set_meta("team", team)
		return pill

	func _pill_button(text: String, icon_tex: Texture2D) -> Button:
		var b := Button.new()
		b.text = text
		b.icon = icon_tex
		b.expand_icon = false
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_constant_override("icon_max_width", 16)
		b.add_theme_constant_override("h_separation", 6)
		return b

	func _style_pill() -> void:
		var team: Color = get_meta("team")
		for pair in [[_human_button, not is_ai], [_ai_button, is_ai]]:
			var b: Button = pair[0]
			var on: bool = pair[1]
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(16)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.bg_color = team if on else Color(0, 0, 0, 0)
			var hover := sb.duplicate()
			if not on:
				hover.bg_color = Color("22262f")
			for state in ["normal", "pressed", "focus"]:
				b.add_theme_stylebox_override(state, sb)
			b.add_theme_stylebox_override("hover", hover)
			var fg := team.darkened(0.85) if on else W.TEXT_DIM
			for c in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
				b.add_theme_color_override(c, fg if not (c.contains("hover") and not on) else W.TEXT)

	func _set_ai(value: bool) -> void:
		is_ai = value
		_style_pill()

	func _change_class(step: int) -> void:
		class_index = posmod(class_index + step, GameConfig.CLASS_PATHS.size())
		_refresh()
		var data: ClassData = menu._classes[class_index]
		Sound.play_voice(data.voice, "select", "menu%d" % player)

	func _refresh() -> void:
		var data: ClassData = menu._classes[class_index]
		_name.text = data.class_label
		_tagline.text = data.description
		_stage.show_class(data)
		for c in _stats.get_children():
			c.queue_free()
		_stats.add_child(_chip("%d PV" % data.max_hp, Color("f3d6d2"), Color("2a1414"), Color("5a2a28")))
		_stats.add_child(_chip("%d PA" % data.max_pa, W.PA_TEXT, Color("1b2634"), Color("2f4a68")))
		_stats.add_child(_chip("%d PM" % data.max_pm, W.PM_TEXT, Color("19291f"), Color("2f5a3c")))
		if menu.tooltip:
			menu.tooltip.hide()
		for c in _spells.get_children():
			c.queue_free()
		for spell in data.spells:
			_spells.add_child(_spell_icon(spell))
		MenuScript()._set_dots(_dots, GameConfig.CLASS_PATHS.size(), class_index)
		_style_pill()

	static func _chip(text: String, fg: Color, bg: Color, border: Color) -> PanelContainer:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", fg)
		p.add_child(l)
		return p

	## Icône d'un sort ; au survol, l'infobulle détaillée comme en combat.
	func _spell_icon(spell: SpellData) -> PanelContainer:
		var p := PanelContainer.new()
		p.mouse_entered.connect(func() -> void:
			menu.tooltip.show_spell(spell, p.get_global_rect(), SpellTooltip.limits_text(spell)))
		p.mouse_exited.connect(func() -> void: menu.tooltip.hide())
		p.custom_minimum_size = Vector2(44, 44)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2a2a2a")
		sb.border_color = Color("5a5040")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(10)
		p.add_theme_stylebox_override("panel", sb)
		if spell.icon:
			var t := TextureRect.new()
			t.texture = spell.icon
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(24, 24)
			t.modulate = Color("f1e3c2")
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(t)
		else:
			var l := Label.new()
			l.text = spell.spell_name.substr(0, 2)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			p.add_child(l)
		return p


# --- Personnage animé sur sa case ----------------------------------------------------

## Dessine une case isométrique avec le cercle d'équipe et place le personnage
## exactement comme en combat : ses pieds (feet_for selon l'orientation) au centre de la case.
class CharacterStage extends Control:
	const FACING := Vector2i(0, 1) # bas gauche à l'écran
	var team: Color
	var mirrored := false
	var _anchor := Node2D.new()
	var _sprite: AnimatedSprite2D

	func _init(p_team: Color, p_mirrored: bool) -> void:
		team = p_team
		mirrored = p_mirrored
		custom_minimum_size = Vector2(336, 250)
		mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_anchor)
		resized.connect(_place)

	func _feet_point() -> Vector2:
		return Vector2(size.x * 0.5, size.y - 40)

	func _place() -> void:
		_anchor.position = _feet_point()
		queue_redraw()

	func show_class(data: ClassData) -> void:
		if _sprite:
			_sprite.queue_free()
			_sprite = null
		var sprites := data.sprites as CharacterSprites
		if sprites == null:
			queue_redraw()
			return
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = sprites.sprite_frames()
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var s := PREVIEW_SCALE * sprites.scale
		_sprite.scale = Vector2(s, s)
		var feet := sprites.feet_for(FACING)
		if mirrored:
			# Image retournée : les pieds passent de l'autre côté de l'image.
			_sprite.flip_h = true
			feet.x = sprites.frame_size.x - feet.x
		_sprite.position = -feet * s
		_anchor.add_child(_sprite)
		_sprite.play(CharacterSprites.animation_key("idle", FACING))
		_place()

	func _draw() -> void:
		var c := _feet_point()
		var k := PREVIEW_SCALE * 1.4 # case agrandie pour aller avec le personnage
		var hw := Iso.TILE_W * 0.5 * k
		var hh := Iso.TILE_H * 0.5 * k
		var pts := PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])
		draw_colored_polygon(pts, Color("2c3a24"))
		pts.append(pts[0])
		draw_polyline(pts, Color("4d6b3a"), 2.0, true)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 21.0 * PREVIEW_SCALE, Color(team, 0.18))
		draw_arc(Vector2.ZERO, 21.0 * PREVIEW_SCALE, 0.0, TAU, 48, team, 3.0, true)
		draw_set_transform(Vector2.ZERO)
