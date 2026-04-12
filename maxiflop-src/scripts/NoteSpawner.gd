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
var is_looping: bool = false
var song_duration: float = 30.0

var active_notes: Array = []

var analyzer_instance: AudioEffectSpectrumAnalyzerInstance
@export var bass_threshold: float = 0.003
@export var cooldown_time: float = 0.12
var current_cooldown: float = 0.0
var smoothed_magnitude: float = 0.0
var bass_baseline: float = 0.0
var is_in_beat: bool = false
var current_max_freq: float = 150.0
var treble_baseline: float = 0.0
var is_in_treble: bool = false


var rng := RandomNumberGenerator.new()

func start_spectrum(bus_idx: int) -> void:
	time_elapsed = 0.0
	is_running = true
	rng.randomize()
	current_cooldown = 0.0
	smoothed_magnitude = 0.0
	bass_baseline = 0.0
	is_in_beat = false
	if bus_idx >= 0:
		analyzer_instance = AudioServer.get_bus_effect_instance(bus_idx, 0) as AudioEffectSpectrumAnalyzerInstance
		if analyzer_instance:
			print("[NoteSpawner] Analyse spectrale demarree sur le bus ", bus_idx)
		else:
			print("[NoteSpawner] ERREUR : Impossible de recuperer l'instance de l'analyseur sur le bus ", bus_idx)
	else:
		print("[NoteSpawner] ERREUR : Index de bus invalide (", bus_idx, ")")

func set_difficulty(diff_name: String) -> void:
	var d = diff_name.to_upper()
	if d.ends_with("EASY"):
		bass_threshold = 0.008
		cooldown_time = 0.20
	elif d.ends_with("MEDIUM"):
		bass_threshold = 0.004
		cooldown_time = 0.16
	elif d.ends_with("HARD"):
		bass_threshold = 0.002
		cooldown_time = 0.13
	elif d.ends_with("EXTREME"):
		bass_threshold = 0.001
		cooldown_time = 0.10
		current_max_freq = 150.0
	else:
		# Valeur par défaut si non spécifié
		bass_threshold = 0.004
		cooldown_time = 0.15
		current_max_freq = 150.0
	
	print("[NoteSpawner] Difficulte reglee sur: ", d, " (Threshold: ", bass_threshold, ", Cooldown: ", cooldown_time, ")")

func stop() -> void:
	is_running = false

func _process(delta: float) -> void:
	if not is_running:
		return
	time_elapsed += delta
	
	if current_cooldown > 0:
		current_cooldown -= delta
		
	if analyzer_instance != null:
		var mag: Vector2 = analyzer_instance.get_magnitude_for_frequency_range(20.0, current_max_freq, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
		var bass_energy = (mag.x + mag.y) / 2.0
		
		# Suivi très réactif de l'énergie (smooth)
		smoothed_magnitude = lerp(smoothed_magnitude, bass_energy, delta * 30.0)
		
		# Suivi très lent pour estimer l'ambiance globale de basse (bruit de fond / nappe)
		bass_baseline = lerp(bass_baseline, bass_energy, delta * 1.5)
		
		var dynamic_threshold = bass_baseline + bass_threshold
		
		# [BASSES] Detection de type "Schmitt trigger" (Hysteresis) adaptatif
		if smoothed_magnitude > dynamic_threshold:
			if not is_in_beat and current_cooldown <= 0:
				_spawn_bass_note()
				current_cooldown = cooldown_time
			is_in_beat = true
		elif smoothed_magnitude < dynamic_threshold - (bass_threshold * 0.5):
			# Réarmer le beat quand l'énergie retombe bas
			is_in_beat = false

		# [MELODIE] Detection additionnelle pour densifier en mode Battle Royale
		if is_looping:
			var mag_treble: Vector2 = analyzer_instance.get_magnitude_for_frequency_range(300.0, 5000.0, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
			var treble_energy = (mag_treble.x + mag_treble.y) / 2.0
			treble_baseline = lerp(treble_baseline, treble_energy, delta * 2.0)
			
			# Seuil beaucoup plus sensible pour la melodie (plus de notes)
			var dyn_treble_threshold = treble_baseline + (bass_threshold * 1.0)
			
			if treble_energy > dyn_treble_threshold:
				if not is_in_treble and current_cooldown <= 0:
					_spawn_bass_note()
					# Cooldown tres court pour une densite maximale (Massacre !)
					current_cooldown = cooldown_time * 0.3
				is_in_treble = true
			elif treble_energy < dyn_treble_threshold * 0.7:
				is_in_treble = false

	_check_misses()

var last_col: int = -1

func _spawn_bass_note() -> void:
	if not is_looping and time_elapsed >= song_duration - 3.0:
		return
		
	var col := rng.randi_range(0, 2)
	if col == last_col:
		col = (col + rng.randi_range(1, 2)) % 3
	last_col = col
	
	# Le ghost player entend la basse mtn
	# L'auditeur l'entendra exactement dans approach_time secondes
	var note_strike_time = time_elapsed + approach_time
	_spawn_note(col, note_strike_time)


func _spawn_note(col: int, arrive_time: float) -> void:
	if note_scene == null:
		return
	var note = note_scene.instantiate()
	note.position = Vector2(column_positions[col], spawn_y)
	note.color = col
	note.fall_speed = (hit_y - spawn_y) / approach_time
	note.spawn_time = arrive_time
	note.hit_y = hit_y
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
		if time_elapsed > note.spawn_time + 0.25:
			note.miss_animation()
			GameManager.register_miss()
			GameManager.emit_signal("global_note_missed", note.color, note.spawn_time)
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
