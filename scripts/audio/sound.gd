extends Node
## Sons du jeu (autoload « Sound »). Quatre bus sous « Master » : « Voix », « Effets » (bruitages, ambiance),
## « Musique » et « Interface ». M coupe / remet le son partout.
## Fichiers : assets/audio/sfx/<nom>_1.ogg, _2... (variantes), music/<nom>.ogg, ambience/<nom>.ogg.

const VOICE_BUS := "Voix"
const SFX_BUS := "Effets"
const MUSIC_BUS := "Musique"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"
## Nombre maximal de bruitages simultanés (au-delà, on ignore le plus récent).
const SFX_VOICES := 10
## Niveau de base des bus (dB), auquel s'ajoute le réglage du joueur (voir Settings.apply).
const BUS_BASE_DB := {"Voix": -3.0, "Effets": -4.0, "Musique": -10.0}
## Volume de l'ambiance (boucle de fond de la carte) dans le bus Effets.
const AMBIENCE_DB := -14.0
## Correction de volume par bruitage (dB) : les packs n'ont pas tous le même niveau.
const SFX_TRIM := {
	"pas_herbe": -9.0, "pas_terre": -2.0, "pas_pierre": -11.0, "pas_bois": -8.0, "pas_eau": -8.0,
	"ui_survol": -28.0, "debut_tour": -2.0, "debut_combat": -4.0,
	"coup_pied": -4.0, "coup_poing": -4.0, "gourdin_impact": -4.0, "caillou_impact": -5.0,
	"chaine_impact": -6.0, "vol": -6.0, "chute": -6.0, "whoosh": -6.0, "hache_impact": -3.0,
}
## Fondu (s) entre deux musiques ou deux ambiances.
const FADE := 1.2

## Coupe voix et bruitages de combat sans toucher au réglage du joueur (démo de l'écran titre).
## La musique, l'ambiance et les sons de l'interface ne sont pas concernés.
var silenced := false
var _voice_players: Dictionary = {} # clé (id du combattant, ou autre) -> AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {} # nom -> Array[AudioStream] (variantes nom_1, nom_2...)
var _last_variant: Dictionary = {} # nom -> dernière variante jouée
var _music: AudioStreamPlayer
var _music_name := ""
var _ambience: AudioStreamPlayer
var _ambience_name := ""
var _last_hover_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in [VOICE_BUS, SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
			AudioServer.set_bus_volume_db(index, BUS_BASE_DB[bus])
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)
	_music = _loop_player(MUSIC_BUS)
	_ambience = _loop_player(SFX_BUS)
	# Clic et survol sur tous les boutons du jeu, sans avoir à les brancher un par un.
	get_tree().node_added.connect(_on_node_added)


func _loop_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## Joue le bruitage `sfx_name` (variantes assets/audio/sfx/<nom>_1.ogg, _2... tirées au hasard,
## jamais deux fois de suite la même). Sans fichier : rien (le jeu reste muet plutôt que de planter).
func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if silenced:
		return
	_play(sfx_name, volume_db)


## Comme play_sfx, mais aussi pendant la démo de l'écran titre (sons de l'interface).
func play_ui(sfx_name: String, volume_db: float = 0.0) -> void:
	_play(sfx_name, volume_db)


func _play(sfx_name: String, volume_db: float) -> void:
	if sfx_name.is_empty():
		return
	var variants := _sfx_variants(sfx_name)
	if variants.is_empty():
		return
	var stream: AudioStream = variants[randi() % variants.size()]
	if variants.size() > 1 and stream == _last_variant.get(sfx_name):
		stream = variants[(variants.find(stream) + 1) % variants.size()]
	_last_variant[sfx_name] = stream
	for p in _sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db + SFX_TRIM.get(sfx_name, 0.0)
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


## Lance la musique `music_name` (assets/audio/music/<nom>.ogg) en boucle, en fondu.
## Ne fait rien si elle joue déjà (changement de scène sans coupure). Nom vide : arrête la musique.
func play_music(music_name: String) -> void:
	_music_name = _switch_loop(_music, _music_name, music_name, MUSIC_DIR, 0.0)


func stop_music() -> void:
	play_music("")


## Boucle d'ambiance de la carte (assets/audio/ambience/<nom>.ogg), « aucune » ou vide : silence.
func play_ambience(ambience_name: String) -> void:
	if ambience_name == "aucune":
		ambience_name = ""
	_ambience_name = _switch_loop(_ambience, _ambience_name, ambience_name, AMBIENCE_DIR, AMBIENCE_DB)


func stop_ambience() -> void:
	play_ambience("")


func _switch_loop(player: AudioStreamPlayer, current: String, wanted: String, dir: String, volume_db: float) -> String:
	if wanted == current and (wanted.is_empty() or player.playing):
		return current
	var stream: AudioStream = null
	if not wanted.is_empty():
		var path := "%s%s.ogg" % [dir, wanted]
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
	if stream == null and not player.playing:
		return ""
	var tween := create_tween()
	if player.playing:
		tween.tween_property(player, "volume_db", -40.0, FADE * 0.5)
		tween.tween_callback(player.stop)
	if stream == null:
		return ""
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	tween.tween_callback(_start_loop.bind(player, stream))
	tween.tween_property(player, "volume_db", volume_db, FADE)
	return wanted


func _start_loop(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.volume_db = -40.0
	player.play()


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


## Boutons : petit son au survol (souris seulement), pas de son au clic.
## Un bouton peut s'en passer avec set_meta("no_sound", true) avant d'entrer dans l'arbre.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta("no_sound"):
		return
	if not Settings.mobile:
		button.mouse_entered.connect(func() -> void:
			var now := Time.get_ticks_msec()
			if button.disabled or now - _last_hover_ms < 70:
				return
			_last_hover_ms = now
			play_ui("ui_survol"))


func toggle_mute() -> void:
	Settings.set_muted(not Settings.muted)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		# Pas pendant la saisie d'un nom dans le menu.
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		toggle_mute()
		get_viewport().set_input_as_handled()
