extends Node2D

@onready var note_spawner: Node2D = $PlayField/NoteSpawner
@onready var hit_zone: Node2D = $PlayField/HitZone
@onready var hud: CanvasLayer = $HUD
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var qr_request: HTTPRequest = $QrRequest

@onready var score_label: Label = $HUD/ScoreLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var multiplier_label: Label = $HUD/MultiplierLabel
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var progress_bar: ProgressBar = $HUD/ProgressBar
@onready var count_down: Label = $HUD/CountdownLabel
@onready var result_panel: Control = $HUD/ResultPanel
@onready var team_a_score_label: Label = $HUD/RightPanel/VBox/TeamAScore
@onready var team_b_score_label: Label = $HUD/RightPanel/VBox/TeamBScore
@onready var lobby_count_label: Label = $HUD/RightPanel/VBox/LobbyCount
@onready var top5_label: Label = $HUD/RightPanel/VBox/Top5Label
@onready var qr_link_label: Label = $HUD/RightPanel/VBox/QRLink
@onready var qr_code_texture: TextureRect = $HUD/RightPanel/VBox/QRCode

@export var song_duration: float = 30.0
@export var join_url_override: String = ""

var countdown_time: float = 3.0
var is_counting_down: bool = true
var elapsed: float = 0.0
var team_scores := {"A": 0, "B": 0}
var players: Dictionary = {}

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.note_hit.connect(_on_note_hit)
	GameManager.game_over.connect(_on_game_over)
	MultiplayerBridge.connected_to_server.connect(_on_host_connected)
	MultiplayerBridge.lobby_updated.connect(_on_lobby_updated)
	MultiplayerBridge.player_input_received.connect(_on_player_input_received)
	MultiplayerBridge.player_left.connect(_on_player_left)

	result_panel.visible = false
	combo_label.visible = false
	feedback_label.visible = false
	qr_request.request_completed.connect(_on_qr_request_completed)
	_set_join_url()
	_refresh_right_panel()
	MultiplayerBridge.connect_as_host()
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
	MultiplayerBridge.send_game_phase("playing")
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
	MultiplayerBridge.send_game_phase("ended")
	result_panel.visible = true
	$HUD/ResultPanel/VBox/FinalScoreLabel.text = str(GameManager.score).lpad(7, "0")
	$HUD/ResultPanel/VBox/MaxComboLabel.text = "Meilleur combo : %d" % GameManager.max_combo
	_refresh_right_panel()

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

func _on_host_connected() -> void:
	_refresh_right_panel()

func _on_lobby_updated(remote_players: Array, remote_team_scores: Dictionary) -> void:
	players.clear()
	for p in remote_players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var player_id := str(p.get("id", ""))
		if player_id.is_empty():
			continue
		players[player_id] = {
			"id": player_id,
			"name": str(p.get("name", "Player")),
			"team": str(p.get("team", "A")),
			"score": int(p.get("score", 0)),
			"combo": int(p.get("combo", 0))
		}
	team_scores["A"] = int(remote_team_scores.get("A", 0))
	team_scores["B"] = int(remote_team_scores.get("B", 0))
	_refresh_right_panel()

func _on_player_left(player_id: String) -> void:
	if players.has(player_id):
		players.erase(player_id)
	_refresh_right_panel()

func _on_player_input_received(payload: Dictionary) -> void:
	if not GameManager.is_playing:
		return

	var player_id := str(payload.get("playerId", ""))
	var color := int(payload.get("color", -1))
	if player_id.is_empty() or color < 0 or color > 2:
		return
	if not players.has(player_id):
		return

	var result := _evaluate_remote_hit(player_id, color)
	_apply_remote_result(player_id, result)

