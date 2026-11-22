class_name SettingsPanel
extends ColorRect
## Fenêtre « Paramètres » : volumes, son coupé, plein écran, particules. Réutilisée par le menu principal
## et le menu pause. Les réglages sont ceux de l'autoload Settings (appliqués et mémorisés tout de suite).

const W := preload("res://scripts/view/hud_widgets.gd")

signal closed

var _master: HSlider
var _voice: HSlider
var _master_value: Label
var _voice_value: Label
var _mute: Button
var _fullscreen: Button
var _particles: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.65)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.panel_style(W.GOLD, 16, 26))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paramètres"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", W.GOLD)
	box.add_child(title)

	var master_row := _slider_row("Volume général")
	_master = master_row[0]
	_master_value = master_row[1]
	_master.value_changed.connect(func(v: float) -> void: Settings.set_master_volume(v / 100.0))
	box.add_child(master_row[2])
	var voice_row := _slider_row("Voix des personnages")
	_voice = voice_row[0]
	_voice_value = voice_row[1]
	_voice.value_changed.connect(func(v: float) -> void: Settings.set_voice_volume(v / 100.0))
	box.add_child(voice_row[2])

	var mute_row := _toggle_row("Couper le son (M)")
	_mute = mute_row[0]
	_mute.toggled.connect(func(on: bool) -> void: Settings.set_muted(on))
	box.add_child(mute_row[1])
	var fullscreen_row := _toggle_row("Plein écran (F11)")
	_fullscreen = fullscreen_row[0]
	_fullscreen.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	box.add_child(fullscreen_row[1])

	var particles_row := _toggle_row("Particules d'ambiance")
	_particles = particles_row[0]
	_particles.toggle_mode = false
	_particles.custom_minimum_size = Vector2(110, 34)
	# Un clic passe au niveau suivant : aucune → réduites → complètes → aucune...
	_particles.pressed.connect(func() -> void:
		Settings.set_particles_level((Settings.particles_level + 1) % Settings.PARTICLES_LABELS.size()))
	box.add_child(particles_row[1])

	var back := W.menu_button("Retour", true)
	back.pressed.connect(close)
	box.add_child(back)

	Settings.changed.connect(_sync)


func open() -> void:
	_sync()
	show()


func close() -> void:
	if visible:
		hide()
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Échap ferme ; Entrée est avalée pour ne pas lancer un combat derrière la fenêtre.
	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()


func _sync() -> void:
	_master.set_value_no_signal(roundf(Settings.master_volume * 100.0))
	_voice.set_value_no_signal(roundf(Settings.voice_volume * 100.0))
	_master_value.text = "%d %%" % int(_master.value)
	_voice_value.text = "%d %%" % int(_voice.value)
	_mute.set_pressed_no_signal(Settings.muted)
	_mute.text = "Oui" if Settings.muted else "Non"
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_fullscreen.text = "Oui" if Settings.fullscreen else "Non"
	_particles.text = Settings.PARTICLES_LABELS[Settings.particles_level]


## [slider, label de valeur, ligne complète]
func _slider_row(text: String) -> Array:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	row.add_child(head)
	var name_label := Label.new()
	name_label.text = text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", W.TEXT)
	head.add_child(name_label)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", W.TEXT_DIM)
	head.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(320, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void: value_label.text = "%d %%" % int(v))
	row.add_child(slider)
	return [slider, value_label, row]


## [bouton Oui / Non, ligne complète]
func _toggle_row(text: String) -> Array:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", W.TEXT)
	row.add_child(label)
	var b := W.menu_button("Non")
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(84, 34)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("pressed", W.button_box(W.GOLD, W.GOLD, 10))
	b.add_theme_color_override("font_pressed_color", Color("1b1408"))
	b.add_theme_color_override("font_hover_pressed_color", Color("1b1408"))
	b.add_theme_stylebox_override("hover_pressed", W.button_box(W.GOLD.lightened(0.15), W.GOLD, 10))
	b.toggled.connect(func(on: bool) -> void: b.text = "Oui" if on else "Non")
	row.add_child(b)
	return [b, row]
