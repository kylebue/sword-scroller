class_name Projectile
extends Area2D
## A slow enemy projectile. Hurts the player on contact and can be destroyed
## with the sword.

@export var lifetime := 5.0

var velocity := Vector2.ZERO
var damage := 8.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation += 8.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


## Called by the player's sword.
func on_sword_hit() -> void:
	queue_free()


func _on_body_entered(hit_body: Node2D) -> void:
	if hit_body is Player:
		# take_damage() returns false while the player is invincible, in
		# which case the projectile just passes through.
		if hit_body.take_damage(damage, global_position.x):
			queue_free()
	else:
		queue_free()  # Hit the ground.
