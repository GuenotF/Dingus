extends Control
## Écran titre : le nom du jeu et les modes à gauche ; en fond, un vrai combat entre deux IA
## (carte et personnages tirés au hasard, sans HUD ni son), relancé à chaque fin de partie.
## Haut / Bas (ou la souris) pour choisir, Entrée pour valider.

const W := preload("res://scripts/view/hud_widgets.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const ICON_MAP := preload("res://assets/ui/icon_map.svg")
const ICON_SWORDS := preload("res://assets/ui/icon_swords.svg")
const ICON_GROUP := preload("res://assets/ui/icon_group.svg")
const ICON_SETTINGS := preload("res://assets/ui/icon_settings.svg")
const ICON_QUIT := preload("res://assets/ui/icon_quit.svg")
const BG := Color("15181e")
## Décalage de la caméra de la démo (part de la largeur) : le plateau se range à droite, hors du menu.
const DEMO_SHIFT := 0.15
const DEMO_ZOOM := 0.8
const FADE_TIME := 0.8

var _viewport: SubViewport
var _fade: ColorRect
var _demo: Node
var _demo_caption: Label
var _settings: SettingsPanel
var _entries: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Sound.silenced = true # la démo joue en silence

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Démo : la scène de combat, rendue dans une fenêtre intégrée qui couvre tout l'écran.
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.gui_disable_input = true
	container.add_child(_viewport)
	_fade = ColorRect.new()
	_fade.color = BG
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	# Voile sombre à gauche pour la lisibilité du menu, qui s'efface vers la droite.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BG, 0.97))
	gradient.set_color(1, Color(BG, 0.0))
	gradient.add_point(0.55, Color(BG, 0.85))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.62
	add_child(shade)

	_build_menu()
	_build_footer()
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void: _entries[1].grab_focus())
	add_child(_settings)

	await get_tree().process_frame # taille de la fenêtre intégrée connue
	_start_demo()


func _exit_tree() -> void:
	Sound.silenced = false


## Quitte l'écran titre. La démo est libérée tout de suite : sinon le combat, retiré de la scène
## en plein tour de l'IA, reprendrait ses attentes sans arbre de scène (erreur sur `process_frame`).
func _leave(scene_path: String) -> void:
	if _demo != null:
		_demo.free()
		_demo = null
	get_tree().change_scene_to_file(scene_path)


# --- Menu ----------------------------------------------------------------------

func _build_menu() -> void:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.anchor_bottom = 1.0
	column.offset_left = 90
	column.offset_right = 90 + 400
	add_child(column)

	var tagline := _label("tactique au tour par tour", 14, W.TEXT_DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	var title := _label("DINGUS", 78, W.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spaced := FontVariation.new()
	spaced.base_font = ThemeDB.fallback_font
	spaced.spacing_glyph = 8
	title.add_theme_font_override("font", spaced)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_offset_x", 0)
	column.add_child(title)
	column.add_child(Ornament.new())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	_add_entry(column, ICON_MAP, "Campagne solo", Callable(), "Bientôt")
	_add_entry(column, ICON_SWORDS, "Combat 1 contre 1",
			func() -> void: _leave("res://scenes/menu.tscn"))
	_add_entry(column, ICON_GROUP, "Escarmouche", Callable(), "Plus tard")
	var line := ColorRect.new()
	line.color = W.PANEL_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	var line_box := MarginContainer.new()
	for side in ["left", "right"]:
		line_box.add_theme_constant_override("margin_" + side, 14)
	line_box.add_theme_constant_override("margin_top", 6)
	line_box.add_theme_constant_override("margin_bottom", 6)
	line_box.add_child(line)
	column.add_child(line_box)
	_add_entry(column, ICON_SETTINGS, "Paramètres", func() -> void:
		get_viewport().gui_release_focus()
		_settings.open())
	_add_entry(column, ICON_QUIT, "Quitter", func() -> void: get_tree().quit())

	_entries[1].grab_focus.call_deferred() # Combat 1 contre 1


## Une entrée du menu. Sans action (`action` vide), elle est « verrouillée » : grisée, avec une étiquette.
func _add_entry(parent: Control, icon: Texture2D, text: String, action: Callable, tag: String = "") -> void:
	var locked := not action.is_valid()
	var b := Button.new()
	b.text = text
	b.icon = icon
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_constant_override("h_separation", 14)
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(0, 48)
	var text_color := Color("6f685b") if locked else Color("c9bfa8")
	var active_color := Color("8a8273") if locked else Color("f1e3c2")
	for state in ["font_color", "font_disabled_color"]:
		b.add_theme_color_override(state, text_color)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, active_color)
	var icon_color := Color("5a5446") if locked else Color("7d7462")
	var icon_active := Color("6f685b") if locked else W.GOLD
	b.add_theme_color_override("icon_normal_color", icon_color)
	for state in ["icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, icon_active)

	# Deux fonds : repos (transparent) et actif (liseré doré). L'entrée active glisse vers la droite.
	var idle := _entry_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	var active := _entry_box(Color(W.GOLD, 0.10), Color(W.GOLD, 0.5) if locked else W.GOLD)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_box(b, idle)
	b.focus_entered.connect(func() -> void:
		_set_box(b, active)
		active.content_margin_left = 14
		create_tween().tween_property(active, "content_margin_left", 26.0, 0.12).set_trans(Tween.TRANS_QUAD))
	b.focus_exited.connect(func() -> void: _set_box(b, idle))
	b.mouse_entered.connect(b.grab_focus)

	if tag != "":
		var badge := Label.new()
		badge.text = tag
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", W.TEXT_DIM)
		var box := W.panel_style(W.PANEL_BORDER, 8, 0)
		box.bg_color = Color(0, 0, 0, 0)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		badge.add_theme_stylebox_override("normal", box)
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.offset_right = -12
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)

	if not locked:
		b.pressed.connect(action)
	parent.add_child(b)
	_entries.append(b)


func _entry_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


func _set_box(b: Button, box: StyleBox) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, box)


