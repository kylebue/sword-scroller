class_name Boss
extends Enemy
## The boss. It cannot be staggered, and cycles through three attacks, each
## with a clear wind-up (the warning) and a recovery (the opening to hit it):
##
##   SLAM   - big swing covering itself and the space in front of it.
##            Back away or get fully behind it.
##   CHARGE - runs across the arena. Jump over it. It stuns itself on the wall.
##   LEAP   - jumps to where the player is standing. Its body hurts in the
##            air and the landing hurts on the ground. Move out from under
##            it. It also does this if the player is above it, so nobody can
##            sit on its head bouncing with downward swings.

enum State {
	ENTER, IDLE,
	SLAM_WINDUP, SLAM,
	CHARGE_WINDUP, CHARGE,
	LEAP_WINDUP, LEAP, LAND,
	RECOVER,
}

## Pause between attacks.
@export var idle_time := 0.9

@export_group("Slam")
## Uses the slam when the player is within this many pixels.
@export var slam_range := 75.0
@export var slam_windup := 0.55
@export var slam_damage := 22.0
@export var slam_recover := 0.7

@export_group("Charge")
@export var charge_windup := 0.65
@export var charge_speed := 360.0
@export var charge_damage := 18.0
## How long it is stunned after running into the arena wall.
@export var charge_recover := 1.2

@export_group("Leap")
@export var leap_windup := 0.45
## Upward launch speed. Higher = longer in the air.
@export var leap_velocity := 520.0
@export var leap_damage := 20.0
@export var leap_recover := 0.8

## Half the width of the collision shape, used to stay inside the arena.
const HALF_WIDTH := 20.0

var state := State.ENTER
var _state_time := 0.0
var _recover_time := 0.0
var _has_hit := false
var _leap_speed_x := 0.0
## The attack state that led into the current RECOVER state.
var _last_attack := State.IDLE

@onready var body: Polygon2D = $Visuals/Body
@onready var fist: Polygon2D = $Visuals/Fist
@onready var slam_effect: Polygon2D = $Visuals/SlamEffect
@onready var land_effect: Polygon2D = $Visuals/LandEffect
@onready var slam_hitbox: Area2D = $SlamHitbox
@onready var body_hitbox: Area2D = $BodyHitbox
@onready var land_hitbox: Area2D = $LandHitbox
@onready var _body_color: Color = body.color


## Scales the boss. `boss_number` is 1 for the first boss, 2 for the second...
## Must be called BEFORE the boss is added to the scene.
func setup(boss_number: int) -> void:
	max_health *= Difficulty.boss_health_multiplier(boss_number)
	damage_multiplier = Difficulty.boss_damage_multiplier(boss_number)
	speed_multiplier = Difficulty.boss_speed_multiplier(boss_number)
	telegraph_multiplier = Difficulty.boss_telegraph_multiplier(boss_number)


func _behave(delta: float) -> void:
	_state_time += delta
	var touching_wall := false
	if state != State.ENTER:
		touching_wall = _stay_in_arena()

	match state:
		State.ENTER:
			# Walk in from off screen.
			facing = -1
			velocity.x = -move_speed * 2.0
			if camera == null or global_position.x <= camera.right_edge() - 70.0:
				_set_state(State.IDLE)

		State.IDLE:
			face_player()
			var far_away := absf(distance_to_player()) > slam_range * 0.6
			velocity.x = facing * move_speed * speed_multiplier if far_away else 0.0
			if _state_time >= idle_time * telegraph_multiplier:
				_choose_attack()

		State.SLAM_WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			if _state_time >= slam_windup * telegraph_multiplier:
				GameFeel.shake(4.0)
				_set_state(State.SLAM)

		State.SLAM:
			_try_to_hit(slam_hitbox, slam_damage)
			if _state_time >= 0.15:
				_recover(slam_recover)

		State.CHARGE_WINDUP:
			velocity.x = -facing * 25.0  # Rear back before charging.
			if _state_time >= charge_windup * telegraph_multiplier:
				_set_state(State.CHARGE)

		State.CHARGE:
			velocity.x = facing * charge_speed * speed_multiplier
			_try_to_hit(body_hitbox, charge_damage)
			if touching_wall or _state_time >= 2.0:
				GameFeel.shake(6.0)
				Sfx.play(&"boss_slam", 1.3)  # Crashing into the wall.
				velocity = Vector2(-facing * 90.0, -160.0)  # Bounce off the wall.
				_recover(charge_recover)

		State.LEAP_WINDUP:
			velocity.x = 0.0
			if _state_time >= leap_windup * telegraph_multiplier:
				# Aim to land where the player is standing right now.
				var air_time := 2.0 * leap_velocity / GRAVITY
				_leap_speed_x = clampf(distance_to_player() / air_time, -320.0, 320.0)
				velocity.y = -leap_velocity
				_set_state(State.LEAP)

		State.LEAP:
			velocity.x = _leap_speed_x
			_try_to_hit(body_hitbox, leap_damage)
			if _state_time > 0.1 and is_on_floor():
				GameFeel.shake(7.0)
				_set_state(State.LAND)

		State.LAND:
			velocity.x = 0.0
			_try_to_hit(land_hitbox, leap_damage)
			if _state_time >= 0.12:
				_recover(leap_recover)

		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			if _state_time >= _recover_time:
				_set_state(State.IDLE)


