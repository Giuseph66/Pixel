class_name Sfx
extends RefCounted

## Runtime chiptune synth. Every sound effect and the music loop are written
## sample by sample into an AudioStreamWAV, so the project ships with no audio
## files at all.

const RATE := 22050

enum Wave { SQUARE, PULSE, TRIANGLE, SAW, NOISE }


# ------------------------------------------------------------- synthesis ---

## Render one note into a float buffer.
## `sweep` bends the pitch over the note's life (1.0 = no bend, 2.0 = up an octave).
static func tone(freq: float, dur: float, wave: int = Wave.SQUARE, vol: float = 0.5,
		sweep: float = 1.0, attack: float = 0.005, release: float = 0.06) -> PackedFloat32Array:
	var count := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in count:
		var t := float(i) / RATE
		var progress := float(i) / maxf(1.0, float(count))
		var f := freq * lerpf(1.0, sweep, progress)
		phase += f / RATE
		phase = fposmod(phase, 1.0)

		var s := 0.0
		match wave:
			Wave.SQUARE:
				s = 1.0 if phase < 0.5 else -1.0
			Wave.PULSE:
				s = 1.0 if phase < 0.25 else -1.0
			Wave.TRIANGLE:
				s = 4.0 * absf(phase - 0.5) - 1.0
			Wave.SAW:
				s = phase * 2.0 - 1.0
			Wave.NOISE:
				s = rng.randf_range(-1.0, 1.0)

		var env := 1.0
		if t < attack:
			env = t / maxf(attack, 0.0001)
		var left := dur - t
		if left < release:
			env = minf(env, left / maxf(release, 0.0001))
		out[i] = s * vol * maxf(env, 0.0)
	return out


static func silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


static func concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


## Add `src` into `dst` starting at `offset` samples, growing `dst` if needed.
## Packed arrays are copy-on-write, so the mixed buffer is returned rather than
## modified in place — the caller has to take it back.
static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int) -> PackedFloat32Array:
	var need := offset + src.size()
	if dst.size() < need:
		dst.resize(need)
	for i in src.size():
		dst[offset + i] = dst[offset + i] + src[i]
	return dst


