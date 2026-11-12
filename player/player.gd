class_name Player
extends CharacterBody2D
## The player character: running, jumping and the three-hit sword combo.
##
## Everything that affects how the controls FEEL is an exported variable (see
## the Inspector with the Player node selected) or lives in the ATTACKS table
## below, so you can tune the game without rewriting logic.
##
## Tricks used here to make the controls feel tight:
##  - Input buffering: a jump/attack pressed slightly too early still happens.
##  - Coyote time: you can still jump for a moment after leaving the ground.
##  - Variable jump height: tap for a hop, hold for a full jump.
##  - Faster falling than rising, so jumps feel snappy instead of floaty.
##  - Combo cancelling: the next swing can interrupt the previous swing's
##    recovery, so mashing attack flows instead of waiting on animations.
##  - Dash cancelling: a dash can interrupt a sword swing at any time, so
##    you are never stuck in an attack when you need to get away.
##  - Downward swing: hold down and attack in the air to swing below you.
##    Landing a hit bounces you back up and gives your air dash back.

signal health_changed(current: float, maximum: float)
signal died

enum State { NORMAL, DASH, HURT, DEAD }

## What kind of sword swing is in progress, if any.
enum Swing { NONE, COMBO, DOWN }

## The sword combo. Each entry is one swing. All times are in seconds.
##   startup   - delay between pressing attack and the blade being able to hit
##   active    - how long the blade can hit
##   recovery  - time after the swing before you are back to normal
##               (the next swing in the combo can skip this!)
##   damage    - damage dealt to each enemy hit
##   knockback - how hard enemies are pushed away (pixels per second)
##   lunge     - forward speed during the swing while on the ground
##   hitstop   - freeze time when the swing connects
##   shake     - screen shake when the swing connects (pixels)
##   swing_sound, hit_sound - names of sounds in audio/sfx.gd
const ATTACKS: Array[Dictionary] = [
	{
		"startup": 0.033, "active": 0.085, "recovery": 0.13,
		"damage": 10.0, "knockback": 120.0, "lunge": 120.0,
		"hitstop": 0.04, "shake": 1.5,
		"swing_sound": &"swing", "hit_sound": &"hit",
	},
	{
		"startup": 0.033, "active": 0.085, "recovery": 0.13,
		"damage": 10.0, "knockback": 120.0, "lunge": 120.0,
		"hitstop": 0.04, "shake": 1.5,
		"swing_sound": &"swing", "hit_sound": &"hit",
	},
	{
		"startup": 0.05, "active": 0.1, "recovery": 0.24,
		"damage": 18.0, "knockback": 270.0, "lunge": 170.0,
		"hitstop": 0.085, "shake": 4.0,
		"swing_sound": &"swing_heavy", "hit_sound": &"hit_heavy",
	},
]

## The downward swing (hold down + attack in the air). It uses the same
## fields as the ATTACKS entries above, and has a longer `active` time so it
## is easier to land while falling.
const DOWN_SWING: Dictionary = {
	"startup": 0.033, "active": 0.15, "recovery": 0.12,
	"damage": 12.0, "knockback": 0.0, "lunge": 0.0,
	"hitstop": 0.05, "shake": 2.0,
	"swing_sound": &"swing", "hit_sound": &"hit",
}

## Half the width of the collision shape. Used to keep the player on screen.
const HALF_WIDTH := 6.0

@export_group("Movement")
## Top running speed in pixels per second.
@export var run_speed := 190.0
## How quickly you reach top speed on the ground. Higher = snappier.
@export var ground_acceleration := 3000.0
## How quickly you stop on the ground when no direction is held.
@export var ground_friction := 3600.0
## How quickly you reverse direction on the ground.
@export var turn_acceleration := 6000.0
## Horizontal control while in the air.
@export var air_acceleration := 2200.0
## How quickly you slow down in the air when no direction is held.
@export var air_friction := 1000.0

