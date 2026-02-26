extends Node2D

@onready var note_spawner: Node2D = $PlayField/NoteSpawner
@onready var hit_zone: Node2D = $PlayField/HitZone
@onready var hud: CanvasLayer = $HUD
@onready var music_player: AudioStreamPlayer = $MusicPlayer

@onready var score_label: Label = $HUD/ScoreLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var multiplier_label: Label = $HUD/MultiplierLabel
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var progress_bar: ProgressBar = $HUD/ProgressBar
@onready var count_down: Label = $HUD/CountdownLabel
@onready var result_panel: Control = $HUD/ResultPanel

@export var song_duration: float = 30.0

var countdown_time: float = 3.0
var is_counting_down: bool = true
var elapsed: float = 0.0

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.note_hit.connect(_on_note_hit)
	GameManager.game_over.connect(_on_game_over)

	result_panel.visible = false
	combo_label.visible = false
	feedback_label.visible = false
	_start_countdown()

func _start_countdown() -> void:
	is_counting_down = true
	count_down.visible = true
	count_down.text = "3"

func _process(delta: float) -> void:
	if is_counting_down:
		countdown_time -= delta
		var display := ceili(countdown_time)
		if display > 0:
			count_down.text = str(display)
		else:
			count_down.text = "GO !"
			if countdown_time <= -0.4:
				_begin_game()
		return

	elapsed += delta
	progress_bar.value = (elapsed / song_duration) * 100.0

	if elapsed >= song_duration:
		GameManager.end_game()

func _begin_game() -> void:
	is_counting_down = false
	count_down.visible = false
	note_spawner.song_duration = song_duration
	note_spawner.start()
	GameManager.start_game()
	if music_player.stream != null:
		music_player.play()

#Signaux

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score).lpad(7, "0")

func _on_combo_changed(new_combo: int) -> void:
	if new_combo > 1:
		combo_label.visible = true
		combo_label.text = "x%d COMBO" % new_combo

		var tween := create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.05)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		combo_label.visible = false

	if GameManager.multiplier > 1.0:
		multiplier_label.text = "x%.0f" % GameManager.multiplier
		multiplier_label.visible = true
	else:
		multiplier_label.visible = false

func _on_note_hit(result: String) -> void:
	feedback_label.visible = true

	match result:
		"PERFECT":
			feedback_label.text = "PERFECT !!"
			feedback_label.modulate = Color("#84FFC9")
		"GOOD":
			feedback_label.text = "GOOD :)"
			feedback_label.modulate = Color("#AAB2FF")
		"BAD":
			feedback_label.text = "BAD :/"
			feedback_label.modulate = Color("#F0E040")
		"MISS":
			feedback_label.text = "MISS :("
			feedback_label.modulate = Color("#FF7081")

	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(feedback_label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): feedback_label.visible = false; feedback_label.modulate.a = 1.0)

func _on_game_over() -> void:
	note_spawner.stop()
	music_player.stop()
	result_panel.visible = true
	$HUD/ResultPanel/VBox/FinalScoreLabel.text = str(GameManager.score).lpad(7, "0")
	$HUD/ResultPanel/VBox/MaxComboLabel.text = "Meilleur combo : %d" % GameManager.max_combo

#btn hitzone

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_btn_blue_pressed() -> void: hit_zone.press_button(0)
func _on_btn_yellow_pressed() -> void: hit_zone.press_button(1)
func _on_btn_red_pressed() -> void: hit_zone.press_button(2)
func _on_restart_pressed() -> void: get_tree().reload_current_scene()
func _on_menu_pressed() -> void: get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
