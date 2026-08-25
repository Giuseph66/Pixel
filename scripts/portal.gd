class_name Portal
extends Area2D

## Two tiles, linked by Level once both exist. Entering one exits the other
## with speed kept and heading replaced by whichever way the exit faces —
## that substitution is the whole trick: a fall in becomes a launch out
## wherever the exit happens to be aimed.

const COOLDOWN := 0.18          # per portal, so a body cannot re-enter what it
                                 # just left before it has cleared the tile

var twin: Portal
var facing := Vector2.RIGHT
var _cool := 0.0


func setup(dir: Vector2) -> void:
	facing = dir.normalized()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var sprite := Sprite2D.new()
	sprite.texture = PixelArt.tex("portal_a")
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(7, 7)
	shape.shape = rect
	add_child(shape)


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _cool > 0.0 or twin == null:
		return

	for body in get_overlapping_bodies():
		if not (body is Player):
			continue
		var player := body as Player
		if not player.alive:
			continue

		var speed := player.velocity.length()
		player.global_position = twin.global_position + twin.facing * 8.0
		player.redirect(twin.facing * speed)
		player.cancel_pound()

		# The cooldown belongs to the destination, not the source — locking
		# only the entrance leaves the exit free to fire the player straight
		# back in on the very next physics step.
		twin._cool = COOLDOWN
		_cool = COOLDOWN
		Audio.play("portal")
