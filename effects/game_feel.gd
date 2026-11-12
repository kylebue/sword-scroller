extends Node
## Global "game feel" helpers. Registered as the autoload "GameFeel", so any
## script can call GameFeel.hitstop(...) or GameFeel.shake(...).
##
## Hitstop = freezing the whole game for a few hundredths of a second when a
## hit lands. It is one of the cheapest ways to make sword hits feel heavy.

## How quickly screen shake fades out, in pixels per second.
const SHAKE_DECAY := 40.0

## Current shake strength in pixels. The camera reads this every frame.
var shake_strength := 0.0

var _hitstop_end_msec := 0
var _in_hitstop := false


func _ready() -> void:
	# Keep running while the game is paused or frozen by hitstop.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Freeze the game for `duration` seconds (real time).
func hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	var end_msec := Time.get_ticks_msec() + int(duration * 1000.0)
	_hitstop_end_msec = maxi(_hitstop_end_msec, end_msec)
	_in_hitstop = true
	Engine.time_scale = 0.0


## Shake the screen. `strength` is the maximum offset in pixels.
func shake(strength: float) -> void:
	shake_strength = maxf(shake_strength, strength)


## Called when a new run starts so nothing carries over from the last one.
func reset() -> void:
	_in_hitstop = false
	_hitstop_end_msec = 0
	shake_strength = 0.0
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	# Hitstop is timed with the real clock because Engine.time_scale is 0
	# while it is active (so `delta` is 0 and normal timers do not advance).
	if _in_hitstop and Time.get_ticks_msec() >= _hitstop_end_msec:
		_in_hitstop = false
		Engine.time_scale = 1.0
	shake_strength = move_toward(shake_strength, 0.0, SHAKE_DECAY * delta)
