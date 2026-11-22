extends Node
## Réglages de la partie choisis dans le menu (autoload « GameConfig »).

const CLASS_PATHS: Array[String] = [
	"res://data/classes/guerrier.tres",
	"res://data/classes/mage_feu.tres",
	"res://data/classes/archer.tres",
]

## Carte de combat (scène dessinée dans l'éditeur, voir scripts/map/battle_map.gd).
var map_path: String = "res://maps/demo.tscn"

## Index dans CLASS_PATHS, par joueur.
var player_classes: Array[int] = [0, 1]
## true = ce joueur est contrôlé par l'IA.
var player_is_ai: Array[bool] = [false, true]
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


## F11 : bascule plein écran / fenêtre maximisée, partout dans le jeu.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


## Nom affiché du joueur (0 ou 1).
func player_name(player: int) -> String:
	var n := player_names[player].strip_edges()
	return n if n != "" else "Joueur %d" % (player + 1)


func class_for(player: int) -> ClassData:
	return load(CLASS_PATHS[player_classes[player]])
