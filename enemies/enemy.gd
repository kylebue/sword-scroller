class_name Enemy
extends CharacterBody2D
## Base class for every enemy, including the boss.
##
## It handles the things all enemies share: health, taking damage, being
## knocked back and staggered, flashing when hit, dying and dropping health.
## Each kind of enemy extends this script and overrides _behave() with its
## own AI (see grunt.gd for the simplest example).

signal health_changed(current: float, maximum: float)
signal died(enemy: Enemy)

@export var max_health := 30.0
@export var move_speed := 60.0
## If true, being hit interrupts whatever this enemy was doing.
@export var can_be_staggered := true
## How long the enemy is stunned after being hit.
@export var stagger_time := 0.25
## After a stagger wears off, hits still hurt the enemy but cannot interrupt
## it again for this long. This stops the player from stun-locking a tough
## enemy forever by mashing attack. 0 = can always be interrupted.
@export var stagger_cooldown := 0.0
@export_range(0.0, 1.0) var health_drop_chance := 0.15
@export var health_drop_amount := 20.0
@export var health_pickup_scene: PackedScene
@export var hit_spark_scene: PackedScene
## Name of the sound (from audio/sfx.gd) played when this enemy dies.
@export var death_sound := &"enemy_die"

const GRAVITY := 1400.0
const MAX_FALL_SPEED := 600.0
const KNOCKBACK_FRICTION := 900.0
const FLASH_TIME := 0.08
## Colour values above 1 over-brighten the sprite, giving a white flash.
const FLASH_COLOR := Color(10.0, 10.0, 10.0)

var health := 0.0
## 1 = facing right, -1 = facing left.
var facing := -1
var is_dead := false

# Set by apply_difficulty(). Subclasses multiply their numbers by these.
var damage_multiplier := 1.0
var speed_multiplier := 1.0
var telegraph_multiplier := 1.0

var _stagger_timer := 0.0
var _stagger_cooldown_timer := 0.0
var _flash_timer := 0.0

@onready var visuals: Node2D = $Visuals
@onready var player := get_tree().get_first_node_in_group("player") as Player
@onready var camera := get_tree().get_first_node_in_group("camera") as GameCamera


func _ready() -> void:
	health = max_health
	add_to_group("enemies")


## Scales this enemy for how far the player has travelled.
## Must be called BEFORE the enemy is added to the scene.
func apply_difficulty(level: float) -> void:
	max_health *= Difficulty.enemy_health_multiplier(level)
	damage_multiplier = Difficulty.enemy_damage_multiplier(level)
	speed_multiplier = Difficulty.enemy_speed_multiplier(level)
	telegraph_multiplier = Difficulty.telegraph_multiplier(level)


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_flash_timer = maxf(_flash_timer - delta, 0.0)

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	elif _stagger_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
		_stagger_timer -= delta
		if _stagger_timer <= 0.0:
			_stagger_cooldown_timer = stagger_cooldown
	else:
		_stagger_cooldown_timer = maxf(_stagger_cooldown_timer - delta, 0.0)
		if player == null or player.state == Player.State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
		else:
			_behave(delta)

	move_and_slide()
	visuals.scale.x = facing  # All art is drawn facing right.
	visuals.modulate = FLASH_COLOR if _flash_timer > 0.0 else Color.WHITE
	_update_visuals()


## Called by the player's sword. `knockback` is a velocity in pixels/second.
func take_damage(amount: float, knockback: Vector2) -> void:
	if is_dead:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	_flash_timer = FLASH_TIME
	_spawn_hit_spark()
	if health <= 0.0:
		_die(knockback)
	elif can_be_staggered and _stagger_cooldown_timer <= 0.0:
		_stagger_timer = stagger_time
		velocity = knockback
		_on_staggered()


## Signed horizontal distance to the player (positive = player is to the right).
func distance_to_player() -> float:
	return player.global_position.x - global_position.x


func face_player() -> void:
	facing = 1 if distance_to_player() >= 0.0 else -1


# --- Functions for subclasses to override -----------------------------------

## The hitboxes that can deal damage right now (used by the debug overlay).
func get_active_hitboxes() -> Array[Area2D]:
	return []


## The enemy's AI. Runs every physics frame while alive and not staggered.
func _behave(_delta: float) -> void:
	pass


## Called when a hit interrupts the enemy, so it can cancel its attack.
func _on_staggered() -> void:
	pass


## Called every physics frame so subclasses can update placeholder visuals.
func _update_visuals() -> void:
	pass


# --- Internals ---------------------------------------------------------------

func _die(knockback: Vector2) -> void:
	is_dead = true
	# Stop being a target, but keep colliding with the ground while falling.
	collision_layer = 0
	remove_from_group("enemies")
	velocity = Vector2(knockback.x * 1.4, -220.0)
	died.emit(self)
	Sfx.play(death_sound)
	_drop_health()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	tween.tween_callback(queue_free)


func _drop_health() -> void:
	if health_pickup_scene == null or randf() >= health_drop_chance:
		return
	var pickup := health_pickup_scene.instantiate() as HealthPickup
	pickup.position = position
	pickup.heal_amount = health_drop_amount
	get_parent().add_child.call_deferred(pickup)


func _spawn_hit_spark() -> void:
	if hit_spark_scene == null:
		return
	var spark := hit_spark_scene.instantiate() as Node2D
	spark.position = position + Vector2(0.0, -14.0)
	get_parent().add_child(spark)
