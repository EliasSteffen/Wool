extends Node

var _music_player: AudioStreamPlayer
var _background_music: AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.bus = "Music"
	
	# Load the music file
	_background_music = load("res://assets/sound/background-music.mp3")
	if not _background_music:
		printerr("AudioManager: Failed to load background-music.mp3")
	else:
		_music_player.stream = _background_music
		# Configure loop if possible via code, though usually it's an import setting.
		# For MP3, looping is indeed an import setting, but we can restart if finished.
		_music_player.finished.connect(_on_music_finished)

func play_music() -> void:
	if not _background_music:
		return
		
	if not _music_player.playing:
		print("AudioManager: Starting background music...")
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func _on_music_finished() -> void:
	# Basic insurance to loop if import settings didn't catch it
	_music_player.play()
