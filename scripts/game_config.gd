extends Node
## Réglages de la partie choisis dans le menu (autoload « GameConfig »).

## Listes des personnages et des combats de campagne : voir scripts/core/roster.gd.
const CLASS_PATHS := Roster.CLASS_PATHS
const ENEMY_PATHS := Roster.ENEMY_PATHS
const CAMPAIGN_FIGHTS := Roster.CAMPAIGN_FIGHTS

## Police de l'interface (assets/fonts/). Si le fichier est absent : police par défaut de Godot.
const FONT_PATH := "res://assets/fonts/vinque_antique_bd.otf"
## Police d'origine de Godot, gardée pour les textes qui doivent rester lisibles (description des sorts).
var body_font: Font


func _ready() -> void:
	body_font = ThemeDB.fallback_font
	if ResourceLoader.exists(FONT_PATH):
		var font: FontFile = load(FONT_PATH)
		font.fallbacks = [body_font] # symboles absents de la police (flèches, puces...)
		ThemeDB.fallback_font = font
		ThemeDB.get_default_theme().default_font = font


## Carte de combat (scène dessinée dans l'éditeur, voir scripts/map/battle_map.gd).
var map_path: String = "res://maps/demo.tscn"

## Index dans CLASS_PATHS, par joueur.
var player_classes: Array[int] = [0, 1]
## true = ce joueur est contrôlé par l'IA.
var player_is_ai: Array[bool] = [false, true]
## Partie de campagne : le joueur 1 (humain) choisit son héros, le joueur 2 est l'ennemi du combat
## `campaign_fight` (IA), sur la carte imposée.
var campaign := false
var campaign_fight := 0
var _versus_map_path := ""
## Noms choisis dans le menu (vide = « Joueur N »), affichés en combat.
var player_names: Array[String] = ["", ""]


## Toutes les cartes du dossier maps/ (une nouvelle carte y apparaît automatiquement dans le menu).
func list_maps() -> Array[String]:
	var result: Array[String] = []
	for entry in DirAccess.get_files_at("res://maps"):
		# Dans un jeu exporté, les scènes deviennent « x.tscn.remap ».
		var file := entry.trim_suffix(".remap")
		if file.ends_with(".tscn"):
			result.append("res://maps/" + file)
	result.sort()
	return result


## Nom et description d'une carte (lus dans la scène).
func map_info(path: String) -> Dictionary:
	var map: BattleMap = load(path).instantiate()
	var info := {
		"name": map.map_name if map.map_name != "" else path.get_file().get_basename(),
		"description": map.description,
		"size": map.grid_size(),
	}
	map.free()
	return info


## F11 : bascule plein écran / fenêtre maximisée, partout dans le jeu (réglage mémorisé).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()


## Nom affiché du joueur (0 ou 1).
func player_name(player: int) -> String:
	var n := player_names[player].strip_edges()
	return n if n != "" else "Joueur %d" % (player + 1)


func class_for(player: int) -> ClassData:
	if campaign and player == 1:
		return load(current_fight().enemy)
	return load(CLASS_PATHS[player_classes[player]])


func current_fight() -> Dictionary:
	return CAMPAIGN_FIGHTS[clampi(campaign_fight, 0, CAMPAIGN_FIGHTS.size() - 1)]


## Prépare une partie de campagne (appelé depuis l'écran titre).
func start_campaign(fight: int = 0) -> void:
	if not campaign:
		_versus_map_path = map_path
	campaign = true
	campaign_fight = fight
	map_path = current_fight().map
	player_is_ai[0] = false
	player_is_ai[1] = true


## Prépare un combat 1v1 classique (appelé depuis l'écran titre).
func start_versus() -> void:
	if campaign:
		campaign = false
		if _versus_map_path != "":
			map_path = _versus_map_path
