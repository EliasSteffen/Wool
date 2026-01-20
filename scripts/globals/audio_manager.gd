extends Node

var _music_player: AudioStreamPlayer
var _main_music_stream: AudioStream
var _credits_music_stream: AudioStream

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

func play_main_music() -> void:
	if not _main_music_stream: return
	
	# Only switch if playing something else or nothing
	if _music_player.stream != _main_music_stream:
		_music_player.stream = _main_music_stream
		_music_player.play()
	elif not _music_player.playing:
		_music_player.play()

func play_credits_music() -> void:
	if not _credits_music_stream: return
	
	if _music_player.stream != _credits_music_stream:
		_music_player.stream = _credits_music_stream
		_music_player.play()
	elif not _music_player.playing:
		_music_player.play()

# Deprecated shorthand, maps to main music
func play_music() -> void:
	play_main_music()

func stop_music() -> void:
	_music_player.stop()

func _on_music_finished() -> void:
	# Loop current track
	_music_player.play()
