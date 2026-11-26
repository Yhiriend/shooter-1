class_name Sfx
extends Node
## Sonido básico del juego, sintetizado al arrancar (no hay archivos de audio todavía).
## Efectos en el mundo con `Sfx.at(nombre, posición)`; de interfaz con `Sfx.ui(nombre)`.
## Para cambiar un sonido, editar su receta en `_build_sounds`. Ver docs/GDD.md, «Dirección de arte y audio».

const RATE := 22050
const POOL_3D := 20
const POOL_2D := 6
## Volumen de la música ambiental (dB).
const MUSIC_DB := -17.0

## Sonido de cada habilidad al lanzarse, por efecto.
const ABILITY_SOUNDS := {
	AbilityData.Effect.YARN_REVEAL: "throw",
	AbilityData.Effect.BELL_FLASH: "throw",
	AbilityData.Effect.DASH: "dash",
	AbilityData.Effect.NIGHT_EYES: "ult",
	AbilityData.Effect.DECOY: "place",
	AbilityData.Effect.GROUND_SLAM: "slam",
	AbilityData.Effect.BURROW: "dig",
	AbilityData.Effect.BIG_LEAP: "leap",
	AbilityData.Effect.BAMBOO_WALL: "wall",
	AbilityData.Effect.HONEY_POOL: "honey",
	AbilityData.Effect.SMOKE: "smoke",
	AbilityData.Effect.BIG_SMOKE: "smoke",
	AbilityData.Effect.ORANGE_TRAP: "place",
	AbilityData.Effect.HOT_SPRING: "chime",
	AbilityData.Effect.WATCHER: "place",
	AbilityData.Effect.TOTAL_CALM: "chime",
}

static var current: Sfx

