extends Node2D

@onready var title_label: Label = $TitleLabel
@onready var start_button: Button = $StartButton
@onready var quit_button: Button = $QuitButton

func _ready() -> void:
	title_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(start_button, "modulate:a", 1.0, 0.4)

	start_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0

	await get_tree().create_timer(0.6).timeout
	var t2 := create_tween()
	t2.tween_property(start_button, "modulate:a", 1.0, 0.3)
	t2.tween_property(quit_button, "modulate:a", 1.0, 0.3)

func _on_start_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/GameScreen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
