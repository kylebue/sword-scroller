class_name LevelGenerator
extends Node2D
## Builds the endless level one chunk at a time.
##
## Chunks are created just before they scroll into view on the right and
## deleted once they are well off the left side of the screen, so the game
## only ever has a few of them in memory no matter how far the player runs.

@export var chunk_scene: PackedScene
## How many pixels beyond each screen edge the level should exist.
@export var margin := 400.0

const CHUNK_WIDTH := 640.0

## The chunks that currently exist, stored as chunk_index -> chunk node.
var _chunks: Dictionary[int, GroundChunk] = {}

@onready var _camera := get_tree().get_first_node_in_group("camera") as GameCamera


func _ready() -> void:
	# Make sure there is ground under the player on the very first frame.
	update_chunks()


func _physics_process(_delta: float) -> void:
	update_chunks()


func update_chunks() -> void:
	var first := floori((_camera.left_edge() - margin) / CHUNK_WIDTH)
	var last := floori((_camera.right_edge() + margin) / CHUNK_WIDTH)

	for index in range(first, last + 1):
		if not _chunks.has(index):
			var chunk := chunk_scene.instantiate() as GroundChunk
			chunk.chunk_index = index
			chunk.position.x = index * CHUNK_WIDTH
			add_child(chunk)
			_chunks[index] = chunk

	for index: int in _chunks.keys():
		if index < first or index > last:
			_chunks[index].queue_free()
			_chunks.erase(index)