func _build_footer() -> void:
	var help := _label("" if Settings.mobile else "Haut / Bas pour choisir  ·  Entrée pour valider  ·  F11 plein écran", 13, Color("8a8578"))
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = 24
	help.offset_bottom = -18
	add_child(help)
	_demo_caption = _label("", 13, Color("8a8578"))
	_demo_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_demo_caption.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_demo_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_demo_caption.offset_right = -24
	_demo_caption.offset_bottom = -18
	add_child(_demo_caption)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# --- Démo ----------------------------------------------------------------------

func _start_demo() -> void:
	var maps := GameConfig.list_maps().filter(func(p: String) -> bool: return not p.get_file().begins_with("test_"))
	if maps.is_empty():
		return
	var picks := range(GameConfig.CLASS_PATHS.size())
	picks.shuffle()
	var classes: Array = [load(GameConfig.CLASS_PATHS[picks[0]]), load(GameConfig.CLASS_PATHS[picks[1 % picks.size()]])]
	var map_path: String = maps.pick_random()

	_demo = MAIN_SCENE.instantiate()
	_demo.demo = true
	_demo.demo_setup = {"map_path": map_path, "classes": classes}
	_demo.demo_finished.connect(_on_demo_finished, CONNECT_ONE_SHOT)
	_viewport.add_child(_demo)
	for child in _demo.get_children():
		if child is Camera2D:
			child.zoom = Vector2.ONE * DEMO_ZOOM
			child.offset.x = -_viewport.size.x * DEMO_SHIFT / DEMO_ZOOM
	_demo_caption.text = "Démonstration  ·  %s contre %s  ·  %s" % [classes[0].class_label, classes[1].class_label, GameConfig.map_info(map_path).name]
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)


## Fin d'un combat de démo : fondu au noir, puis un autre combat.
func _on_demo_finished() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	if _demo == null or not is_inside_tree():
		return
	_demo.queue_free()
	_demo = null
	await get_tree().process_frame
	_start_demo()


## Ornement sous le titre : deux filets et un losange doré.
class Ornament extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var line_color := Color("5a5040")
		draw_line(Vector2(30, c.y), Vector2(c.x - 14, c.y), line_color, 1.0)
		draw_line(Vector2(c.x + 14, c.y), Vector2(size.x - 30, c.y), line_color, 1.0)
		var gold := Color("d9a441")
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), gold)
		draw_circle(Vector2(30, c.y), 2.0, line_color)
		draw_circle(Vector2(size.x - 30, c.y), 2.0, line_color)
