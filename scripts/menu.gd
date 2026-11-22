extends Control
## Menu de départ : classe et contrôleur (humain / IA) de chaque joueur.

var _class_pickers: Array[OptionButton] = []
var _control_pickers: Array[OptionButton] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1d2128")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title := Label.new()
	title.text = ProjectSettings.get_setting("application/config/name", "Jeu")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Combat 1 contre 1"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	box.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for player in 2:
		var label := Label.new()
		label.text = "Joueur %d" % (player + 1)
		label.add_theme_font_size_override("font_size", 20)
		grid.add_child(label)

		var class_picker := OptionButton.new()
		class_picker.custom_minimum_size = Vector2(180, 40)
		for path in GameConfig.CLASS_PATHS:
			var data: ClassData = load(path)
			class_picker.add_item("%s  (%d PV, %d PA, %d PM)" % [data.class_label, data.max_hp, data.max_pa, data.max_pm])
		class_picker.select(GameConfig.player_classes[player])
		grid.add_child(class_picker)
		_class_pickers.append(class_picker)

		var control_picker := OptionButton.new()
		control_picker.custom_minimum_size = Vector2(140, 40)
		control_picker.add_item("Humain")
		control_picker.add_item("IA")
		control_picker.select(1 if GameConfig.player_is_ai[player] else 0)
		grid.add_child(control_picker)
		_control_pickers.append(control_picker)

	var start := Button.new()
	start.text = "Lancer le combat"
	start.custom_minimum_size = Vector2(0, 52)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_start)
	box.add_child(start)


func _on_start() -> void:
	for player in 2:
		GameConfig.player_classes[player] = _class_pickers[player].selected
		GameConfig.player_is_ai[player] = _control_pickers[player].selected == 1
	get_tree().change_scene_to_file("res://scenes/main.tscn")
