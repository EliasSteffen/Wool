extends Node

# --- Constants for Sound Access ---
const WOOL = {
	HOOK = "wool_hook",
	DIE = "wool_die",
	SCHWINGEN = "wool_swing",
	FALLING = "wool_falling"
}

const ENEMIES = {
	BIRD = "enemy_bird",
	SPUCKI = "enemy_spucki",
	FISH = "enemy_fish"
}

const GAME = {
	ANFANG = "game_start",
	HIGHSCORE = "game_highscore",
	WARN = "game_warn"
}

# Values map to file paths
var _sound_files = {
	WOOL.HOOK: "res://assets/sound/wool/hook.wav",
	WOOL.DIE: "res://assets/sound/wool/die.wav",
	WOOL.SCHWINGEN: "res://assets/sound/wool/swing.mp3",

	ENEMIES.BIRD: "res://assets/sound/enemies/bird.wav",
	ENEMIES.SPUCKI: "res://assets/sound/enemies/spucki.wav",
	ENEMIES.FISH: "res://assets/sound/enemies/fish.mp3",

	GAME.HIGHSCORE: "res://assets/sound/game/highscore.wav",
	GAME.WARN: "res://assets/sound/game/warn.wav"
}

const MUSIC_PATH = "res://assets/sound/game/background.mp3"

var _loaded_sounds = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Initialize Volumes to 50% (User Request)
	_set_bus_volume("Master", 0.5)
	_set_bus_volume("Music", 0.5)
	_set_bus_volume("SFX", 0.5)

	load_sounds()
	_start_background_music()

func _set_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))

func load_sounds() -> void:
	for key in _sound_files:
		var path = _sound_files[key]
		if ResourceLoader.exists(path):
			var stream = load(path)
			if stream:
				_loaded_sounds[key] = stream
				print("AudioManager: Loaded sound '", key, "' from ", path)
			else:
				printerr("AudioManager: Failed to load sound stream from ", path)
		else:
			printerr("AudioManager: Sound file not found at ", path)

func play_sound(sound_id: String) -> void:
	if not _loaded_sounds.has(sound_id):
		printerr("AudioManager: Play requested for unknown or unloaded sound: ", sound_id)
		return

	var stream = _loaded_sounds[sound_id]
	var player = _get_available_sfx_player()
	player.stream = stream
	player.bus = "SFX"
	if sound_id.begins_with("wool_") or sound_id.begins_with("enemy_"):
		player.volume_db = linear_to_db(0.75)
	else:
		player.volume_db = 0.0
	player.play()

func get_sound_stream(sound_id: String) -> AudioStream:
	if not _loaded_sounds.has(sound_id):
		printerr("AudioManager: Stream requested for unknown or unloaded sound: ", sound_id)
		return null
	return _loaded_sounds[sound_id]

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p

	var new_player = AudioStreamPlayer.new()
	add_child(new_player)
	_sfx_pool.append(new_player)
	return new_player

func create_audio_player(sound_id: String, parent: Node) -> AudioStreamPlayer:
	if not _loaded_sounds.has(sound_id):
		printerr("AudioManager: Create player requested for unknown or unloaded sound: ", sound_id)
		return null

	var new_player = AudioStreamPlayer.new()
	parent.add_child(new_player)
	new_player.stream = _loaded_sounds[sound_id]
	new_player.bus = "SFX"
	if sound_id.begins_with("wool_") or sound_id.begins_with("enemy_"):
		new_player.volume_db = linear_to_db(0.75)
	return new_player

func _start_background_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		printerr("AudioManager: Background music not found at ", MUSIC_PATH)
		return

	var stream = load(MUSIC_PATH)
	if stream is AudioStreamMP3:
		stream.loop = true

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = stream
	_music_player.bus = "Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_music_player.play()
	print("AudioManager: Background music started")
