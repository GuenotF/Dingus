extends Node
## Sons du jeu (autoload « Sound »). Les voix passent par le bus « Voix » ;
## M coupe / remet le son partout.

const VOICE_BUS := "Voix"
const SFX_BUS := "Effets"
const SFX_DIR := "res://assets/audio/sfx/"
## Nombre maximal de bruitages simultanés (au-delà, on ignore le plus récent).
const SFX_VOICES := 8
## Une voix par personnage à la fois : une nouvelle réplique coupe la précédente du même personnage.
## Coupe voix et bruitages sans toucher au réglage du joueur (démo de l'écran titre).
var silenced := false
var _voice_players: Dictionary = {} # clé (id du combattant, ou autre) -> AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {} # nom -> Array[AudioStream] (variantes nom_1, nom_2...)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(VOICE_BUS) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, VOICE_BUS)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, -3.0)
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var sfx_index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_index, SFX_BUS)
		AudioServer.set_bus_send(sfx_index, "Master")
		AudioServer.set_bus_volume_db(sfx_index, -4.0)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)


## Joue le bruitage `sfx_name` (variantes assets/audio/sfx/<nom>_1.ogg, _2... tirées au hasard).
## Sans fichier : rien (le jeu reste muet plutôt que de planter).
func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if silenced:
		return
	var variants := _sfx_variants(sfx_name)
	if variants.is_empty():
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = variants[randi() % variants.size()]
			p.volume_db = volume_db
			p.pitch_scale = randf_range(0.94, 1.06)
			p.play()
			return


func _sfx_variants(sfx_name: String) -> Array:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var found: Array = []
	for i in range(1, 10):
		var path := "%s%s_%d.ogg" % [SFX_DIR, sfx_name, i]
		if not ResourceLoader.exists(path):
			break
		var stream := load(path) as AudioStream
		if stream != null:
			found.append(stream)
	_sfx_cache[sfx_name] = found
	return found


## Joue une réplique de `voice` (CharacterVoice) pour le moment donné. `key` identifie
## celui qui parle (une seule réplique à la fois par clé). Sans voix ou sans variante : rien.
func play_voice(voice: Resource, moment: String, key: Variant = "menu") -> void:
	if silenced:
		return
	var v := voice as CharacterVoice
	if v == null:
		return
	var stream := v.pick(moment)
	if stream == null:
		return
	var player: AudioStreamPlayer = _voice_players.get(key)
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = VOICE_BUS
		add_child(player)
		_voice_players[key] = player
	player.stream = stream
	player.volume_db = v.volume_db
	player.pitch_scale = randf_range(0.97, 1.03) # un peu de variété
	player.play()


func toggle_mute() -> void:
	Settings.set_muted(not Settings.muted)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		# Pas pendant la saisie d'un nom dans le menu.
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle_mute()
		get_viewport().set_input_as_handled()
