# Sword Scroller (working title)

A small 2D hack-and-slash infinite scroller made with **Godot 4.7.2** and GDScript.

You run to the right through an endless level, fighting enemies with a three-hit
sword combo. The screen only ever scrolls right: anything that leaves the left
edge is gone for good. Every 150 m a boss locks the screen until it is beaten,
and everything gets steadily harder the farther you go.

The game opens on a main menu, which also has a switch for a temporary
**developer debug mode** (see below).

All visuals are coloured-rectangle placeholders, ready to be swapped for pixel art.

## Running it

1. Open Godot 4.7.2, click **Import**, and choose this folder's `project.godot`.
2. Press **F5** (or the Play button, top right).

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | A / D or Left / Right | D-pad or left stick |
| Jump (hold for higher) | Space, W or Up | A (bottom face button) |
| Attack (press repeatedly to combo) | J, X or left mouse button | X (left face button) |
| Dash (hold a direction) | Shift, K or right mouse button | RB or B |
| Pause | Esc or P | Start |

Hold a direction when you press attack to swing that way, even behind you.
Projectiles can be jumped over or cut down with the sword.

The dash goes in the direction you are holding (not the way you are facing),
works on the ground and once per jump in the air, cannot be cancelled, and
does **not** make you invincible. It can interrupt a sword swing.

## Developer debug mode

Switch on **Developer debug mode** on the main menu before pressing Start.

| Feature | How |
| --- | --- |
| Hitboxes | Always drawn. Green = player body, orange = enemy bodies, yellow = your sword, red = enemy attacks, blue = sensors and pickups. A hitbox is an outline normally and is **filled in on the exact frames it can deal damage**. |
| State labels | Each character's current state (and enemy health) is shown above its head. |
| Freeze and frame step | Press **.** (period) or **N** to freeze. Press again to advance one frame; hold it for slow motion. **Esc** resumes. Held movement keys still apply, and a jump, attack or dash pressed while frozen happens on the next step. |
| Teleport | Set **Start at distance** on the menu, or pause (Esc) during a run, type a distance and press **Go**. Difficulty and the boss schedule are set as if you had run there. |

Everything for this mode lives in the `debug/` folder; `debug/debug_mode.gd`
explains how to remove it when it is no longer needed.

To change the bindings: **Project > Project Settings > Input Map**.

## Where everything is

| Path | What it does |
| --- | --- |
| `player/player.gd` | Movement, jumping, the sword combo. **Start here to tune the feel.** |
| `world/main.gd` | Overall game flow: distance, boss fights, game over, restart. |
| `world/game_camera.gd` | The camera that only scrolls right and locks for bosses. |
| `world/difficulty.gd` | **Every difficulty number in one place.** |
| `world/encounter_spawner.gd` | Spawns groups of enemies ahead of the player. |
| `world/level_generator.gd`, `ground_chunk.*` | Builds the endless ground one chunk at a time. |
| `enemies/enemy.gd` | Base class shared by all enemies (health, knockback, death). |
| `enemies/grunt.gd`, `spitter.gd`, `boss.gd` | The AI for each enemy type. |
| `effects/game_feel.gd` | Hitstop and screen shake (autoload named `GameFeel`). |
| `ui/main_menu.*` | The main menu (the scene the game starts on). |
| `ui/hud.*` | Health bars, distance, messages, pause and game over screens. |
| `debug/` | The temporary developer debug mode. |

## Tuning cheat sheet

Most tuning needs no code changes: select the node and edit the values in the
Inspector. Hover over a property name to read what it does.

| I want to change... | Go to |
| --- | --- |
| Run speed, acceleration, how fast you stop or turn | `player/player.tscn` > Player node > **Movement** |
| Jump height, floatiness, coyote time, jump buffer | Player node > **Jump** |
| Dash distance (speed x duration), cooldown, air dashes | Player node > **Dash** |
| Health, attack buffer, combo window, knockback when hit | Player node > **Combat** |
| Speed, damage, reach-in and weight of each sword swing | The `ATTACKS` table at the top of `player/player.gd` |
| The sword's reach | Resize `SwordHitbox` in `player/player.tscn` |
| How strong hitstop and screen shake are | `hitstop` / `shake` in `ATTACKS`, and `effects/game_feel.gd` |
| Where the player sits on screen | `world/main.tscn` > GameCamera > Player Screen Position |
| How fast the game gets harder | `world/difficulty.gd` |
| Distance between bosses | `world/main.tscn` > Main node > Boss Interval M |
| An enemy's health, speed, damage, warning time | Open its scene in `enemies/` and select the root node |

Useful while tuning: the developer debug mode above shows every hitbox and
lets you step through attacks one frame at a time.

If motion looks slightly choppy on a high-refresh-rate monitor, try
**Project Settings > Physics > Common > Physics Interpolation**.

## Collision layers

| Layer | Name | Used by |
| --- | --- | --- |
| 1 | world | Ground |
| 2 | player | The player's body |
| 3 | enemies | Enemy bodies (what the sword looks for) |
| 4 | enemy_projectiles | Spitter projectiles (the sword can destroy these) |
| 5 | pickups | Health pickups |

The player and enemies only collide with the world, not with each other, so
nobody gets stuck on anybody. All damage comes from hitboxes (`Area2D` nodes).

## Replacing the placeholder art

Each character scene has a `Visuals` node holding `Polygon2D` placeholders.
Swap those for a `Sprite2D` or `AnimatedSprite2D` (drawn facing right), then
change that script's `_update_visuals()` function to play animations instead of
changing colours. The collision shapes and hitboxes are separate nodes, so the
gameplay will not change when the art does.

## Saving your work with Git

After making changes you are happy with:

```bash
git add .
```

```bash
git commit -m "Describe what you changed"
```

```bash
git push
```

The `.godot/` folder is Godot's cache and is deliberately not saved to Git
(see `.gitignore`). The `*.uid` and `*.import` files **should** be saved.