var _streams := {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_2d := 0
var _listener: AudioListener3D
var _music: AudioStreamPlayer
## Lo llena el hilo de síntesis; se pasa a `_streams` en el hilo principal.
var _built := {}
var _task := -1


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 9.0
		p.max_distance = 40.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.6
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool_2d.append(p)
	# El oído va en el punto del suelo que mira la cámara (no a 18 m de altura).
	_listener = AudioListener3D.new()
	add_child(_listener)
	_listener.make_current()
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	# Sintetizar lleva un momento (más en el móvil): se hace en otro hilo para no frenar el arranque.
	_task = WorkerThreadPool.add_task(func() -> void:
		_build_sounds()
		_built["music"] = _build_music()
		_on_built.call_deferred())


func _on_built() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for key: String in _built:
		_streams[key] = _make_stream(_built[key])
	_built.clear()
	_music.stream = _streams["music"]
	# Bucle a mano: el bucle interno de AudioStreamWAV hecho por código cerraba el juego en Android
	# al volver al inicio (lee más allá del final del búfer).
	_music.finished.connect(_music.play)
	_music.play()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var forward := -cam.global_basis.z
	var origin := cam.global_position
	if absf(forward.y) > 0.01:
		origin += forward * (-origin.y / forward.y)
	var yaw := Vector3(forward.x, 0.0, forward.z)
	if yaw.length_squared() < 0.001:
		yaw = Vector3.FORWARD
	_listener.global_transform = Transform3D(Basis.looking_at(yaw.normalized(), Vector3.UP), origin + Vector3.UP)


## Sonido en el mundo (se oye más fuerte cerca y hacia su lado).
static func at(sound: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	if current == null or not current._streams.has(sound):
		return
	var p := current._pool_3d[current._next_3d]
	current._next_3d = (current._next_3d + 1) % POOL_3D
	p.stream = current._streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.global_position = pos
	p.play()


## Sonido de interfaz o aviso de partida (igual de fuerte en todas partes).
static func ui(sound: String, volume_db := 0.0) -> void:
	if current == null or not current._streams.has(sound):
		return
	var p := current._pool_2d[current._next_2d]
	current._next_2d = (current._next_2d + 1) % POOL_2D
	p.stream = current._streams[sound]
	p.volume_db = volume_db
	p.play()


static func ability(effect: AbilityData.Effect, is_ult: bool, pos: Vector3) -> void:
	at(ABILITY_SOUNDS.get(effect, "throw"), pos)
	if is_ult:
		at("ult", pos, 2.0, 0.0)


# --- Recetas ---

func _build_sounds() -> void:
	var b: PackedFloat32Array

	# Armas: pistola de burbujas (pop), escopeta de confeti (ráfaga), rifle de semillas (zumbido).
	b = _buf(0.12)
	_tone(b, 0.0, 0.1, 950.0, 280.0, 0.55, "sine", 0.002, 2.0)
	_noise(b, 0.0, 0.02, 0.25, 0.5, 2.0)
	_built["pistol"] = _wav(b)

	b = _buf(0.3)
	_noise(b, 0.0, 0.26, 0.6, 0.25, 2.5)
	_tone(b, 0.0, 0.18, 170.0, 55.0, 0.6, "sine", 0.002, 2.0)
	for i in 5:
		_tone(b, 0.03 + i * 0.03, 0.04, randf_range(1500.0, 2600.0), 1200.0, 0.12, "sine", 0.002, 1.5)
	_built["shotgun"] = _wav(b)

	b = _buf(0.22)
	_noise(b, 0.0, 0.015, 0.4, 0.7, 2.0)
	_tone(b, 0.0, 0.2, 1500.0, 180.0, 0.5, "tri", 0.002, 1.6)
	_built["rifle"] = _wav(b)

	b = _buf(0.22)
	_noise(b, 0.0, 0.012, 0.4, 0.6, 1.0)
	_noise(b, 0.14, 0.015, 0.45, 0.6, 1.0)
	_tone(b, 0.14, 0.06, 700.0, 900.0, 0.15, "square", 0.002, 2.0)
	_built["reload"] = _wav(b)

	# Impactos y caídas.
	b = _buf(0.1)
	_tone(b, 0.0, 0.09, 260.0, 150.0, 0.6, "tri", 0.002, 1.5)
	_noise(b, 0.0, 0.03, 0.2, 0.3, 2.0)
	_built["hit"] = _wav(b)

	b = _buf(0.05)
	_tone(b, 0.0, 0.045, 1700.0, 1700.0, 0.35, "sine", 0.001, 2.0)
	_built["hit_confirm"] = _wav(b)

	b = _buf(0.6)
	_tone(b, 0.0, 0.55, 700.0, 110.0, 0.5, "tri", 0.01, 1.2)
	_noise(b, 0.0, 0.35, 0.25, 0.12, 2.0)
	_built["death"] = _wav(b)

	b = _buf(0.05)
	_noise(b, 0.0, 0.045, 0.5, 0.08, 2.0)
	_built["step"] = _wav(b)

	# Habilidades.
	b = _buf(0.3)
	_noise(b, 0.0, 0.28, 0.4, 0.18, 1.0, 0.12)
	_built["throw"] = _wav(b)

	b = _buf(0.22)
	_noise(b, 0.0, 0.2, 0.45, 0.3, 1.2, 0.03)
	_tone(b, 0.0, 0.18, 300.0, 900.0, 0.15, "sine", 0.01, 1.0)
	_built["dash"] = _wav(b)

	b = _buf(0.45)
	_noise(b, 0.0, 0.4, 0.4, 0.2, 1.0, 0.05)
	_tone(b, 0.0, 0.4, 200.0, 600.0, 0.2, "sine", 0.02, 1.0)
	_built["leap"] = _wav(b)

	b = _buf(0.45)
	_tone(b, 0.0, 0.4, 110.0, 38.0, 0.8, "sine", 0.002, 1.5)
	_noise(b, 0.0, 0.3, 0.4, 0.1, 2.0)
	_built["slam"] = _wav(b)

	b = _buf(0.6)
	_noise(b, 0.0, 0.55, 0.6, 0.05, 1.0, 0.05)
	_built["dig"] = _wav(b)

	b = _buf(0.35)
	for i in 3:
		_tone(b, i * 0.09, 0.12, 190.0, 170.0, 0.45, "tri", 0.001, 3.0)
		_tone(b, i * 0.09, 0.08, 380.0, 340.0, 0.2, "sine", 0.001, 3.0)
	_built["wall"] = _wav(b)

	b = _buf(0.35)
	_tone(b, 0.0, 0.15, 180.0, 380.0, 0.4, "sine", 0.01, 1.0)
	_tone(b, 0.16, 0.15, 220.0, 420.0, 0.35, "sine", 0.01, 1.0)
	_built["honey"] = _wav(b)

	b = _buf(0.8)
	_noise(b, 0.0, 0.75, 0.5, 0.06, 1.2, 0.08)
	_built["smoke"] = _wav(b)

	b = _buf(0.15)
	_noise(b, 0.0, 0.02, 0.4, 0.5, 2.0)
	_tone(b, 0.0, 0.12, 520.0, 660.0, 0.3, "sine", 0.002, 2.0)
	_built["place"] = _wav(b)

	b = _buf(0.9)
	for f in [1320.0, 1980.0, 2640.0, 3300.0]:
		_tone(b, 0.0, 0.85, f, f, 0.18, "sine", 0.001, 2.5)
	_built["bell"] = _wav(b)

	b = _buf(0.2)
	_noise(b, 0.0, 0.02, 0.6, 0.6, 2.0)
	_tone(b, 0.0, 0.15, 320.0, 90.0, 0.4, "square", 0.001, 2.0)
	_built["trap"] = _wav(b)

	b = _buf(0.6)
	_arpeggio(b, [523.25, 659.25, 783.99], 0.08, 0.35, 0.3)
	_built["chime"] = _wav(b)

	b = _buf(1.0)
	_arpeggio(b, [392.0, 523.25, 659.25, 783.99, 1046.5], 0.07, 0.6, 0.28)
	_noise(b, 0.0, 0.9, 0.06, 0.9, 1.0, 0.3)
	_built["ult"] = _wav(b)

	# Objetivo y partida.
	b = _buf(0.3)
	_arpeggio(b, [659.25, 987.77], 0.08, 0.2, 0.3)
	_built["seed_pick"] = _wav(b)

	b = _buf(0.5)
	_arpeggio(b, [1046.5, 1318.5, 1568.0, 2093.0], 0.05, 0.3, 0.2)
	_built["clover"] = _wav(b)

	b = _buf(1.2)
	_arpeggio(b, [523.25, 783.99, 1046.5, 1318.5], 0.12, 0.8, 0.3)
	_built["plant"] = _wav(b)

	b = _buf(0.8)
	_arpeggio(b, [783.99, 659.25, 523.25, 392.0], 0.1, 0.35, 0.3)
	_built["uproot"] = _wav(b)

	b = _buf(0.5)
	_tone(b, 0.0, 0.18, 587.33, 587.33, 0.3, "tri", 0.005, 1.5)
	_tone(b, 0.2, 0.28, 880.0, 880.0, 0.3, "tri", 0.005, 1.5)
	_built["round_start"] = _wav(b)

	b = _buf(1.1)
	_arpeggio(b, [523.25, 659.25, 783.99, 1046.5], 0.13, 0.6, 0.3, "tri")
	_built["win"] = _wav(b)

	b = _buf(1.1)
	_arpeggio(b, [392.0, 311.13, 261.63], 0.18, 0.6, 0.3, "tri")
	_built["lose"] = _wav(b)

	b = _buf(0.04)
	_tone(b, 0.0, 0.035, 1100.0, 900.0, 0.3, "sine", 0.001, 2.0)
	_built["click"] = _wav(b)


## Música ambiental en bucle: acordes suaves (Do maj7 → La m7 → Fa maj7 → Sol), 12 s.
func _build_music() -> PackedByteArray:
	var chord_time := 3.0
	var chords := [
		[130.81, 196.0, 246.94, 329.63],
		[110.0, 164.81, 196.0, 261.63],
		[87.31, 174.61, 220.0, 329.63],
		[98.0, 146.83, 196.0, 293.66],
	]
	var b := _buf(chord_time * chords.size())
	for i in chords.size():
		for f: float in chords[i]:
			# Cada acorde entra y sale suave y se solapa un poco con el siguiente: el bucle no salta.
			_pad(b, i * chord_time, chord_time, f, 0.07)
		# Una notita de "campanita" por acorde, para que no sea un zumbido.
		var top: float = chords[i][3] * 2.0
		_tone(b, i * chord_time + 1.0, 1.6, top, top, 0.05, "sine", 0.01, 2.0)
	return _wav(b)


# --- Síntesis ---

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Tono con barrido de frecuencia (exponencial) y envolvente: subida `attack` y caída (1-u)^decay.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float,
		wave := "sine", attack := 0.005, decay := 1.0) -> void:
	var i0 := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - i0)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / n
		var f := f0 * pow(f1 / f0, u)
		phase += TAU * f / RATE
		var s := sin(phase)
		match wave:
			"square":
				s = 0.6 if s >= 0.0 else -0.6
			"tri":
				s = asin(s) * 0.6366
		var env := minf(t / maxf(attack, 0.0001), 1.0) * pow(1.0 - u, decay)
		b[i0 + i] += s * amp * env


