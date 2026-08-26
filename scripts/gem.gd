class_name Gem
extends Area2D

signal collected(gem: Gem, player: Player)

var secret := false           # true for hidden gems that don't count toward door
var _time := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_time = randf() * TAU

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("gem_secret" if secret else "gem")
	add_child(_sprite)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	# Snap the bob to whole pixels — a smooth float here would shimmer.
	_sprite.position.y = roundf(sin(_time * 3.0) * 1.5)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collected.emit(self, body as Player)
