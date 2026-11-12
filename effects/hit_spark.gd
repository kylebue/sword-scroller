extends CPUParticles2D
## A one-shot burst of particles that deletes itself when it is done.


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)
