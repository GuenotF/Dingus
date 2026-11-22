extends Node
## Réglages du joueur (autoload « Settings ») : volumes, son coupé, plein écran, particules.
## Sauvegardés dans user://settings.cfg et réappliqués à chaque lancement.

signal changed

const FILE := "user://settings.cfg"
## Niveau de base du bus « Voix » (voir Sound), auquel s'ajoute le réglage du joueur.
const VOICE_BASE_DB := -3.0

## Volumes de 0.0 à 1.0.
var master_volume := 1.0
var voice_volume := 1.0
var muted := false
var fullscreen := false
## Particules d'ambiance du fond : 0 aucune, 1 réduites, 2 complètes.
var particles_level := 2
## Animations du décor (vent sur arbres, herbes et fleurs).
var scenery_animation := true

const PARTICLES_LABELS: Array[String] = ["Aucune", "Réduites", "Complètes"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_voice_volume(value: float) -> void:
	voice_volume = clampf(value, 0.0, 1.0)
	_commit()


func set_muted(value: bool) -> void:
	muted = value
	_commit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_commit()


func set_particles_level(value: int) -> void:
	particles_level = clampi(value, 0, PARTICLES_LABELS.size() - 1)
	_commit()


func set_scenery_animation(value: bool) -> void:
	scenery_animation = value
	_commit()


func toggle_fullscreen() -> void:
	set_fullscreen(not fullscreen)


## Applique les réglages au son et à la fenêtre.
func apply() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, _to_db(master_volume))
	AudioServer.set_bus_mute(master, muted)
	var voice := AudioServer.get_bus_index(Sound.VOICE_BUS)
	if voice != -1:
		AudioServer.set_bus_volume_db(voice, VOICE_BASE_DB + _to_db(voice_volume))
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED
	# Pas de changement de mode sans écran (tests, serveur) ni si la fenêtre est déjà dans le bon état.
	if DisplayServer.get_name() != "headless" and (fullscreen != (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)):
		DisplayServer.window_set_mode(wanted)


static func _to_db(volume: float) -> float:
	return -80.0 if volume <= 0.001 else linear_to_db(volume)


func _commit() -> void:
	apply()
	_save()
	changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "voice", voice_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "particles", particles_level)
	cfg.set_value("display", "scenery_animation", scenery_animation)
	cfg.save(FILE)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	voice_volume = clampf(float(cfg.get_value("audio", "voice", 1.0)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", false))
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	scenery_animation = bool(cfg.get_value("display", "scenery_animation", true))
	particles_level = clampi(int(cfg.get_value("display", "particles", 2)), 0, PARTICLES_LABELS.size() - 1)