@export_group("Jump")
## Height of a full jump in pixels.
@export var jump_height := 60.0
## Seconds from leaving the ground to the top of a full jump.
@export var jump_time_to_peak := 0.32
## Gravity is multiplied by this while falling. Above 1 = less floaty.
@export var fall_gravity_multiplier := 1.6
## Upward speed is multiplied by this when jump is released early.
@export var jump_cut_multiplier := 0.4
@export var max_fall_speed := 520.0
## Grace period after walking off a ledge in which you can still jump.
@export var coyote_time := 0.09
## A jump pressed this long before landing still happens on landing.
@export var jump_buffer_time := 0.12

@export_group("Dash")
## Dash speed in pixels per second.
## Distance covered = dash_speed x dash_duration (about 80 pixels by default).
@export var dash_speed := 480.0
## How long a dash lasts. It cannot be cancelled once it starts.
@export var dash_duration := 0.16
## Delay after a dash ends before you can dash again.
@export var dash_cooldown := 0.3
## How many dashes you get in the air before you must land again.
@export var air_dashes := 1
## A dash pressed this long before it is possible still happens. This also
## covers pressing dash a split second before pressing a direction.
@export var dash_buffer_time := 0.12

@export_group("Combat")
@export var max_health := 100.0
## An attack pressed this long before it is possible still happens.
@export var attack_buffer_time := 0.18
## After a swing ends you have this long to press attack and continue the
## combo. Wait longer and the combo starts again from the first swing.
@export var combo_reset_time := 0.35
## Movement speed multiplier while recovering from a ground swing.
@export var attack_move_multiplier := 0.5
## How high (in pixels) you bounce when a downward swing hits something.
## Set to 0 for no bounce.
@export var down_swing_bounce_height := 40.0
## How long you lose control after being hit.
@export var hurt_time := 0.22
## How long you cannot be hit again after being hit.
@export var invincibility_time := 0.9
## Knockback when hit: x is away from the attacker, y is upward (negative).
@export var hurt_knockback := Vector2(170.0, -150.0)

var state := State.NORMAL
## 1 = facing right, -1 = facing left.
var facing := 1
var health := 0.0

# Worked out from jump_height and jump_time_to_peak in _ready().
var _gravity := 0.0
var _jump_velocity := 0.0

# Timers count down to zero. "Greater than zero" means "still active".
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _attack_buffer_timer := 0.0
var _dash_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _combo_timer := 0.0
var _hurt_timer := 0.0
var _invincible_timer := 0.0

## True while rising from a jump with the button still held.
var _is_jumping := false
## Seconds spent off the ground (used for the landing sound).
var _air_time := 0.0

## 1 = dashing right, -1 = dashing left. Independent of `facing`.
var _dash_direction := 1
var _air_dashes_left := 0

## The kind of swing in progress. Swing.NONE means "not attacking".
var _swing := Swing.NONE
## Which entry of ATTACKS is being performed (only used by combo swings).
var _attack_index := 0
## Seconds since the current swing started.
var _attack_time := 0.0
## Which swing the next attack press will start.
var _combo_step := 0
## Things already hit by the current swing, so each swing hits a target once.
var _already_hit: Array[Node] = []

@onready var visuals: Node2D = $Visuals
@onready var body: Polygon2D = $Visuals/Body
@onready var sword: Polygon2D = $Visuals/Sword
@onready var slash: Polygon2D = $Visuals/Slash
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var down_hitbox: Area2D = $DownHitbox
@onready var close_range_sensor: Area2D = $CloseRangeSensor
@onready var camera := get_tree().get_first_node_in_group("camera") as GameCamera
@onready var _body_color: Color = body.color
@onready var _slash_position: Vector2 = slash.position


func _ready() -> void:
	health = max_health
	# Standard platformer maths: pick the jump height and duration you want
	# and derive gravity and launch speed from them.
	_gravity = 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
	_jump_velocity = 2.0 * jump_height / jump_time_to_peak


