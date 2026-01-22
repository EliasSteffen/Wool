extends Node

var _music_player: AudioStreamPlayer
var _main_music_stream: AudioStream
var _credits_music_stream: AudioStream
var _sfx_die_to_void_stream: AudioStream
var _sfx_die_to_enemy_stream: AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.bus = "Music"
	_music_player.finished.connect(_on_music_finished)
	
	# Load tracks
	_main_music_stream = load("res://assets/sound/background-music.mp3")
	if not _main_music_stream:
		printerr("AudioManager: Failed to load background-music.mp3")
		
	_credits_music_stream = load("res://assets/sound/credits-music.mp3")
	if not _credits_music_stream:
		printerr("AudioManager: Failed to load credits-music.mp3")

	_sfx_die_to_void_stream = load("res://assets/sound/die-to-void.mp3")
	if not _sfx_die_to_void_stream:
		printerr("AudioManager: Failed to load die-to-void.mp3")

	_sfx_die_to_enemy_stream = load("res://assets/sound/die-to-enemy.mp3")
	if not _sfx_die_to_enemy_stream:
		printerr("AudioManager: Failed to load die-to-enemy.mp3")

func play_main_music() -> void:
	if not _main_music_stream: return
	
	# Only switch if playing something else or nothing
	if _music_player.stream != _main_music_stream:
		# Crossfade could be added here, but for now simple switch
		_music_player.stream = _main_music_stream
		_music_player.play()
		print("AudioManager: Main music started.")
	elif not _music_player.playing:
		_music_player.play()

func play_credits_music() -> void:
	if not _credits_music_stream: return
	
	if _music_player.stream != _credits_music_stream:
		_music_player.stream = _credits_music_stream
		_music_player.play()
		print("AudioManager: Credits music started.")
	elif not _music_player.playing:
		_music_player.play()


func play_sfx_die_to_void() -> void:
	if not _sfx_die_to_void_stream: return
	var player = _get_available_sfx_player()
	player.stream = _sfx_die_to_void_stream
	player.bus = "SFX"
	player.play()

func play_sfx_die_to_enemy() -> void:
	if not _sfx_die_to_enemy_stream: return
	var player = _get_available_sfx_player()
	player.stream = _sfx_die_to_enemy_stream
	player.bus = "SFX"
	player.play()

var _sfx_pool: Array[AudioStreamPlayer] = []

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	
	# Create new if none available
	var new_player = AudioStreamPlayer.new()
	add_child(new_player)
	_sfx_pool.append(new_player)
	return new_player

# Deprecated shorthand, maps to main music
func play_music() -> void:
	play_main_music()

func stop_music() -> void:
	_music_player.stop()

func _on_music_finished() -> void:
	# Loop current track
	_music_player.play()
