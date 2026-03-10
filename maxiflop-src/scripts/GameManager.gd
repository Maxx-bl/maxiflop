extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal note_hit(result: String)
signal game_started
signal game_over

const SCORE_PERFECT := 300
const SCORE_GOOD := 100
const SCORE_BAD := 50
const SCORE_MISS := 0

const WINDOW_PERFECT := 0.08
const WINDOW_GOOD := 0.15
const WINDOW_BAD := 0.25

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var multiplier: float = 1.0
var is_playing: bool = false
var song_position: float = 0.0

func _ready() -> void:
	pass

func start_game() -> void:
	score = 0
	combo = 0
	max_combo = 0
	multiplier = 1.0
	is_playing = true
	emit_signal("game_started")

func register_hit(timing_error: float, correct_color: bool) -> String:
	if not correct_color:
		register_miss()
		return "MISS"

	var result := ""
	var points := 0

	if timing_error <= WINDOW_PERFECT:
		result = "PERFECT"
		points = SCORE_PERFECT
	elif timing_error <= WINDOW_GOOD:
		result = "GOOD"
		points = SCORE_GOOD
	elif timing_error <= WINDOW_BAD:
		result = "BAD"
		points = SCORE_BAD
	else:
		register_miss()
		return "MISS"

	combo += 1
	if combo > max_combo:
		max_combo = combo

	if combo >= 20:
		multiplier = 4.0
	elif combo >= 10:
		multiplier = 3.0
	elif combo >= 5:
		multiplier = 2.0
	else:
		multiplier = 1.0

	var final_points := int(points * multiplier)
	score += final_points

	emit_signal("score_changed", score)
	emit_signal("combo_changed", combo)
	emit_signal("note_hit", result)
	return result

func register_miss() -> void:
	combo = 0
	multiplier = 1.0
	emit_signal("combo_changed", combo)
	emit_signal("note_hit", "MISS")

func end_game() -> void:
	is_playing = false
	emit_signal("game_over")

func get_multiplier_threshold() -> int:
	if combo >= 20: return 20
	elif combo >= 10: return 10
	elif combo >= 5: return 5
	return 0
