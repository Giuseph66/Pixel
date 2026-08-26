class_name Darkness
extends Node2D

## Step 20 — the 'dark' endless modifier. The project has no shader anywhere;
## everything is draw_rect() and a baked Image (see level.gd's _bake_*
## functions), so the vision limit is four plain rectangles covering
## everything except a square window around the player. A hard edge matches
## that pixel aesthetic better than a soft vignette would need a shader for.
##
## Added as a child of Level, after terrain and entities, so it draws over
## both. Level itself is added to main before Hud, which keeps Hud on top of
## this regardless — the one thing this modifier must never darken.

const RADIUS := 46.0
const SCREEN := Vector2(480, 270)

var player: Player
## Positions worth showing through the dark anyway. Gems and crystals glow so
## the modifier changes navigation, not collection — without this, a gem five
## tiles out is not "harder to see", it is invisible, and finding it is luck.
var glow_provider: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var p := player.global_position - global_position
	var r := RADIUS
	draw_rect(Rect2(0.0, 0.0, SCREEN.x, p.y - r), Palette.OUTLINE)
	draw_rect(Rect2(0.0, p.y + r, SCREEN.x, SCREEN.y), Palette.OUTLINE)
	draw_rect(Rect2(0.0, p.y - r, p.x - r, r * 2.0), Palette.OUTLINE)
	draw_rect(Rect2(p.x + r, p.y - r, SCREEN.x, r * 2.0), Palette.OUTLINE)

	if glow_provider.is_valid():
		for pos: Vector2 in glow_provider.call():
			draw_rect(Rect2(pos.x - 1.0, pos.y - 1.0, 2.0, 2.0), Palette.GOLD)