func _evaluate_remote_hit(player_id: String, color: int) -> Dictionary:
	var best: Dictionary = note_spawner.get_best_note_for_timing(color, elapsed, GameManager.WINDOW_BAD)
	if best.is_empty():
		return {"result": "MISS", "points": 0}

	var note = best.get("note", null)
	var timing_error := float(best.get("timing_error", 999.0))
	var result := "MISS"
	var base_points := 0

	if timing_error <= GameManager.WINDOW_PERFECT:
		result = "PERFECT"
		base_points = GameManager.SCORE_PERFECT
	elif timing_error <= GameManager.WINDOW_GOOD:
		result = "GOOD"
		base_points = GameManager.SCORE_GOOD
	elif timing_error <= GameManager.WINDOW_BAD:
		result = "BAD"
		base_points = GameManager.SCORE_BAD

	if note != null and is_instance_valid(note):
		note.hit_animation(result)

	if result == "MISS":
		return {"result": "MISS", "points": 0}

	var player_data: Dictionary = players[player_id]
	var next_combo := int(player_data.get("combo", 0)) + 1
	var multiplier := 1
	if next_combo >= 20:
		multiplier = 4
	elif next_combo >= 10:
		multiplier = 3
	elif next_combo >= 5:
		multiplier = 2

	var points := base_points * multiplier
	return {
		"result": result,
		"points": points,
		"combo": next_combo
	}

func _apply_remote_result(player_id: String, result_payload: Dictionary) -> void:
	if not players.has(player_id):
		return

	var player_data: Dictionary = players[player_id]
	var result := str(result_payload.get("result", "MISS"))
	var points := int(result_payload.get("points", 0))
	var combo := int(player_data.get("combo", 0))

	if result == "MISS":
		combo = 0
	else:
		combo = int(result_payload.get("combo", combo + 1))

	var score := int(player_data.get("score", 0)) + points
	player_data["combo"] = combo
	player_data["score"] = score
	players[player_id] = player_data

	var team := str(player_data.get("team", "A"))
	team_scores[team] = int(team_scores.get(team, 0)) + points

	var sorted_players := _get_sorted_players()
	var rank := 1
	for i in sorted_players.size():
		var p: Dictionary = sorted_players[i]
		if str(p.get("id", "")) == player_id:
			rank = i + 1
			break

	MultiplayerBridge.send_feedback(player_id, result, points, combo, score, rank)
	MultiplayerBridge.send_scoreboard(_build_player_array(), team_scores)
	_refresh_right_panel()

func _build_player_array() -> Array:
	var arr: Array = []
	for k in players.keys():
		arr.append(players[k])
	return arr

func _get_sorted_players() -> Array:
	var arr := _build_player_array()
	arr.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	return arr

func _refresh_right_panel() -> void:
	team_a_score_label.text = "Equipe A: %d" % int(team_scores.get("A", 0))
	team_b_score_label.text = "Equipe B: %d" % int(team_scores.get("B", 0))
	lobby_count_label.text = "Joueurs connectes: %d" % players.size()

	var ranked := _get_sorted_players()
	var lines := ["TOP 5 JOUEURS"]
	var max_lines := mini(5, ranked.size())
	for i in max_lines:
		var p: Dictionary = ranked[i]
		lines.append("%d. %s - %d" % [i + 1, str(p.get("name", "Player")), int(p.get("score", 0))])
	top5_label.text = "\n".join(lines)

func _set_join_url() -> void:
	var join_url := join_url_override.strip_edges()
	if join_url.is_empty():
		var local_ip := _get_preferred_lan_ip()
		join_url = "http://%s:8080" % local_ip
	qr_link_label.text = "Rejoindre: %s" % join_url
	var qr_url := "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=%s" % join_url.uri_encode()
	qr_request.request(qr_url)

func _get_preferred_lan_ip() -> String:
	var fallback := "127.0.0.1"
	for addr in IP.get_local_addresses():
		if not addr.contains("."):
			continue
		if addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
		if addr.begins_with("172."):
			var parts := addr.split(".")
			if parts.size() >= 2:
				var second := int(parts[1])
				if second >= 16 and second <= 31:
					return addr
		if fallback == "127.0.0.1":
			fallback = addr
	return fallback

func _on_qr_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		return
	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		return
	var texture := ImageTexture.create_from_image(image)
	qr_code_texture.texture = texture
