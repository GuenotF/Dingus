class_name PauseMenu
extends ColorRect
## Menu pause du combat : Reprendre, Rejouer, Paramètres, Menu principal, Quitter.
## Ouvert, il met le jeu en pause (rien ne bouge, l'IA attend). Rejouer, Menu principal
## et Quitter demandent confirmation. Échap ferme (ou revient en arrière).

const W := preload("res://scripts/view/hud_widgets.gd")

signal restart_requested
signal menu_requested

var _main_page: VBoxContainer
var _confirm_page: VBoxContainer
var _confirm_title: Label
var _confirm_text: Label
var _confirm_action: Callable
var _settings: SettingsPanel
var _center: CenterContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0, 0, 0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", W.panel_style(W.GOLD, 16, 26))
	_center.add_child(panel)
	UiFit.attach(_center, panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)

	_main_page = VBoxContainer.new()
	_main_page.add_theme_constant_override("separation", 12)
	stack.add_child(_main_page)
	var title := _title("Pause")
	_main_page.add_child(title)
	var resume := W.menu_button("Reprendre", true)
	resume.pressed.connect(close)
	_main_page.add_child(resume)
	_main_page.add_child(_entry("Rejouer", func() -> void: _ask("Rejouer le combat ?", "Le combat en cours sera perdu.", _do_restart)))
	_main_page.add_child(_entry("Paramètres", func() -> void:
		_center.hide()
		_settings.open()))
	_main_page.add_child(_entry("Menu principal", func() -> void: _ask("Retourner au menu principal ?", "Le combat en cours sera perdu.", _do_menu)))
	_main_page.add_child(_entry("Quitter le jeu", func() -> void: _ask("Quitter le jeu ?", "Le combat en cours sera perdu.", _do_quit)))

	_confirm_page = VBoxContainer.new()
	_confirm_page.add_theme_constant_override("separation", 14)
	_confirm_page.hide()
	stack.add_child(_confirm_page)
	_confirm_title = _title("")
	_confirm_page.add_child(_confirm_title)
	_confirm_text = Label.new()
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.add_theme_font_size_override("font_size", 16)
	_confirm_text.add_theme_color_override("font_color", W.TEXT_DIM)
	_confirm_page.add_child(_confirm_text)
	var yes := W.menu_button("Confirmer", true)
	yes.pressed.connect(func() -> void: _confirm_action.call())
	_confirm_page.add_child(yes)
	_confirm_page.add_child(_entry("Annuler", _show_main_page))

	_settings = SettingsPanel.new()
	_settings.closed.connect(_center.show)
	add_child(_settings)


func open() -> void:
	_show_main_page()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	_center.show()
	_settings.hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE: # la fenêtre Paramètres, si elle est ouverte, a déjà pris l'événement
		if _confirm_page.visible:
			_show_main_page()
		else:
			close()
		get_viewport().set_input_as_handled()


func _show_main_page() -> void:
	_confirm_page.hide()
	_main_page.show()


func _ask(title: String, text: String, action: Callable) -> void:
	_confirm_title.text = title
	_confirm_text.text = text
	_confirm_action = action
	_main_page.hide()
	_confirm_page.show()


func _do_restart() -> void:
	close()
	restart_requested.emit()


func _do_menu() -> void:
	close()
	menu_requested.emit()


func _do_quit() -> void:
	get_tree().quit()


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", W.GOLD)
	return l


func _entry(text: String, action: Callable) -> Button:
	var b := W.menu_button(text)
	b.pressed.connect(action)
	return b
