class_name Difficulty
extends RefCounted
## Every difficulty number in the game comes from here, so this is the one
## file to edit when balancing.
##
## The idea: distance travelled is turned into a single "level" number that
## rises in a straight line forever (level 1.0 at 100 m, 2.0 at 200 m...).
## Each stat is then a straight-line function of that level. Stats that
## would become unfair if they grew forever (speed, reaction time) are capped
## with min()/max(); enemy health and damage keep growing.
##
## All functions are static, so call them like: Difficulty.level_at(120.0)

const PIXELS_PER_METER := 32.0
## Distance needed for the level to rise by 1.0.
const METERS_PER_LEVEL := 100.0


static func level_at(distance_m: float) -> float:
	return maxf(distance_m, 0.0) / METERS_PER_LEVEL


# --- Regular enemies ---------------------------------------------------------

static func enemy_health_multiplier(level: float) -> float:
	return 1.0 + 0.25 * level


static func enemy_damage_multiplier(level: float) -> float:
	return 1.0 + 0.12 * level


static func enemy_speed_multiplier(level: float) -> float:
	return minf(1.0 + 0.05 * level, 1.6)


## Multiplier on how long enemies telegraph (wind up) before attacking.
## Lower = less time for the player to react.
static func telegraph_multiplier(level: float) -> float:
	return maxf(1.0 - 0.04 * level, 0.55)


# --- Encounters (groups of enemies) ------------------------------------------

## Pixels of scrolling between one group of enemies and the next.
static func encounter_spacing(level: float) -> float:
	return maxf(420.0 - 20.0 * level, 200.0)


## How many enemies arrive together. The randf() makes it vary by one.
static func encounter_size(level: float) -> int:
	return mini(1 + int(level * 0.6 + randf()), 5)


## Chance (0 to 1) that an enemy is a ranged Spitter instead of a Grunt.
static func ranged_chance(level: float) -> float:
	if level < 0.4:
		return 0.0
	return minf(0.1 + 0.06 * level, 0.45)


## No new group spawns while this many enemies are already alive.
static func max_enemies_alive(level: float) -> int:
	return mini(3 + int(level), 8)


# --- Bosses ------------------------------------------------------------------
# `boss_number` is 1 for the first boss, 2 for the second, and so on.

static func boss_health_multiplier(boss_number: int) -> float:
	return 1.0 + 0.5 * (boss_number - 1)


static func boss_damage_multiplier(boss_number: int) -> float:
	return 1.0 + 0.15 * (boss_number - 1)


static func boss_speed_multiplier(boss_number: int) -> float:
	return minf(1.0 + 0.08 * (boss_number - 1), 1.5)


static func boss_telegraph_multiplier(boss_number: int) -> float:
	return maxf(1.0 - 0.07 * (boss_number - 1), 0.55)
