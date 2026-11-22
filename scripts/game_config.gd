extends Node
## Réglages de la partie choisis dans le menu (autoload « GameConfig »).

const CLASS_PATHS: Array[String] = [
	"res://data/classes/guerrier.tres",
	"res://data/classes/druide.tres",
]

## Carte de combat (scène dessinée dans l'éditeur, voir scripts/map/battle_map.gd).
var map_path: String = "res://maps/demo.tscn"

## Index dans CLASS_PATHS, par joueur.
var player_classes: Array[int] = [0, 1]
## true = ce joueur est contrôlé par l'IA.
var player_is_ai: Array[bool] = [false, true]


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


func class_for(player: int) -> ClassData:
	return load(CLASS_PATHS[player_classes[player]])