## Button presses are caught here (the moment they happen) rather than polled
## in _physics_process, so a press is never missed, even during hitstop.
func _unhandled_input(event: InputEvent) -> void:
	if state == State.DEAD:
		return
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if event.is_action_pressed("attack"):
		_attack_buffer_timer = attack_buffer_time
	if event.is_action_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	match state:
		State.NORMAL:
			_process_normal(delta)
		State.DASH:
			_process_dash(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEAD:
			_process_dead(delta)
	move_and_slide()
	_update_air_time(delta)
	_keep_on_screen()
	_update_visuals()


func is_attacking() -> bool:
	return _swing != Swing.NONE


## The hitboxes that can deal damage right now (used by the debug overlay).
func get_active_hitboxes() -> Array[Area2D]:
	if is_attacking():
		var attack := _get_attack()
		var active_start: float = attack["startup"]
		var active_end: float = active_start + attack["active"]
		if _attack_time >= active_start and _attack_time < active_end:
			return [down_hitbox if _swing == Swing.DOWN else sword_hitbox]
	return []


## Called by enemies and projectiles. `from_x` is the attacker's x position,
## used to knock the player away from it. Returns true if the hit landed.
func take_damage(amount: float, from_x: float) -> bool:
	if state == State.DEAD or _invincible_timer > 0.0:
		return false
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	_swing = Swing.NONE
	_combo_step = 0
	_is_jumping = false
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(away * hurt_knockback.x, hurt_knockback.y)
	GameFeel.hitstop(0.1)
	GameFeel.shake(5.0)
	Sfx.play(&"player_die" if health <= 0.0 else &"player_hurt")
	if health <= 0.0:
		state = State.DEAD
		died.emit()
	else:
		state = State.HURT
		_hurt_timer = hurt_time
		_invincible_timer = invincibility_time
	return true


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


# --- States ------------------------------------------------------------------

func _process_normal(delta: float) -> void:
	# signf() turns analog stick input into -1, 0 or 1: movement is all or
	# nothing, which feels more precise for this kind of game.
	var input_dir := signf(Input.get_axis("move_left", "move_right"))
	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = coyote_time
		_is_jumping = false
		_air_dashes_left = air_dashes

	# A dash needs a direction to be held: it goes where you are pressing,
	# not where the character happens to be facing.
	var has_dash_available := on_floor or _air_dashes_left > 0
	if _dash_buffer_timer > 0.0 and _dash_cooldown_timer <= 0.0 and input_dir != 0.0 and has_dash_available:
		_start_dash(int(input_dir), on_floor)
		_process_dash(delta)  # Start moving on this very frame.
		return

	_update_attack(delta, input_dir, on_floor)

	# Facing is locked during a swing; each new swing can pick a new direction.
	if not is_attacking() and input_dir != 0.0:
		_set_facing(int(input_dir))

	# Horizontal movement.
	var target_speed := input_dir * run_speed
	if is_attacking() and on_floor:
		target_speed = _get_ground_attack_speed(input_dir)
	var acceleration: float
	if not on_floor:
		acceleration = air_acceleration if input_dir != 0.0 else air_friction
	elif target_speed == 0.0:
		acceleration = ground_friction
	elif signf(target_speed) != signf(velocity.x) and velocity.x != 0.0:
		acceleration = turn_acceleration
	else:
		acceleration = ground_acceleration
	velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)

	# Vertical movement.
	_apply_gravity(delta)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = -_jump_velocity
		Sfx.play(&"jump")
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_is_jumping = true
	# Variable jump height: letting go of jump early cuts the jump short.
	if _is_jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut_multiplier
		_is_jumping = false


## A dash is a short burst in a straight line. Nothing the player presses
## can interrupt it, and it gives no protection: getting hit still hurts
## (and is the one thing that does cut a dash short).
func _process_dash(_delta: float) -> void:
	velocity = Vector2(_dash_direction * dash_speed, 0.0)
	if _dash_timer <= 0.0:
		state = State.NORMAL
		_dash_cooldown_timer = dash_cooldown
		# Come out of the dash at running speed rather than a dead stop.
		velocity.x = _dash_direction * run_speed


func _start_dash(direction: int, on_floor: bool) -> void:
	state = State.DASH
	Sfx.play(&"dash")
	_dash_direction = direction
	_dash_timer = dash_duration
	_dash_buffer_timer = 0.0
	if not on_floor:
		_air_dashes_left -= 1
	# Dashing cancels whatever swing was in progress.
	_swing = Swing.NONE
	_combo_step = 0
	_is_jumping = false


