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
	SPUCKI = "enemy_spucki"
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
	WOOL.SCHWINGEN: "res://assets/sound/wool/schwingen.wav",
	WOOL.FALLING: "res://assets/sound/wool/falling.wav",

	ENEMIES.BIRD: "res://assets/sound/enemies/bird.wav",
	ENEMIES.SPUCKI: "res://assets/sound/enemies/spucki.wav",

	GAME.ANFANG: "res://assets/sound/game/anfang.wav",
	GAME.HIGHSCORE: "res://assets/sound/game/highscore.wav",
	GAME.WARN: "res://assets/sound/game/warn.wav"
}

var _loaded_sounds = {}
var _sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_sounds()

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
