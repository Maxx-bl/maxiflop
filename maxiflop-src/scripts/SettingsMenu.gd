extends Control

@onready var in_game_slider: HSlider = %MasterSlider
@onready var menu_slider: HSlider = %MusicSlider

func _ready() -> void:
	# Initialise les sliders avec les nouvelles variables du manager
	in_game_slider.value = SettingsManager.in_game_volume
	menu_slider.value = SettingsManager.menu_music_volume
	
	# Connecte les signaux
	in_game_slider.value_changed.connect(_on_in_game_changed)
	menu_slider.value_changed.connect(_on_menu_music_changed)
	
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_in_game_changed(value: float) -> void:
	SettingsManager.in_game_volume = value
	SettingsManager.apply_volumes()

func _on_menu_music_changed(value: float) -> void:
	SettingsManager.menu_music_volume = value
	SettingsManager.apply_volumes()

func _on_back_pressed() -> void:
	# Sauvegarde les réglages avant de quitter
	SettingsManager.save_settings()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