## Ruido filtrado (pasa bajos de un polo; `cutoff` 0–1). `swell` > 0 hace que suba y baje (soplido).
func _noise(b: PackedFloat32Array, start: float, dur: float, amp: float, cutoff: float,
		decay := 1.0, swell := 0.0) -> void:
	var i0 := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - i0)
	var y := 0.0
	for i in n:
		var u := float(i) / n
		y += cutoff * (randf_range(-1.0, 1.0) - y)
		var env := pow(1.0 - u, decay)
		if swell > 0.0:
			env = sin(u * PI) * pow(1.0 - u * 0.5, decay)
		else:
			env *= minf(float(i) / (0.002 * RATE), 1.0)
		b[i0 + i] += y * amp * env * (1.0 + cutoff)


func _arpeggio(b: PackedFloat32Array, notes: Array, step: float, note_len: float, amp: float, wave := "sine") -> void:
	for i in notes.size():
		_tone(b, i * step, note_len, notes[i], notes[i], amp, wave, 0.004, 1.8)
		_tone(b, i * step, note_len, notes[i] * 2.0, notes[i] * 2.0, amp * 0.25, "sine", 0.004, 2.5)


## Nota larga y suave para la música; se extiende un poco por los dos lados (dando la vuelta al bucle).
func _pad(b: PackedFloat32Array, start: float, dur: float, f: float, amp: float) -> void:
	var overlap := 0.6
	var total := dur + overlap * 2.0
	var n := int(total * RATE)
	var i0 := int((start - overlap) * RATE)
	var phase := randf() * TAU
	for i in n:
		var u := float(i) / n
		phase += TAU * f / RATE
		var env := sin(u * PI)
		env *= env
		var tremolo := 0.85 + 0.15 * sin(TAU * 0.25 * float(i) / RATE)
		var s := sin(phase) + 0.2 * sin(phase * 2.0)
		var idx := posmod(i0 + i, b.size())
		b[idx] += s * amp * env * tremolo


## Muestras a PCM de 16 bits (en el hilo de síntesis).
func _wav(b: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	for i in b.size():
		bytes.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32767.0))
	return bytes


## El recurso de audio se crea en el hilo principal.
func _make_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