## The hitboxes that can deal damage right now (used by the debug overlay).
func get_active_hitboxes() -> Array[Area2D]:
	match state:
		State.SLAM:
			return [slam_hitbox]
		State.CHARGE, State.LEAP:
			return [body_hitbox]
		State.LAND:
			return [land_hitbox]
	return []


func _choose_attack() -> void:
	var roll := randf()
	var player_is_above := global_position.y - player.global_position.y > 40.0
	if player_is_above and absf(distance_to_player()) <= slam_range:
		_set_state(State.LEAP_WINDUP)
	elif absf(distance_to_player()) <= slam_range:
		_set_state(State.SLAM_WINDUP if roll < 0.65 else State.LEAP_WINDUP)
	else:
		_set_state(State.CHARGE_WINDUP if roll < 0.55 else State.LEAP_WINDUP)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_has_hit = false
	# The slam hitbox covers the boss and the space in front of it.
	slam_hitbox.position.x = absf(slam_hitbox.position.x) * facing
	# The boss reuses the normal sounds at a lower pitch, so it sounds big.
	match state:
		State.SLAM_WINDUP, State.CHARGE_WINDUP, State.LEAP_WINDUP:
			Sfx.play(&"windup", 0.6)
		State.SLAM, State.LAND:
			Sfx.play(&"boss_slam")
		State.CHARGE:
			Sfx.play(&"dash", 0.6)
		State.LEAP:
			Sfx.play(&"jump", 0.5)


func _recover(duration: float) -> void:
	_last_attack = state
	_recover_time = duration
	_set_state(State.RECOVER)


## Each attack can only damage the player once.
func _try_to_hit(hitbox: Area2D, damage: float) -> void:
	if not _has_hit and hitbox.overlaps_body(player):
		_has_hit = player.take_damage(damage * damage_multiplier, global_position.x)


## Keeps the boss on screen. Returns true if it is touching an arena wall.
func _stay_in_arena() -> bool:
	if camera == null:
		return false
	var min_x := camera.left_edge() + HALF_WIDTH
	var max_x := camera.right_edge() - HALF_WIDTH
	var clamped_x := clampf(global_position.x, min_x, max_x)
	var touching := clamped_x != global_position.x
	global_position.x = clamped_x
	return touching


func _update_visuals() -> void:
	# Placeholder telegraphs: a different colour for each wind-up, and a
	# dull colour while recovering to show "hit me now".
	visuals.scale.y = 1.0
	fist.position = Vector2.ZERO
	match state:
		State.SLAM_WINDUP:
			body.color = Color(1.0, 0.85, 0.2)
			fist.position = Vector2(-22.0, -36.0)  # Raised behind its head.
		State.CHARGE_WINDUP:
			body.color = Color(1.0, 0.3, 0.2)
		State.LEAP_WINDUP:
			body.color = Color(0.4, 0.9, 1.0)
			visuals.scale.y = 0.8  # Crouch.
		State.SLAM:
			body.color = Color(1.0, 1.0, 1.0)
			fist.position = Vector2(34.0, 14.0)  # Smashed into the ground in front.
		State.CHARGE, State.LEAP, State.LAND:
			body.color = Color(1.0, 1.0, 1.0)
		State.RECOVER:
			body.color = _body_color.darkened(0.45)
		_:
			body.color = _body_color

	# Show where the slam and the leap landing actually hit. The effects stay
	# visible a moment longer than the hit itself so they are easy to read.
	var just_finished := state == State.RECOVER and _state_time < 0.1
	slam_effect.visible = state == State.SLAM or (just_finished and _last_attack == State.SLAM)
	land_effect.visible = state == State.LAND or (just_finished and _last_attack == State.LAND)
	if slam_effect.visible:
		fist.position = Vector2(34.0, 14.0)
