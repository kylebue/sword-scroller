class_name GroundChunk
extends StaticBody2D
## One screen-wide piece of the endless level: a strip of solid ground plus
## some placeholder scenery so you can see the world scrolling.
##
## The level generator places these side by side. When real art exists this
## scene is where a TileMapLayer (and platforms, pits, etc.) would go.

const WIDTH := 640.0
const FLOOR_Y := 300.0

const GROUND_COLOR := Color(0.24, 0.21, 0.2)
const GRASS_COLOR := Color(0.42, 0.58, 0.32)
const TICK_COLOR := Color(0.17, 0.15, 0.15)
const SCENERY_COLOR := Color(0.14, 0.17, 0.23)
const SIGN_COLOR := Color(0.75, 0.7, 0.55)

## Which piece of the level this is: chunk 0 starts at x = 0, chunk 1 at
## x = 640, and so on. Set by the level generator.
var chunk_index := 0


func _draw() -> void:
	# Seeding the random generator with the chunk index means a chunk always
	# looks the same, no matter when it is created.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk_index)

	# Background scenery (placeholder "trees").
	for i in rng.randi_range(3, 6):
		var w := rng.randf_range(10.0, 26.0)
		var h := rng.randf_range(30.0, 110.0)
		var x := rng.randf_range(0.0, WIDTH - w)
		draw_rect(Rect2(x, FLOOR_Y - h, w, h), SCENERY_COLOR)
		draw_rect(Rect2(x - w * 0.6, FLOOR_Y - h - w, w * 2.2, w * 1.4), SCENERY_COLOR)

	# Ground.
	draw_rect(Rect2(0.0, FLOOR_Y, WIDTH, 60.0), GROUND_COLOR)
	draw_rect(Rect2(0.0, FLOOR_Y, WIDTH, 3.0), GRASS_COLOR)

	# A tick every metre and a sign post every 10 metres.
	var font := ThemeDB.fallback_font
	var meters_per_chunk := int(WIDTH / Difficulty.PIXELS_PER_METER)
	for i in meters_per_chunk:
		var x := i * Difficulty.PIXELS_PER_METER
		var meter := chunk_index * meters_per_chunk + i
		draw_rect(Rect2(x, FLOOR_Y + 3.0, 1.0, 5.0), TICK_COLOR)
		if meter > 0 and meter % 10 == 0:
			draw_rect(Rect2(x, FLOOR_Y - 20.0, 2.0, 20.0), SIGN_COLOR)
			draw_string(font, Vector2(x + 4.0, FLOOR_Y - 12.0), "%d m" % meter,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, SIGN_COLOR)
