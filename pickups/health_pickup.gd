class_name HealthPickup
extends Area2D
## Restores health when touched. Dropped by enemies.
##
## It stays on the ground until collected, but like everything else it is
## gone for good once it scrolls off the left side of the screen.

@export var heal_amount := 20.0

@onready var visual: Node2D = $Visual


func _physics_process(_delta: float) -> void:
	# Gentle bobbing so it catches the eye.
	visual.position.y = -10.0 + sin(Time.get_ticks_msec() / 200.0) * 2.0
	# Checked every frame (rather than with the body_entered signal) so a
	# pickup the player is already standing on is collected as soon as
	# they need it.
	for hit_body in get_overlapping_bodies():
		if hit_body is Player and hit_body.health < hit_body.max_health:
			hit_body.heal(heal_amount)
			Sfx.play(&"pickup")
			queue_free()
			return
