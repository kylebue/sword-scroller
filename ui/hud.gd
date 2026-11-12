class_name HUD
extends CanvasLayer
## Everything drawn on top of the game: health, distance, the boss health
## bar, messages, the pause text and the game over screen.
##
## The HUD's Process Mode is set to "Always" in the scene so that it can
## still react to the pause button while the rest of the game is paused.

const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"

@onready var health_bar: ProgressBar = %HealthBar
@onready var distance_label: Label = %DistanceLabel
@onready var boss_panel: Control = %BossPanel
@onready var boss_bar: ProgressBar = %BossBar
@onready var message_label: Label = %MessageLabel
@onready var hint_label: Label = %HintLabel
@onready var pause_menu: Control = %PauseMenu
@onready var resume_button: Button = %ResumeButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var game_over_panel: Control = %GameOverPanel
@onready var game_over_label: Label = %GameOverLabel

var _message_tween: Tween


func _ready() -> void:
	# Show the controls for a few seconds, then fade them out.
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)
	resume_button.pressed.connect(set_paused.bind(false))
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not game_over_panel.visible:
		set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_menu.visible = paused
	if paused:
		# Give a button keyboard/gamepad focus so the menu can be used
		# without a mouse.
		resume_button.grab_focus()


func set_player_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func set_distance(distance_m: float) -> void:
	distance_label.text = "%d m" % int(distance_m)


func show_boss(boss: Enemy) -> void:
	boss_bar.max_value = boss.max_health
	boss_bar.value = boss.health
	boss.health_changed.connect(_on_boss_health_changed)
	boss_panel.visible = true


func hide_boss() -> void:
	boss_panel.visible = false


## Shows a large message in the middle of the screen for a moment.
func show_message(text: String, duration := 1.5) -> void:
	if _message_tween:
		_message_tween.kill()
	message_label.text = text
	message_label.modulate.a = 1.0
	message_label.visible = true
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)


func show_game_over(distance_m: float, best_distance_m: float) -> void:
	game_over_label.text = "YOU DIED\n\nDistance: %d m\nBest: %d m\n\nATTACK or JUMP: try again\nPAUSE (Esc): main menu" % [
		int(distance_m), int(best_distance_m),
	]
	game_over_panel.visible = true


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_boss_health_changed(current: float, _maximum: float) -> void:
	boss_bar.value = current
