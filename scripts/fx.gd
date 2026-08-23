class_name Fx
extends Node2D

## A tiny particle system. Particles are single pixels drawn with draw_rect(),
## which keeps them on the same grid as everything else — no textures, no
## smooth sub-pixel drift.

const GRAVITY := 340.0

class Particle:
	var pos: Vector2
	var vel: Vector2
	var life: float
	var max_life: float
	var color: Color
	var size: float
	var gravity: float

var _particles: Array[Particle] = []


func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	var alive: Array[Particle] = []
	for p in _particles:
		p.life -= delta
		if p.life <= 0.0:
			continue
		p.vel.y += p.gravity * delta
		p.pos += p.vel * delta
		alive.append(p)
	_particles = alive
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var t := p.life / p.max_life
		var c := p.color
		# Fade by dropping alpha in steps so the pixels never look blurry.
		c.a = 1.0 if t > 0.35 else 0.55
		var s := maxf(1.0, roundf(p.size * (0.6 + 0.4 * t)))
		ci_rect(p.pos, s, c)


func ci_rect(pos: Vector2, s: float, c: Color) -> void:
	draw_rect(Rect2(roundf(pos.x), roundf(pos.y), s, s), c)


func emit(pos: Vector2, count: int, color: Color, speed: float,
		direction: Vector2 = Vector2.ZERO, spread: float = TAU,
		life: float = 0.45, gravity: float = GRAVITY, size: float = 1.0) -> void:
	for i in count:
		var p := Particle.new()
		p.pos = pos
		var angle := randf() * TAU
		if direction != Vector2.ZERO:
			angle = direction.angle() + randf_range(-spread * 0.5, spread * 0.5)
		p.vel = Vector2.RIGHT.rotated(angle) * speed * randf_range(0.45, 1.0)
		p.max_life = life * randf_range(0.7, 1.2)
		p.life = p.max_life
		p.color = color
		p.size = size
		p.gravity = gravity
		_particles.append(p)


## A flat ring of dust, used for landings and squashes.
func dust(pos: Vector2, color: Color = Palette.CYAN_DARK, count: int = 8) -> void:
	for i in count:
		var p := Particle.new()
		p.pos = pos + Vector2(randf_range(-3.0, 3.0), 0.0)
		p.vel = Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, -6.0))
		p.max_life = randf_range(0.18, 0.34)
		p.life = p.max_life
		p.color = color
		p.size = 1.0
		p.gravity = 120.0
		_particles.append(p)


func clear() -> void:
	_particles.clear()
	queue_redraw()