static func to_stream(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


static func note_freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# ----------------------------------------------------------------- sounds ---

static func library() -> Dictionary:
	return {
		"jump": to_stream(tone(330.0, 0.14, Wave.SQUARE, 0.35, 1.9, 0.002, 0.05)),
		"wall_jump": to_stream(tone(260.0, 0.13, Wave.PULSE, 0.32, 2.1, 0.002, 0.05)),
		"land": to_stream(concat([
			tone(180.0, 0.05, Wave.NOISE, 0.16, 1.0, 0.001, 0.04),
			tone(110.0, 0.05, Wave.TRIANGLE, 0.22, 0.6, 0.001, 0.04),
		])),
		"gem": to_stream(concat([
			tone(note_freq(88), 0.05, Wave.SQUARE, 0.26, 1.0, 0.001, 0.02),
			tone(note_freq(93), 0.10, Wave.SQUARE, 0.26, 1.0, 0.001, 0.06),
		])),
		"stomp": to_stream(concat([
			tone(520.0, 0.05, Wave.PULSE, 0.3, 0.4, 0.001, 0.02),
			tone(160.0, 0.09, Wave.NOISE, 0.2, 1.0, 0.001, 0.06),
		])),
		"spring": to_stream(tone(200.0, 0.22, Wave.TRIANGLE, 0.4, 3.4, 0.002, 0.08)),
		# A downward sweep with noise under it: air being cut, not a jump.
		"dash": to_stream(concat([
			tone(880.0, 0.06, Wave.PULSE, 0.26, 0.35, 0.001, 0.02),
			tone(300.0, 0.07, Wave.NOISE, 0.14, 1.0, 0.001, 0.05),
		])),
		# Wind-up whine, then the hit is the existing stomp.
		"pound": to_stream(tone(220.0, 0.10, Wave.PULSE, 0.22, 2.6, 0.002, 0.03)),
		"break": to_stream(concat([
			tone(320.0, 0.05, Wave.NOISE, 0.26, 1.0, 0.001, 0.02),
			tone(140.0, 0.09, Wave.SQUARE, 0.2, 0.5, 0.001, 0.05),
		])),
		"crystal": to_stream(concat([
			tone(note_freq(84), 0.04, Wave.TRIANGLE, 0.24, 1.0, 0.001, 0.02),
			tone(note_freq(91), 0.11, Wave.TRIANGLE, 0.24, 1.0, 0.001, 0.06),
		])),
		"death": to_stream(concat([
			tone(400.0, 0.08, Wave.SAW, 0.3, 0.5, 0.001, 0.02),
			tone(200.0, 0.10, Wave.SAW, 0.3, 0.5, 0.001, 0.03),
			tone(100.0, 0.22, Wave.SAW, 0.3, 0.4, 0.001, 0.12),
		])),
		# A dry mechanical click, up then down: a switch does not care which way
		# it just flipped, so one sound serves both directions.
		"switch": to_stream(concat([
			tone(520.0, 0.03, Wave.PULSE, 0.22, 1.0, 0.001, 0.015),
			tone(340.0, 0.05, Wave.PULSE, 0.2, 1.0, 0.001, 0.03),
		])),
		"door": to_stream(concat([
			tone(note_freq(69), 0.09, Wave.SQUARE, 0.24, 1.0, 0.002, 0.03),
			tone(note_freq(76), 0.09, Wave.SQUARE, 0.24, 1.0, 0.002, 0.03),
			tone(note_freq(81), 0.26, Wave.SQUARE, 0.26, 1.0, 0.002, 0.14),
		])),
		"menu_move": to_stream(tone(700.0, 0.04, Wave.PULSE, 0.18, 1.0, 0.001, 0.02)),
		"menu_select": to_stream(concat([
			tone(note_freq(72), 0.05, Wave.PULSE, 0.22, 1.0, 0.001, 0.02),
			tone(note_freq(79), 0.12, Wave.PULSE, 0.22, 1.0, 0.001, 0.07),
		])),
		"menu_back": to_stream(concat([
			tone(note_freq(72), 0.05, Wave.PULSE, 0.2, 1.0, 0.001, 0.02),
			tone(note_freq(65), 0.11, Wave.PULSE, 0.2, 1.0, 0.001, 0.07),
		])),
		"complete": to_stream(concat([
			tone(note_freq(69), 0.10, Wave.SQUARE, 0.26, 1.0, 0.002, 0.03),
			tone(note_freq(73), 0.10, Wave.SQUARE, 0.26, 1.0, 0.002, 0.03),
			tone(note_freq(76), 0.10, Wave.SQUARE, 0.26, 1.0, 0.002, 0.03),
			tone(note_freq(81), 0.40, Wave.SQUARE, 0.30, 1.0, 0.002, 0.25),
		])),
	}


# ------------------------------------------------------------------ music ---

const BPM := 132.0

## Four-bar loop in A minor: triangle bass, square arpeggio, noise hat.
## Kept short on purpose — every sample is computed in GDScript at boot.
static func music() -> AudioStreamWAV:
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var bars := 4
	var total := int(bar * bars * RATE) + RATE / 2
	var buf := PackedFloat32Array()
	buf.resize(total)

	# Root note of each bar: Am F C G.
	var roots := [57, 53, 48, 55]
	# Chord shapes relative to the root, used for the arpeggio.
	var shapes := [[0, 3, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12]]

	for b in bars:
		var bar_start := bar * b
		var root: int = roots[b]
		var shape: Array = shapes[b % shapes.size()]

		# Bass: root on every beat, octave down, with a lift on beat 4.
		for beat_index in 4:
			var midi := root - 12 + (7 if beat_index == 3 else 0)
			var at := int((bar_start + beat * beat_index) * RATE)
			buf = mix_into(buf, tone(note_freq(midi), beat * 0.55, Wave.TRIANGLE, 0.24,
				1.0, 0.004, 0.05), at)

		# Lead: sixteenth-note arpeggio climbing through the chord.
		for step in 16:
			var degree: int = shape[step % shape.size()]
			var octave := 12 if step >= 8 else 0
			var midi := root + degree + octave
			var at := int((bar_start + beat * 0.25 * step) * RATE)
			var wave := Wave.PULSE if step % 4 == 0 else Wave.SQUARE
			buf = mix_into(buf, tone(note_freq(midi), beat * 0.22, wave, 0.11,
				1.0, 0.002, 0.03), at)

		# Hat: quiet noise blip on every offbeat eighth.
		for step in 8:
			if step % 2 == 0:
				continue
			var at := int((bar_start + beat * 0.5 * step) * RATE)
			buf = mix_into(buf, tone(4000.0, 0.03, Wave.NOISE, 0.05, 1.0, 0.001, 0.02), at)

	# Trim any tail past the loop point so the seam is clean.
	buf.resize(int(bar * bars * RATE))
	return to_stream(buf, true)
