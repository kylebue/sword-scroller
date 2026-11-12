extends Node2D
## Temporary developer tools. main.gd adds this to the game only when debug
## mode was switched on from the main menu.
##
## What it does:
##  - Draws every collision shape, colour coded (see the constants below).
##    Hitboxes are outlines normally and are FILLED IN on the exact frames
##    they can deal damage.
##  - Shows each character's current state (and enemy health) above its head.
##  - Frame stepping: press . (period) or N to freeze the game, press again
##    to advance exactly one physics frame, or hold it to play in slow motion.
##    Esc resumes. Jump/attack/dash presses made while frozen are applied on
##    the next step, and held movement keys work as normal.
##  - Teleport: on the pause screen (Esc), type a distance and press Go.
##
## This node's Process Mode is "Always" so it keeps working while the game
## is paused or frozen.

signal teleport_requested(distance_m: float)

const COLOR_PLAYER_BODY := Color(0.2, 1.0, 0.4)
const COLOR_PLAYER_HITBOX := Color(1.0, 1.0, 0.2)
const COLOR_ENEMY_BODY := Color(1.0, 0.6, 0.1)
const COLOR_ENEMY_HITBOX := Color(1.0, 0.15, 0.15)
## Things that are neither a body nor a hitbox: sensors and pickups.
const COLOR_OTHER := Color(0.4, 0.8, 1.0)

## Button presses to pass on to the game when stepping a frame.
const STEP_ACTIONS: Array[StringName] = [&"jump", &"attack", &"dash"]

var _frozen := false
var _step_requested := false
var _stepping := false
## Which of STEP_ACTIONS were already held at the previous step.
var _held_before: Dictionary[StringName, bool] = {}

@onready var info_label: Label = %InfoLabel
@onready var teleport_panel: Control = %TeleportPanel
@onready var teleport_distance: SpinBox = %TeleportDistance
@onready var teleport_button: Button = %TeleportButton


func _ready() -> void:
	teleport_button.pressed.connect(_on_teleport_pressed)
	teleport_distance.value = DebugMode.start_distance_m


## _input runs before the game's own input handling, so the debug keys win.
func _input(event: InputEvent) -> void:
	# `true` allows key repeat, so holding the key steps again and again.
	if event.is_action_pressed("debug_step", true):
		get_viewport().set_input_as_handled()
		if not get_tree().paused:
			_set_frozen(true)
		elif _frozen:
			_step_requested = true
	elif _frozen and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_set_frozen(false)


func _process(_delta: float) -> void:
	queue_redraw()
	if _step_requested and not _stepping:
		_step_requested = false
		_step_one_frame()
	# The teleport box sits on the normal pause screen (not while frozen).
	teleport_panel.visible = get_tree().paused and not _frozen and not _stepping
	if _frozen:
		info_label.text = "FROZEN at frame %d    . or N: next frame (hold = slow motion)    Esc: resume" % Engine.get_physics_frames()
	else:
		info_label.text = "DEBUG    frame %d    %d fps    enemies: %d    . or N: freeze    Esc: pause + teleport" % [
			Engine.get_physics_frames(), Engine.get_frames_per_second(),
			get_tree().get_nodes_in_group("enemies").size(),
		]


# --- Frame stepping ------------------------------------------------------------

func _set_frozen(frozen: bool) -> void:
	_frozen = frozen
	get_tree().paused = frozen
	if frozen:
		for action in STEP_ACTIONS:
			_held_before[action] = Input.is_action_pressed(action)


func _step_one_frame() -> void:
	_stepping = true
	get_tree().paused = false
	_pass_on_new_presses()
	# The physics_frame signal fires at the START of each physics frame.
	# Waiting for it twice lets exactly one whole frame run in between.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _frozen:
		get_tree().paused = true
	_stepping = false


## The player script listens for button-press events, and it cannot hear
## them while the game is frozen. So any button that has been pressed since
## the last step is "pressed again" here, now that the game is running.
func _pass_on_new_presses() -> void:
	for action in STEP_ACTIONS:
		var held := Input.is_action_pressed(action)
		if held and not _held_before.get(action, false):
			for pressed: bool in [true, false]:
				var event := InputEventAction.new()
				event.action = action
				event.pressed = pressed
				Input.parse_input_event(event)
		_held_before[action] = held
	Input.flush_buffered_events()


# --- Teleport --------------------------------------------------------------------

func _on_teleport_pressed() -> void:
	teleport_distance.apply()  # Use the number even if Enter was not pressed.
	teleport_distance.get_line_edit().release_focus()
	teleport_requested.emit(teleport_distance.value)


# --- Hitbox drawing --------------------------------------------------------------

func _draw() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		_draw_character(player, COLOR_PLAYER_BODY, COLOR_PLAYER_HITBOX)
		_draw_text_above(player, Player.State.keys()[player.state], COLOR_PLAYER_BODY)

	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		_draw_character(enemy, COLOR_ENEMY_BODY, COLOR_ENEMY_HITBOX)
		var text := "%d hp" % ceili(enemy.health)
		if "state" in enemy:
			text = "%s  %s" % [enemy.State.keys()[enemy.state], text]
		_draw_text_above(enemy, text, COLOR_ENEMY_BODY)

	# Projectiles (always dangerous, so always filled in) and pickups.
	for node in get_tree().get_nodes_in_group("offscreen_cleanup"):
		if node is Projectile:
			_draw_shapes_of(node, COLOR_ENEMY_HITBOX, true)
		elif node is Area2D:
			_draw_shapes_of(node, COLOR_OTHER, false)


## Draws a character's body shape, plus every Area2D attached to it.
func _draw_character(character: CharacterBody2D, body_color: Color, hitbox_color: Color) -> void:
	var active_hitboxes: Array[Area2D] = character.get_active_hitboxes()
	_draw_shapes_of(character, body_color, false)
	for child in character.get_children():
		if child is Area2D:
			var is_hitbox := String(child.name).ends_with("Hitbox")
			_draw_shapes_of(child, hitbox_color if is_hitbox else COLOR_OTHER, child in active_hitboxes)


## Draws the CollisionShape2D nodes directly under `parent`.
func _draw_shapes_of(parent: Node, color: Color, filled: bool) -> void:
	for child in parent.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		# Draw in the shape's own coordinate space, wherever it is in the world.
		draw_set_transform_matrix(global_transform.affine_inverse() * shape_node.global_transform)
		var fill := Color(color, 0.45)
		if shape_node.shape is RectangleShape2D:
			var size: Vector2 = shape_node.shape.size
			var rect := Rect2(-size / 2.0, size)
			if filled:
				draw_rect(rect, fill)
			draw_rect(rect, color, false, 1.0)
		elif shape_node.shape is CircleShape2D:
			var radius: float = shape_node.shape.radius
			if filled:
				draw_circle(Vector2.ZERO, radius, fill)
			draw_circle(Vector2.ZERO, radius, color, false, 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_text_above(character: CharacterBody2D, text: String, color: Color) -> void:
	# Find the top of the character from its body collision shape.
	var top := 0.0
	for child in character.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node and shape_node.shape is RectangleShape2D:
			top = shape_node.position.y - shape_node.shape.size.y / 2.0
	var position_above := to_local(character.global_position) + Vector2(-60.0, top - 16.0)
	draw_string(ThemeDB.fallback_font, position_above, text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 8, color)
