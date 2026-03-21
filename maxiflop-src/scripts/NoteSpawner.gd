extends Node2D

signal note_spawned(note: Area2D)

@export var note_scene: PackedScene
@export var bpm: float = 118.0
@export var approach_time: float = 1.3

# Colonnes : 0=bleu, 1=jaune, 2=rouge
@export var column_positions: Array[float] = [213.0, 426.0, 640.0]
@export var spawn_y: float = -60.0
@export var hit_y: float = 560.0

var time_elapsed: float = 0.0
var is_running: bool = false
var song_duration: float = 30.0

var beatmap: Array = []
var active_notes: Array = []

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	pass

func _generate_random_beatmap() -> void:
	beatmap.clear()
	rng.randomize()

	var beat := 60.0 / bpm # ~0.6s à 100bpm
	var t := approach_time
	var last_col := -1

	while t < song_duration + approach_time:
		var pattern := rng.randi_range(0, 7)

		match pattern:
			0, 1, 2: # Note simple (3/8 de chance)
				var col := _rand_col(last_col)
				beatmap.append([t, col])
				last_col = col
				t += beat

			3, 4: # Deux notes séparées d'un demi-beat (2/8)
				var col_a := _rand_col(last_col)
				var col_b := _rand_col(col_a)
				beatmap.append([t, col_a])
				beatmap.append([t + beat * 0.5, col_b])
				last_col = col_b
				t += beat * 1.5

			5, 6: # Double note simultanée (2/8)
				var col_a := rng.randi_range(0, 2)
				var col_b := (col_a + rng.randi_range(1, 2)) % 3
				beatmap.append([t, col_a])
				beatmap.append([t, col_b])
				last_col = col_b
				t += beat * 1.5

			7: # Pause courte (1/8 de chance seulement)
				t += beat

	beatmap.sort_custom(func(a, b): return a[0] < b[0])

func _rand_col(exclude: int) -> int:
	var col := rng.randi_range(0, 2)
	if col == exclude:
		col = (col + 1) % 3
	return col

func start() -> void:
	_generate_random_beatmap()
	time_elapsed = 0.0
	is_running = true

func stop() -> void:
	is_running = false

func _process(delta: float) -> void:
	if not is_running:
		return
	time_elapsed += delta
	for entry in beatmap:
		var note_arrive_time: float = entry[0]
		var spawn_trigger_time: float = note_arrive_time - approach_time
		if entry.size() < 3 and time_elapsed >= spawn_trigger_time:
			entry.append(true)
			_spawn_note(entry[1], note_arrive_time)
	_check_misses()

func _spawn_note(col: int, arrive_time: float) -> void:
	if note_scene == null:
		return
	var note = note_scene.instantiate()
	note.position = Vector2(column_positions[col], spawn_y)
	note.color = col
	note.fall_speed = (hit_y - spawn_y) / approach_time
	note.spawn_time = arrive_time
	get_parent().add_child(note)
	active_notes.append(note)
	emit_signal("note_spawned", note)

func _check_misses() -> void:
	var to_remove := []
	for note in active_notes:
		if not is_instance_valid(note):
			to_remove.append(note)
			continue
		if note.has_been_hit or note.is_missed:
			to_remove.append(note)
			continue
		if note.position.y > hit_y + 100:
			note.miss_animation()
			GameManager.register_miss()
			to_remove.append(note)
	for note in to_remove:
		active_notes.erase(note)

func get_notes_near_hit(col: int, hit_y_pos: float) -> Array:
	var result := []
	for note in active_notes:
		if not is_instance_valid(note):
			continue
		if note.has_been_hit or note.is_missed:
			continue
		if note.color == col:
			if abs(note.position.y - hit_y_pos) <= 50:
				result.append(note)
	result.sort_custom(func(a, b): return abs(a.position.y - hit_y_pos) < abs(b.position.y - hit_y_pos))
	return result

func get_best_note_for_timing(col: int, song_time: float, max_window: float = 0.25) -> Dictionary:
	var best_note = null
	var best_error := 999.0
	for note in active_notes:
		if not is_instance_valid(note):
			continue
		if note.has_been_hit or note.is_missed:
			continue
		if note.color != col:
			continue
		var err: float = abs(float(note.spawn_time) - song_time)
		if err <= max_window and err < best_error:
			best_error = err
			best_note = note
	if best_note == null:
		return {}
	return {"note": best_note, "timing_error": best_error}
