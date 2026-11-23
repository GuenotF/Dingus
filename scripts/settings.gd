extends Node
## Réglages du joueur (autoload « Settings ») : volumes, son coupé, plein écran, particules, taille de l'interface.
## Sauvegardés dans user://settings.cfg et réappliqués à chaque lancement.
## Indique aussi si le jeu tourne en mode mobile (écran tactile) : voir `mobile`.

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

## Mode mobile : jeu exporté pour Android / iOS, ou version Web ouverte sur un téléphone.
## Pour tester sur PC : ajouter « --mobile » aux arguments de lancement
## (Projet > Paramètres du projet > Éditeur > Exécution > Arguments de la scène principale : « --mobile »).
## Sur PC, rien de ce qui dépend de ce mode ne change.
var mobile := false

## Taille de l'interface (mode mobile uniquement) : agrandit tout l'affichage.
const UI_SCALES: Array[float] = [1.0, 1.2, 1.4, 1.6]
const UI_SCALE_LABELS: Array[String] = ["Normale", "Grande", "Très grande", "Énorme"]
const UI_SCALE_DEFAULT_MOBILE := 2
var ui_scale_index := UI_SCALE_DEFAULT_MOBILE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") \
		or "--mobile" in OS.get_cmdline_user_args() or "--mobile" in OS.get_cmdline_args()
	if mobile:
		# Le bouton (ou geste) Retour d'Android ne ferme plus le jeu : il agit comme Échap.
		get_tree().quit_on_go_back = false
	_load()
	apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and mobile:
		# Retour = Échap : annule le sort, ouvre la pause, ferme une fenêtre, revient au titre...
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.physical_keycode = KEY_ESCAPE
			key.pressed = pressed
			Input.parse_input_event(key)


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


func set_ui_scale_index(value: int) -> void:
	ui_scale_index = clampi(value, 0, UI_SCALES.size() - 1)
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
	if mobile:
		# Sur téléphone : toujours plein écran (géré par le système), seule la taille de l'interface change.
		get_tree().root.content_scale_factor = UI_SCALES[ui_scale_index]
		return
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
	if mobile:
		cfg.set_value("display", "ui_scale", ui_scale_index)
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
	ui_scale_index = clampi(int(cfg.get_value("display", "ui_scale", UI_SCALE_DEFAULT_MOBILE)), 0, UI_SCALES.size() - 1)
