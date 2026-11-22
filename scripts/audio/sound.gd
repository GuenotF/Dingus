extends Node
## Sons du jeu (autoload « Sound »). Les voix passent par le bus « Voix » ;
## M coupe / remet le son partout.

const VOICE_BUS := "Voix"
## Une voix par personnage à la fois : une nouvelle réplique coupe la précédente du même personnage.
var _voice_players: Dictionary = {} # clé (id du combattant, ou autre) -> AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(VOICE_BUS) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, VOICE_BUS)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, -3.0)


## Joue une réplique de `voice` (CharacterVoice) pour le moment donné. `key` identifie
## celui qui parle (une seule réplique à la fois par clé). Sans voix ou sans variante : rien.
func play_voice(voice: Resource, moment: String, key: Variant = "menu") -> void:
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
