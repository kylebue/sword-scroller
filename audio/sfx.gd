extends Node
## Plays sound effects. Registered as the autoload "Sfx", so any script can
## call:  Sfx.play(&"hit")
##
## The sounds in audio/sfx are generated placeholders. To replace one, either
## overwrite its .wav file with your own (keeping the same name), or change
## the path in the SOUNDS table below. To add a new sound, add a line to
## SOUNDS and call Sfx.play() with its name.
##
## All sounds play on the "SFX" audio bus, so their overall volume can be
## changed in one place (the Audio tab at the bottom of the editor).

const SOUNDS: Dictionary[StringName, AudioStream] = {
	# Player
	&"swing": preload("res://audio/sfx/swing.wav"),
	&"swing_heavy": preload("res://audio/sfx/swing_heavy.wav"),
	&"hit": preload("res://audio/sfx/hit.wav"),
	&"hit_heavy": preload("res://audio/sfx/hit_heavy.wav"),
	&"jump": preload("res://audio/sfx/jump.wav"),
	&"land": preload("res://audio/sfx/land.wav"),
	&"dash": preload("res://audio/sfx/dash.wav"),
	&"bounce": preload("res://audio/sfx/bounce.wav"),
	&"player_hurt": preload("res://audio/sfx/player_hurt.wav"),
	&"player_die": preload("res://audio/sfx/player_die.wav"),
	&"pickup": preload("res://audio/sfx/pickup.wav"),
	# Enemies
	&"windup": preload("res://audio/sfx/windup.wav"),
	&"enemy_swing": preload("res://audio/sfx/enemy_swing.wav"),
	&"spit": preload("res://audio/sfx/spit.wav"),
	&"enemy_die": preload("res://audio/sfx/enemy_die.wav"),
	# Boss
	&"boss_appear": preload("res://audio/sfx/boss_appear.wav"),
	&"boss_slam": preload("res://audio/sfx/boss_slam.wav"),
	&"boss_die": preload("res://audio/sfx/boss_die.wav"),
	# Menus
	&"ui_move": preload("res://audio/sfx/ui_move.wav"),
	&"ui_select": preload("res://audio/sfx/ui_select.wav"),
}

## How many sounds can overlap. When all are busy the oldest is cut off.
const MAX_SOUNDS_AT_ONCE := 12
## Each sound is played at a slightly random pitch (here up to 8% higher or
## lower) so that repeated sounds, like sword swings, do not sound robotic.
const PITCH_VARIATION := 0.08

var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	# Keep working while the game is paused (for menu sounds).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in MAX_SOUNDS_AT_ONCE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


## Plays a sound from the SOUNDS table.
## `pitch` 1.0 is normal; lower is deeper (the boss reuses sounds this way).
## `volume_db` 0.0 is normal; negative is quieter.
func play(sound: StringName, pitch := 1.0, volume_db := 0.0) -> void:
	if not SOUNDS.has(sound):
		push_warning("Sfx: there is no sound called '%s'" % sound)
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % MAX_SOUNDS_AT_ONCE
	player.stream = SOUNDS[sound]
	player.pitch_scale = pitch * randf_range(1.0 - PITCH_VARIATION, 1.0 + PITCH_VARIATION)
	player.volume_db = volume_db
	player.play()
