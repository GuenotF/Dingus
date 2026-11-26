class_name CharacterVoice
extends Resource
## Voix d'un personnage (data/voices/*.tres), branchée dans le champ `voice` de sa classe.
## Chaque moment a plusieurs variantes : une est tirée au hasard (jamais deux fois de suite la même).

## Attaque légère (sorts dont l'animation est « melee » ou « attack1 »).
@export var attack: Array[AudioStream] = []
## Attaque lourde, bond, coup de pied (« jump », « kick », « attack2 », « attack3 »).
@export var heavy_attack: Array[AudioStream] = []
## Cri, sort lancé (« cast » et toute autre animation).
@export var shout: Array[AudioStream] = []
## Dégâts reçus.
@export var hurt: Array[AudioStream] = []
## Gros dégâts reçus (au moins `big_hurt_ratio` des PV max d'un coup).
@export var big_hurt: Array[AudioStream] = []
@export_range(0.0, 1.0) var big_hurt_ratio: float = 0.12
@export var death: Array[AudioStream] = []
@export var victory: Array[AudioStream] = []
## Premier tour du combat.
@export var greet: Array[AudioStream] = []
## Choisi dans le menu.
@export var select: Array[AudioStream] = []
## Volume de cette voix (dB), pour équilibrer les personnages entre eux.
@export_range(-24.0, 12.0) var volume_db: float = 0.0

var _last: Dictionary = {} # moment -> dernière variante jouée


## Les variantes d'un moment : « attack », « hurt », « victory »...
func lines(moment: String) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	var list = get(moment)
	if list is Array:
		result.assign(list)
	return result


## Moment correspondant à l'animation d'un sort.
static func moment_for_animation(anim: String) -> String:
	match anim:
		"melee", "attack1":
			return "attack"
		"jump", "kick", "attack2", "attack3":
			return "heavy_attack"
	return "shout"


## Une variante au hasard, différente de la précédente quand c'est possible.
func pick(moment: String) -> AudioStream:
	var list := lines(moment)
	if list.is_empty():
		return null
	var stream: AudioStream = list[randi() % list.size()]
	if list.size() > 1 and stream == _last.get(moment):
		stream = list[(list.find(stream) + 1 + randi() % (list.size() - 1)) % list.size()]
	_last[moment] = stream
	return stream
