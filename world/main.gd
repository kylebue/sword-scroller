extends Node2D
## The main game scene. It ties the other pieces together and owns the
## overall flow of a run:
##
##   run right -> fight enemies -> reach the boss distance -> camera locks ->
##   beat the boss -> camera unlocks -> repeat, a little harder each time.

@export var boss_scene: PackedScene
## Distance between boss fights, in metres.
@export var boss_interval_m := 150.0

const FLOOR_Y := 300.0
const MAIN_MENU_SCENE := "res://ui/main_menu.tscn"
const DEBUG_TOOLS_SCENE := preload("res://debug/debug_tools.tscn")
## Things are deleted once they are this far off the left of the screen.
const CLEANUP_MARGIN := 48.0

## `static` means this survives restarting the scene, so the best distance
## is remembered until the game is closed.
static var best_distance_m := 0.0

var distance_m := 0.0
var bosses_defeated := 0
var boss_active := false
var is_game_over := false

var _next_boss_m := 0.0
var _can_restart := false

@onready var player: Player = $Player
@onready var camera: GameCamera = $GameCamera
@onready var entities: Node2D = %Entities
@onready var level: LevelGenerator = $Level
@onready var spawner: EncounterSpawner = $EncounterSpawner
@onready var hud: HUD = $HUD


func _ready() -> void:
	GameFeel.reset()
	_next_boss_m = boss_interval_m
	player.health_changed.connect(hud.set_player_health)
	player.died.connect(_on_player_died)
	hud.set_player_health(player.health, player.max_health)
	if DebugMode.enabled:
		var debug_tools := DEBUG_TOOLS_SCENE.instantiate()
		debug_tools.teleport_requested.connect(teleport_to)
		add_child(debug_tools)
		if DebugMode.start_distance_m > 0.0:
			teleport_to(DebugMode.start_distance_m)


func _physics_process(_delta: float) -> void:
	# The player starts at x = 0, so distance is simply how far right they
	# have ever been.
	distance_m = maxf(distance_m, player.global_position.x / Difficulty.PIXELS_PER_METER)
	hud.set_distance(distance_m)
	if not boss_active and not is_game_over and distance_m >= _next_boss_m:
		_start_boss_fight()
	_remove_things_left_behind()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_restart:
		return
	if event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Debug helper: jumps the run to `target_m` metres, set up as if the player
## had got there normally (same difficulty, same number of bosses beaten).
func teleport_to(target_m: float) -> void:
	# Clear out everything that is currently alive, including a boss.
	for group in ["enemies", "offscreen_cleanup"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	boss_active = false
	camera.locked = false
	hud.hide_boss()

	player.global_position = Vector2(target_m * Difficulty.PIXELS_PER_METER, FLOOR_Y)
	player.velocity = Vector2.ZERO
	camera.snap_to_target()
	level.update_chunks()  # Make sure there is ground at the new position.

	distance_m = target_m
	hud.set_distance(distance_m)
	# The next boss is at the next multiple of the boss interval.
	bosses_defeated = maxi(ceili(target_m / boss_interval_m) - 1, 0)
	_next_boss_m = (bosses_defeated + 1) * boss_interval_m
	spawner.enabled = not is_game_over
	spawner.skip_ahead(100.0)


func _start_boss_fight() -> void:
	boss_active = true
	camera.locked = true  # The screen becomes the arena.
	spawner.enabled = false
	var boss := boss_scene.instantiate() as Boss
	boss.setup(bosses_defeated + 1)
	boss.position = Vector2(camera.right_edge() + 50.0, FLOOR_Y)
	boss.died.connect(_on_boss_died)
	entities.add_child(boss)
	hud.show_boss(boss)
	hud.show_message("BOSS!")


func _on_boss_died(_boss: Enemy) -> void:
	bosses_defeated += 1
	boss_active = false
	camera.locked = false
	spawner.enabled = true
	spawner.skip_ahead(250.0)  # A short breather before more enemies arrive.
	_next_boss_m = distance_m + boss_interval_m
	GameFeel.hitstop(0.25)
	GameFeel.shake(10.0)
	hud.hide_boss()
	hud.show_message("GO  >>")


func _on_player_died() -> void:
	is_game_over = true
	spawner.enabled = false
	best_distance_m = maxf(best_distance_m, distance_m)
	# A short pause before the game over screen, so the death can be seen and
	# a mashed attack button does not instantly restart the game.
	await get_tree().create_timer(0.8).timeout
	hud.show_game_over(distance_m, best_distance_m)
	_can_restart = true


## The rule of the game: once something scrolls off the left side of the
## screen it is gone for good. Anything in the "offscreen_cleanup" group
## (enemies, projectiles, pickups) is deleted when that happens.
func _remove_things_left_behind() -> void:
	var limit := camera.left_edge() - CLEANUP_MARGIN
	for node: Node2D in get_tree().get_nodes_in_group("offscreen_cleanup"):
		if node.global_position.x < limit:
			node.queue_free()
