class_name DebugMode
extends RefCounted
## Settings for the temporary developer debug mode, chosen on the main menu.
##
## These are `static`, so they keep their values when the scene changes from
## the menu to the game. Read them anywhere with DebugMode.enabled.
##
## To remove debug mode from the game later: delete the `debug` folder, the
## debug options on the main menu, and the few lines in world/main.gd that
## mention DebugMode.

static var enabled := false
## Where a run starts (in metres) when debug mode is on.
static var start_distance_m := 0.0
