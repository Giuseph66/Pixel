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

## A short bitmap-text callout, e.g. the "+1" a gem leaves behind. Kept
## separate from Particle since it draws through PixelFont, not draw_rect().
class Callout:
	var pos: Vector2
	var text: String
	var life: float
	var max_life: float
	var color: Color

var _particles: Array[Particle] = []
var _popups: Array[Callout] = []


func _process(delta: float) -> void:
	if not _particles.is_empty():
		var alive: Array[Particle] = []
		for p: Particle in _particles:
			p.life -= delta
			if p.life <= 0.0:
				continue
			p.vel.y += p.gravity * delta
			p.pos += p.vel * delta
			alive.append(p)
		_particles = alive

	if not _popups.is_empty():
		var alive_popups: Array[Callout] = []
		for p: Callout in _popups:
			p.life -= delta
			if p.life <= 0.0:
				continue
			p.pos.y -= 22.0 * delta
			alive_popups.append(p)
		_popups = alive_popups

	if not _particles.is_empty() or not _popups.is_empty():
		queue_redraw()


func _draw() -> void:
	for p: Particle in _particles:
		var t := p.life / p.max_life
		var c := p.color
		# Fade by dropping alpha in steps so the pixels never look blurry.
		c.a = 1.0 if t > 0.35 else 0.55
		var s := maxf(1.0, roundf(p.size * (0.6 + 0.4 * t)))
		ci_rect(p.pos, s, c)

	for p: Callout in _popups:
		var t := p.life / p.max_life
		var c := p.color
		c.a = 1.0 if t > 0.3 else 0.5
		PixelFont.draw_text_centered(self, p.text, p.pos.x, roundf(p.pos.y), c, 1)


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


## Small text that drifts up and fades — "+1", "+3", that kind of callout.
func popup(pos: Vector2, text: String, color: Color = Palette.GOLD, life: float = 0.6) -> void:
	var p := Callout.new()
	p.pos = pos + Vector2(0, -6.0)
	p.text = text
	p.max_life = life
	p.life = life
	p.color = color
	_popups.append(p)
	queue_redraw()


func clear() -> void:
	_particles.clear()
	_popups.clear()
	queue_redraw()
