class_name Roster
extends RefCounted
## Listes des personnages et des combats de campagne. Sans dépendance aux autoloads :
## utilisable par les tests et les scripts lancés avec -s (GameConfig y reprend ces listes).

## Personnages jouables (menu 1v1, démo de l'écran titre, matrice d'équilibrage).
const CLASS_PATHS: Array[String] = [
	"res://data/classes/guerrier.tres",
	"res://data/classes/mage_feu.tres",
	"res://data/classes/archer.tres",
	"res://data/classes/chevalier_maudit.tres",
	"res://data/classes/gobelin.tres",
	"res://data/classes/kael.tres",
]

## Ennemis non jouables (PNJ de campagne) : jamais proposés dans le menu 1v1, la démo de l'écran titre
## ni la matrice d'équilibrage. Joués uniquement par l'IA.
const ENEMY_PATHS: Array[String] = [
	"res://data/classes/pnj_gobelin.tres",
]

## Combats de la campagne, dans l'ordre (pour l'instant un seul : pas encore de progression sauvegardée).
const CAMPAIGN_FIGHTS: Array[Dictionary] = [
	{
		"title": "La forêt aux gobelins",
		"map": "res://maps/foret.tscn",
		"enemy": "res://data/classes/pnj_gobelin.tres",
	},
]