func _process_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	if _hurt_timer <= 0.0:
		state = State.NORMAL


func _process_dead(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)


func _apply_gravity(delta: float) -> void:
	var gravity := _gravity
	if velocity.y > 0.0:
		gravity *= fall_gravity_multiplier
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


# --- Sword combo -------------------------------------------------------------

func _update_attack(delta: float, input_dir: float, on_floor: bool) -> void:
	# Holding down while attacking in the air swings downward instead.
	var wants_down_swing := not on_floor and Input.is_action_pressed("move_down")

	# Landing ends a downward swing straight away, so you can act at once.
	if _swing == Swing.DOWN and on_floor:
		_swing = Swing.NONE
		_combo_step = 0

	if not is_attacking():
		if _attack_buffer_timer > 0.0:
			if wants_down_swing:
				_start_down_swing()
			else:
				_start_attack(_combo_step if _combo_timer > 0.0 else 0, input_dir)
		return

	_attack_time += delta
	var attack := _get_attack()
	var active_start: float = attack["startup"]
	var active_end: float = active_start + attack["active"]
	var attack_end: float = active_end + attack["recovery"]

	if _attack_time >= active_start and _attack_time < active_end:
		_hit_with_sword(attack)

	# Every swing except the combo finisher can be cancelled into another
	# swing. For downward swings this is what lets you bounce on an enemy
	# again and again without needing perfect timing.
	var can_chain := _swing == Swing.DOWN or _attack_index < ATTACKS.size() - 1
	if _attack_time >= active_end and _attack_buffer_timer > 0.0 and can_chain:
		# Combo cancel: skip the rest of the recovery and swing again.
		if wants_down_swing:
			_start_down_swing()
		else:
			_start_attack(_attack_index + 1 if _swing == Swing.COMBO else 0, input_dir)
	elif _attack_time >= attack_end:
		# A finished combo swing leads on to the next one; a downward swing
		# starts the combo over.
		_combo_step = (_attack_index + 1) % ATTACKS.size() if _swing == Swing.COMBO else 0
		_combo_timer = combo_reset_time
		_swing = Swing.NONE


## The data for the swing in progress.
func _get_attack() -> Dictionary:
	return DOWN_SWING if _swing == Swing.DOWN else ATTACKS[_attack_index]


func _start_attack(index: int, input_dir: float) -> void:
	_swing = Swing.COMBO
	_attack_index = index
	Sfx.play(ATTACKS[index]["swing_sound"])
	_attack_time = 0.0
	_attack_buffer_timer = 0.0
	_already_hit.clear()
	# Holding a direction when a swing starts turns you that way, so you can
	# instantly attack behind you.
	if input_dir != 0.0:
		_set_facing(int(input_dir))


func _start_down_swing() -> void:
	_swing = Swing.DOWN
	Sfx.play(DOWN_SWING["swing_sound"])
	_attack_time = 0.0
	_attack_buffer_timer = 0.0
	_already_hit.clear()


## Target horizontal speed while swinging on the ground.
func _get_ground_attack_speed(input_dir: float) -> float:
	var attack := _get_attack()
	var lunge_end: float = attack["startup"] + attack["active"]
	if _attack_time < lunge_end:
		# Step forward with the swing, unless the player is holding back or
		# an enemy is already right in front. Without the second check, the
		# lunge would carry you through enemies that do not get knocked back
		# (like the boss) and the next swing would miss behind them.
		if input_dir * facing < 0.0 or close_range_sensor.has_overlapping_bodies():
			return 0.0
		return facing * float(attack["lunge"])
	return input_dir * run_speed * attack_move_multiplier


func _hit_with_sword(attack: Dictionary) -> void:
	var hitbox := down_hitbox if _swing == Swing.DOWN else sword_hitbox
	var hit_something := false
	# Enemies are physics bodies...
	for target in hitbox.get_overlapping_bodies():
		if target in _already_hit or not target.has_method("take_damage"):
			continue
		_already_hit.append(target)
		var knockback := Vector2(facing * float(attack["knockback"]), -60.0)
		target.take_damage(attack["damage"], knockback)
		hit_something = true
	# ...and enemy projectiles are areas, which the sword can destroy.
	for target in hitbox.get_overlapping_areas():
		if target in _already_hit or not target.has_method("on_sword_hit"):
			continue
		_already_hit.append(target)
		target.on_sword_hit()
		hit_something = true
	if hit_something:
		GameFeel.hitstop(attack["hitstop"])
		GameFeel.shake(attack["shake"])
		Sfx.play(attack["hit_sound"])
		if _swing == Swing.DOWN and down_swing_bounce_height > 0.0:
			_bounce()


