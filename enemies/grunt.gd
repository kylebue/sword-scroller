extends Enemy
## Basic melee enemy. Walks up to the player, winds up (a clear warning),
## then swings. If the player is overhead (jumping over it, or bouncing on
## its head with downward swings) it swings upward instead. Hitting it during the wind-up cancels its attack, unless it
## was staggered very recently (see stagger_cooldown in enemy.gd).

enum State { CHASE, WINDUP, STRIKE, RECOVER }

## Starts winding up when the player is within this many pixels.
@export var attack_range := 32.0
@export var attack_damage := 12.0
## Warning time before the swing. Shrinks as difficulty rises.
@export var windup_time := 0.45
@export var strike_time := 0.12
## Time spent vulnerable after a swing.
@export var recover_time := 0.5
## Speed of the small step forward during the swing.
@export var strike_lunge_speed := 150.0

var state := State.CHASE
var _state_time := 0.0
var _has_hit := false
## True when the current attack is the upward swing.
var _striking_up := false
## A little randomness per grunt so groups do not stack perfectly.
var _speed_variation := randf_range(0.85, 1.15)
var _range_variation := randf_range(0.75, 1.0)

@onready var body: Polygon2D = $Visuals/Body
@onready var weapon: Polygon2D = $Visuals/Weapon
@onready var swipe: Polygon2D = $Visuals/Swipe
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var up_hitbox: Area2D = $UpHitbox
@onready var _body_color: Color = body.color


func _behave(delta: float) -> void:
	_state_time += delta
	match state:
		State.CHASE:
			face_player()
			var in_range := absf(distance_to_player()) <= attack_range * _range_variation
			if in_range:
				# How far the player is above this grunt, in pixels.
				var height_above := global_position.y - player.global_position.y
				_striking_up = height_above >= 40.0
				_set_state(State.WINDUP)
			else:
				velocity.x = facing * move_speed * speed_multiplier * _speed_variation
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			if _state_time >= windup_time * telegraph_multiplier:
				_set_state(State.STRIKE)
		State.STRIKE:
			# Step into the swing, but do not walk straight through the player.
			var has_room := absf(distance_to_player()) > 14.0
			var lunges := has_room and not _striking_up
			velocity.x = facing * strike_lunge_speed if lunges else 0.0
			var hitbox := up_hitbox if _striking_up else attack_hitbox
			if not _has_hit and hitbox.overlaps_body(player):
				_has_hit = player.take_damage(attack_damage * damage_multiplier, global_position.x)
			if _state_time >= strike_time:
				_set_state(State.RECOVER)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			if _state_time >= recover_time:
				_set_state(State.CHASE)


## The hitboxes that can deal damage right now (used by the debug overlay).
func get_active_hitboxes() -> Array[Area2D]:
	if state == State.STRIKE:
		return [up_hitbox if _striking_up else attack_hitbox]
	return []


func _on_staggered() -> void:
	_set_state(State.CHASE)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_has_hit = false
	# The hitbox always sits in front of the grunt.
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * facing
	match state:
		State.WINDUP:
			Sfx.play(&"windup")
		State.STRIKE:
			Sfx.play(&"enemy_swing")


func _update_visuals() -> void:
	# Placeholder telegraph: turn yellow and raise the weapon during wind-up.
	match state:
		State.WINDUP:
			body.color = Color(1.0, 0.85, 0.2)
			weapon.rotation = deg_to_rad(110.0)
		State.STRIKE:
			body.color = Color(1.0, 1.0, 1.0)
			weapon.rotation = deg_to_rad(-90.0 if _striking_up else -20.0)
		State.RECOVER:
			body.color = _body_color.darkened(0.35)
			weapon.rotation = deg_to_rad(-90.0 if _striking_up else -20.0)
		_:
			body.color = _body_color
			weapon.rotation = deg_to_rad(40.0)

	# Show where the swing hits: in front, or above for the upward swing.
	swipe.visible = state == State.STRIKE or (state == State.RECOVER and _state_time < 0.06)
	if _striking_up:
		swipe.position = Vector2(0.0, -30.0)
		swipe.rotation = -PI / 2.0
		swipe.scale = Vector2(1.5, 1.5)
	else:
		swipe.position = Vector2(14.0, -13.0)
		swipe.rotation = 0.0
		swipe.scale = Vector2.ONE
