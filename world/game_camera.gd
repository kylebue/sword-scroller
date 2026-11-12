class_name GameCamera
extends Camera2D
## A camera that only ever scrolls to the right.
##
## It follows the player, but never moves back to the left. While `locked`
## is true (boss fights) it does not move at all, which turns the screen
## into an arena.

## Where the player sits on screen while running: 0 = left edge, 1 = right
## edge. Below 0.5 shows more of what is coming up ahead.
@export_range(0.1, 0.9) var player_screen_position := 0.38
## How fast the camera catches up when it has fallen behind (for example
## after a boss fight). Must be higher than the player's run speed.
@export var catch_up_speed := 600.0

var locked := false

var _half_width := 320.0
@onready var _target := get_tree().get_first_node_in_group("player") as Node2D


func _ready() -> void:
	_half_width = get_viewport_rect().size.x / 2.0 / zoom.x
	# Run after the player has moved each physics frame, so the camera uses
	# the player's newest position and never lags a frame behind.
	process_physics_priority = 100
	if _target:
		global_position.x = _get_desired_x()


func _physics_process(delta: float) -> void:
	if _target == null or locked:
		return
	var desired_x := _get_desired_x()
	# Only ever move right. move_toward() snaps straight to the target when
	# it is close, so normal running has zero camera lag.
	if desired_x > global_position.x:
		global_position.x = move_toward(global_position.x, desired_x, catch_up_speed * delta)


func _process(_delta: float) -> void:
	# Screen shake only changes `offset`, so it never affects the edges below.
	var strength := GameFeel.shake_strength
	offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength)).round()


## World x position of the left edge of the screen.
func left_edge() -> float:
	return global_position.x - _half_width


## World x position of the right edge of the screen.
func right_edge() -> float:
	return global_position.x + _half_width


func _get_desired_x() -> float:
	return _target.global_position.x + (0.5 - player_screen_position) * _half_width * 2.0
