extends Enemy
## Ranged enemy. Keeps its distance and spits slow projectiles that the
## player can jump over or destroy with the sword.

enum State { POSITION, WINDUP, COOLDOWN }

## Tries to stay between these two distances from the player.
@export var too_close_distance := 80.0
@export var shoot_range := 230.0
@export var projectile_scene: PackedScene
@export var projectile_speed := 150.0
@export var projectile_damage := 8.0
## Warning time before firing. Shrinks as difficulty rises.
@export var windup_time := 0.5
@export var cooldown_time := 1.5

var state := State.POSITION
var _state_time := 0.0

@onready var body: Polygon2D = $Visuals/Body
@onready var _body_color: Color = body.color


func _ready() -> void:
	super()
	# Do not fire the instant it walks on screen.
	_set_state(State.COOLDOWN)
	_state_time = cooldown_time * randf_range(0.3, 0.7)


func _behave(delta: float) -> void:
	_state_time += delta
	face_player()
	var distance := absf(distance_to_player())
	match state:
		State.POSITION:
			if distance > shoot_range or not _is_on_screen():
				velocity.x = facing * move_speed * speed_multiplier
			elif distance < too_close_distance and _can_back_away():
				velocity.x = -facing * move_speed * speed_multiplier
			else:
				_set_state(State.WINDUP)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			if _state_time >= windup_time * telegraph_multiplier:
				_shoot()
				_set_state(State.COOLDOWN)
		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
			if _state_time >= cooldown_time:
				_set_state(State.POSITION)


func _on_staggered() -> void:
	_set_state(State.COOLDOWN)
	_state_time = cooldown_time * 0.5


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _is_on_screen() -> bool:
	return camera == null or global_position.x < camera.right_edge() - 12.0


## Never retreat off the right side of the screen, where the player could
## not reach it.
func _can_back_away() -> bool:
	if facing == 1:
		return true  # Backing away to the left is always fine.
	return camera == null or global_position.x < camera.right_edge() - 24.0


func _shoot() -> void:
	var projectile := projectile_scene.instantiate() as Projectile
	projectile.position = position + Vector2(facing * 10.0, -12.0)
	projectile.velocity = Vector2(facing * projectile_speed * speed_multiplier, 0.0)
	projectile.damage = projectile_damage * damage_multiplier
	get_parent().add_child(projectile)


func _update_visuals() -> void:
	# Placeholder telegraph: blink yellow before firing.
	if state == State.WINDUP:
		var blink := fmod(_state_time, 0.12) < 0.06
		body.color = Color(1.0, 0.85, 0.2) if blink else _body_color
	else:
		body.color = _body_color