## Pops the player back up after a downward swing connects.
func _bounce() -> void:
	# The launch speed needed to rise exactly `down_swing_bounce_height`.
	velocity.y = -sqrt(2.0 * _gravity * down_swing_bounce_height)
	Sfx.play(&"bounce")
	# Not a held jump, so letting go of the jump button must not cut it short.
	_is_jumping = false
	_air_dashes_left = air_dashes


# --- Helpers -----------------------------------------------------------------

func _set_facing(direction: int) -> void:
	facing = direction
	# The sword hitbox and close-range sensor always sit in front of the player.
	sword_hitbox.position.x = absf(sword_hitbox.position.x) * facing
	close_range_sensor.position.x = absf(close_range_sensor.position.x) * facing


## Tracks time in the air so that landing can make a sound. Tiny hops off
## the ground (shorter than a few frames) stay silent.
func _update_air_time(delta: float) -> void:
	if is_on_floor():
		if _air_time > 0.12:
			Sfx.play(&"land")
		_air_time = 0.0
	else:
		_air_time += delta


func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	_dash_buffer_timer = maxf(_dash_buffer_timer - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	if not is_attacking():
		_combo_timer = maxf(_combo_timer - delta, 0.0)


## The screen never scrolls back, so the left edge of the screen is a wall.
## (The right edge only matters while the camera is locked for a boss fight.)
func _keep_on_screen() -> void:
	if camera == null:
		return
	var min_x := camera.left_edge() + HALF_WIDTH
	var max_x := camera.right_edge() - HALF_WIDTH
	if global_position.x < min_x:
		global_position.x = min_x
		velocity.x = maxf(velocity.x, 0.0)
	elif global_position.x > max_x:
		global_position.x = max_x
		velocity.x = minf(velocity.x, 0.0)


## Placeholder visuals. When real art exists, this is the function that will
## choose which animation to play instead.
func _update_visuals() -> void:
	visuals.scale.x = facing

	var slash_visible := false
	if is_attacking():
		var attack := _get_attack()
		var active_start: float = attack["startup"]
		# Keep the slash on screen slightly longer than it can hit so it reads.
		var slash_end: float = active_start + attack["active"] + 0.04
		slash_visible = _attack_time >= active_start and _attack_time < slash_end
		if _swing == Swing.DOWN:
			# Point the slash straight down, underneath the player.
			slash.position = Vector2(0.0, -4.0)
			slash.rotation = PI / 2.0
			slash.scale = Vector2(1.2, 1.2)
		else:
			slash.position = _slash_position
			slash.rotation = 0.0
			# Alternate the slash direction per swing; the finisher is bigger.
			match _attack_index:
				0: slash.scale = Vector2(1.0, 1.0)
				1: slash.scale = Vector2(1.0, -1.0)
				_: slash.scale = Vector2(1.3, 1.3)
	slash.visible = slash_visible
	sword.visible = not is_attacking()

	visuals.scale.y = 1.0
	if state == State.DEAD:
		body.color = Color(0.3, 0.3, 0.35)
		visuals.rotation = -PI / 2.0 * facing if is_on_floor() else 0.0
	elif state == State.HURT:
		body.color = Color(1.0, 0.35, 0.35)
	elif state == State.DASH:
		# Placeholder dash look: brighter, and stretched into a streak.
		body.color = _body_color.lightened(0.5)
		visuals.scale = Vector2(facing * 1.5, 0.75)
	else:
		body.color = _body_color

	# Blink while invincible after being hit.
	var blink := _invincible_timer > 0.0 and fmod(_invincible_timer, 0.12) < 0.06
	visuals.modulate.a = 0.35 if blink else 1.0
