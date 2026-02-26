extends Node2D

signal note_spawned(note: Area2D)

@export var note_scene: PackedScene
@export var bpm: float = 120.0
@export var approach_time: float = 1.5

# Colonnes : 0=bleu, 1=jaune, 2=rouge (même ordre que les boutons)
@export var column_positions: Array[float] = [213.0, 426.0, 640.0]
@export var spawn_y: float = -60.0
@export var hit_y: float = 560.0

var beat_interval: float
var time_elapsed: float = 0.0
var is_running: bool = false
var song_duration: float = 60.0

# Beatmap : liste de [temps_en_secondes, couleur (0=bleu, 1=jaune, 2=rouge)]
# Générée automatiquement ici, à remplacer par un vrai fichier JSON/midi
var beatmap: Array = []

# Notes actives suivies pour la détection de miss
var active_notes: Array = []

func _ready() -> void:
	beat_interval = 60.0 / bpm
	_generate_demo_beatmap()

func _generate_demo_beatmap() -> void:
	# Génère un beatmap de démonstration simple à 120 BPM
	# Pattern : [temps, colonne]
	var t := approach_time # première note arrive après approach_time
	var colors := [0, 1, 2, 1, 0, 2, 0, 1, 2, 2, 1, 0]
	var idx := 0

	while t < song_duration + approach_time:
		beatmap.append([t, colors[idx % colors.size()]])
		# Variation rythmique
		if idx % 4 == 3:
			t += beat_interval * 0.5
		else:
			t += beat_interval
		idx += 1

func start() -> void:
	time_elapsed = 0.0
	is_running = true

func stop() -> void:
	is_running = false

func _process(delta: float) -> void:
	if not is_running:
		return

	time_elapsed += delta

	# Spawn les notes dont le temps d'arrivée est maintenant
	# (on les spawne approach_time secondes à l'avance)
	for entry in beatmap:
		var note_arrive_time: float = entry[0]
		var spawn_trigger_time: float = note_arrive_time - approach_time

		if entry.size() < 3 and time_elapsed >= spawn_trigger_time:
			entry.append(true)
			_spawn_note(entry[1], note_arrive_time)

	# Nettoyage des notes qui ont passé la zone de miss
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
		# Si la note est trop basse (miss total)
		if note.position.y > hit_y + 100:
			note.miss_animation()
			GameManager.register_miss()
			to_remove.append(note)

	for note in to_remove:
		active_notes.erase(note)

func get_notes_near_hit(col: int, hit_y_pos: float) -> Array:
	# Retourne les notes dans la zone de hit pour une colonne donnée
	var result := []
	for note in active_notes:
		if not is_instance_valid(note):
			continue
		if note.has_been_hit or note.is_missed:
			continue
		if note.color == col:
			var dist = abs(note.position.y - hit_y_pos)
			if dist <= 50:
				result.append(note)
	result.sort_custom(func(a, b): return abs(a.position.y - hit_y_pos) < abs(b.position.y - hit_y_pos))
	return result
