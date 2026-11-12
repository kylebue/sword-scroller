class_name EncounterSpawner
extends Node
## Spawns groups of enemies just off the right side of the screen as the
## player advances.
##
## Spawning is tied to how far the camera has scrolled, not to time. If the
## player stops to fight, nothing new arrives; pushing forward is what brings
## the next group. How big and how frequent the groups are comes from
## difficulty.gd.

@export var grunt_scene: PackedScene
@export var spitter_scene: PackedScene
## Distance travelled before the very first enemy appears.
@export var first_encounter_m := 25.0

## Enemies appear this far beyond the right edge of the screen.
const SPAWN_MARGIN := 40.0
const FLOOR_Y := 300.0

## Turned off by main.gd during boss fights.
var enabled := true

var _next_spawn_x := 0.0

@onready var _camera := get_tree().get_first_node_in_group("camera") as GameCamera
@onready var _entities: Node2D = %Entities


func _ready() -> void:
	_next_spawn_x = first_encounter_m * Difficulty.PIXELS_PER_METER


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	var spawn_x := _camera.right_edge() + SPAWN_MARGIN
	if spawn_x < _next_spawn_x:
		return
	var level := Difficulty.level_at(spawn_x / Difficulty.PIXELS_PER_METER)
	# Too crowded already? Check again after a little more scrolling.
	if get_tree().get_nodes_in_group("enemies").size() >= Difficulty.max_enemies_alive(level):
		_next_spawn_x = spawn_x + 96.0
		return
	_spawn_encounter(spawn_x, level)
	_next_spawn_x = spawn_x + Difficulty.encounter_spacing(level)


## Call after a boss fight so enemies do not pour in the moment it ends.
func skip_ahead(pixels: float) -> void:
	_next_spawn_x = _camera.right_edge() + SPAWN_MARGIN + pixels


func _spawn_encounter(spawn_x: float, level: float) -> void:
	for i in Difficulty.encounter_size(level):
		var scene := grunt_scene
		if randf() < Difficulty.ranged_chance(level):
			scene = spitter_scene
		var enemy := scene.instantiate() as Enemy
		enemy.apply_difficulty(level)
		enemy.position = Vector2(spawn_x + i * 30.0 + randf_range(0.0, 12.0), FLOOR_Y)
		_entities.add_child(enemy)
