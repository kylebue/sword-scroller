extends Control
## The main menu: start the game, switch developer debug mode on or off,
## and (in debug mode) choose the distance to start at.

const GAME_SCENE := "res://world/main.tscn"

@onready var start_button: Button = %StartButton
@onready var debug_toggle: CheckButton = %DebugToggle
@onready var debug_options: Control = %DebugOptions
@onready var start_distance: SpinBox = %StartDistance
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	# Coming back from a run: make sure nothing is left paused or frozen.
	get_tree().paused = false
	GameFeel.reset()

	# Remember the debug choices from last time.
	debug_toggle.button_pressed = DebugMode.enabled
	debug_options.visible = DebugMode.enabled
	start_distance.value = DebugMode.start_distance_m

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(get_tree().quit)
	debug_toggle.toggled.connect(_on_debug_toggled)
	# Focus a button so the menu works with keyboard and gamepad.
	start_button.grab_focus()
	for button: BaseButton in [start_button, quit_button, debug_toggle]:
		button.focus_entered.connect(Sfx.play.bind(&"ui_move"))
		button.pressed.connect(Sfx.play.bind(&"ui_select"))


func _on_debug_toggled(enabled: bool) -> void:
	debug_options.visible = enabled


func _on_start_pressed() -> void:
	start_distance.apply()  # Use the number even if Enter was not pressed.
	DebugMode.enabled = debug_toggle.button_pressed
	DebugMode.start_distance_m = start_distance.value
	get_tree().change_scene_to_file(GAME_SCENE)
