extends Node2D

@onready var note_spawner: Node2D = $PlayField/NoteSpawner
@onready var hit_zone: Node2D = $PlayField/HitZone
@onready var music_player: AudioStreamPlayer = $MusicPlayer

@onready var score_label: Label = $HUD/ScoreLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var multiplier_label: Label = $HUD/MultiplierLabel
@onready var progress_bar: ProgressBar = $HUD/ProgressBar
@onready var count_down: Label = $HUD/CountdownLabel
@onready var result_panel: Control = $HUD/ResultPanel
@onready var warmup_label: Label = $HUD/WarmupLabel
@onready var start_match_button: Button = $HUD/StartMatchButton
@onready var team_a_score_label: Label = $HUD/RightPanel/VBox/TeamAScore
@onready var team_b_score_label: Label = $HUD/RightPanel/VBox/TeamBScore
@onready var lobby_count_label: Label = $HUD/RightPanel/VBox/LobbyCount
@onready var join_link_label: Label = $HUD/RightPanel/VBox/JoinLink
@onready var team_a_progress: ProgressBar = $HUD/RightPanel/VBox/RacePanel/TeamATrack/TeamAProgress
@onready var team_b_progress: ProgressBar = $HUD/RightPanel/VBox/RacePanel/TeamBTrack/TeamBProgress
@onready var top5_label: RichTextLabel = $HUD/RightPanel/VBox/LeaderboardPanel/LeaderboardVBox/Top5Label
@onready var qr_texture: TextureRect = $HUD/RightPanel/VBox/QRCodeTexture
@onready var qr_http: HTTPRequest = $HUD/RightPanel/VBox/QRHTTPRequest
@onready var result_team_scores_label: Label = $HUD/ResultPanel/VBox/TeamScoresLabel
@onready var result_winner_label: Label = $HUD/ResultPanel/VBox/WinnerLabel
@onready var result_top5_label: RichTextLabel = $HUD/ResultPanel/VBox/Top5ResultLabel

@export var song_duration: float = 30.0
@export var join_url_override: String = ""

var countdown_time: float = 5.0
var is_counting_down: bool = false
var is_waiting_start: bool = true
var elapsed: float = 0.0
var team_scores := {"A": 0, "B": 0}
var players: Dictionary = {}
var player_judged_notes: Dictionary = {}

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.game_over.connect(_on_game_over)
	MultiplayerBridge.connected_to_server.connect(_on_host_connected)
	MultiplayerBridge.lobby_updated.connect(_on_lobby_updated)
	MultiplayerBridge.player_input_received.connect(_on_player_input_received)
	MultiplayerBridge.player_left.connect(_on_player_left)

	result_panel.visible = false
	combo_label.visible = false
	start_match_button.pressed.connect(_on_start_match_pressed)
	_set_join_url()
	qr_http.request_completed.connect(_on_qr_downloaded)
	_load_qr_code()
	_refresh_right_panel()
	MultiplayerBridge.connect_as_host()
	_enter_waiting_state()

func _enter_waiting_state() -> void:
	is_waiting_start = true
	is_counting_down = false
	warmup_label.visible = true
	warmup_label.text = "Salle d'attente"
	start_match_button.visible = true
	start_match_button.disabled = false
	count_down.visible = false
	MultiplayerBridge.send_game_phase("lobby")

func _start_countdown() -> void:
	is_waiting_start = false
	is_counting_down = true
	countdown_time = 5.0
	warmup_label.visible = false
	start_match_button.visible = false
	count_down.visible = true
	count_down.text = "5"
	MultiplayerBridge.send_game_phase("countdown")

func _process(delta: float) -> void:
	if is_waiting_start:
		return

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
	player_judged_notes.clear()
	elapsed = 0.0
	progress_bar.value = 0.0
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

func _on_game_over() -> void:
	note_spawner.stop()
	music_player.stop()
	MultiplayerBridge.send_game_phase("ended")
	is_waiting_start = true
	is_counting_down = false
	start_match_button.visible = true
	start_match_button.disabled = false
	warmup_label.visible = true
	warmup_label.text = "Partie terminee"
	result_panel.visible = true
	_refresh_result_panel()
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
func _refresh_result_panel() -> void:
	var score_a := int(team_scores.get("A", 0))
	var score_b := int(team_scores.get("B", 0))
	result_team_scores_label.text = "Equipe bleue: %d  |  Equipe rouge: %d" % [score_a, score_b]

	# Couleur équipe bleue = cyan, rouge = rose
	var color_a := Color("#5fcde4")
	var color_b := Color("#ff7081")
	if score_a > score_b:
		result_winner_label.text = "Equipe bleue remporte la partie !"
		result_winner_label.add_theme_color_override("font_color", color_a)
	elif score_b > score_a:
		result_winner_label.text = "Equipe rouge remporte la partie !"
		result_winner_label.add_theme_color_override("font_color", color_b)
	else:
		result_winner_label.text = "Egalite !"
		result_winner_label.add_theme_color_override("font_color", Color.WHITE)

	var ranked := _get_sorted_players()
	var lines := ["[b]TOP 5 JOUEURS[/b]\n"]
	var max_lines := mini(5, ranked.size())
	for i in max_lines:
		var p: Dictionary = ranked[i]
		var team := str(p.get("team", "A"))
		var name_str := str(p.get("name", "Player"))
		var score_str := str(int(p.get("score", 0)))
		var color := "#5fcde4" if team == "A" else "#ff7081"
		lines.append("%d. [color=%s]%s[/color] — %s pts" % [i + 1, color, name_str, score_str])
	result_top5_label.text = "\n".join(lines)

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
	if player_judged_notes.has(player_id):
		player_judged_notes.erase(player_id)
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
	if result.has("note_key"):
		var note_key := str(result.get("note_key", ""))
		if _already_judged_note(player_id, note_key):
			return
		_mark_judged_note(player_id, note_key)
	_apply_remote_result(player_id, result)

func _evaluate_remote_hit(player_id: String, color: int) -> Dictionary:
	var best: Dictionary = note_spawner.get_best_note_for_timing(color, elapsed, GameManager.WINDOW_BAD)
	if best.is_empty():
		return {"result": "MISS", "points": 0, "empty": true}

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
	var note_key := "%d:%d" % [color, int(round(float(note.spawn_time) * 1000.0))]
	return {
		"result": result,
		"points": points,
		"combo": next_combo,
		"note_key": note_key
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
		# Pénalité si clic dans le vide (points = -400 encodé comme 0 avec flag empty)
		var is_empty := bool(result_payload.get("empty", false))
		if is_empty:
			points = - GameManager.PENALTY_EMPTY
	else:
		combo = int(result_payload.get("combo", combo + 1))

	var score := maxi(0, int(player_data.get("score", 0)) + points)
	player_data["combo"] = combo
	player_data["score"] = score
	players[player_id] = player_data

	var team := str(player_data.get("team", "A"))
	if points > 0:
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
	team_a_score_label.text = "Equipe bleue: %d" % int(team_scores.get("A", 0))
	team_b_score_label.text = "Equipe rouge: %d" % int(team_scores.get("B", 0))
	lobby_count_label.text = "Joueurs connectes: %d" % players.size()
	var total := float(int(team_scores.get("A", 0)) + int(team_scores.get("B", 0)))
	if total <= 0.0:
		team_a_progress.value = 0.0
		team_b_progress.value = 0.0
	else:
		team_a_progress.value = (float(int(team_scores.get("A", 0))) / total) * 100.0
		team_b_progress.value = (float(int(team_scores.get("B", 0))) / total) * 100.0

	# En lobby : afficher QR code + lien, masquer classement
	# En jeu : afficher classement, masquer QR code + lien
	var in_lobby: bool = is_waiting_start
	qr_texture.visible = in_lobby
	join_link_label.visible = in_lobby
	top5_label.visible = not in_lobby

	var ranked := _get_sorted_players()
	var lines := ["[b]TOP 5 JOUEURS[/b]"]
	var max_lines := mini(5, ranked.size())
	for i in max_lines:
		var p: Dictionary = ranked[i]
		var team := str(p.get("team", "A"))
		var color := "#5fcde4" if team == "A" else "#ff7081"
		lines.append("%d. [color=%s]%s[/color] - %d" % [i + 1, color, str(p.get("name", "Player")), int(p.get("score", 0))])
	top5_label.text = "\n".join(lines)

func _load_qr_code() -> void:
	var url := join_url_override.strip_edges()
	if url.is_empty():
		url = "http://%s:3000" % _get_preferred_lan_ip()
	var encoded := url.uri_encode()
	qr_http.request("https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=" + encoded)

func _on_qr_downloaded(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var img := Image.new()
	if img.load_png_from_buffer(body) == OK:
		qr_texture.texture = ImageTexture.create_from_image(img)

func _set_join_url() -> void:
	var join_url := join_url_override.strip_edges()
	if join_url.is_empty():
		var local_ip := _get_preferred_lan_ip()
		join_url = "http://%s:3000" % local_ip
	join_link_label.text = "Adresse: %s" % join_url

func _already_judged_note(player_id: String, note_key: String) -> bool:
	if not player_judged_notes.has(player_id):
		return false
	var judged: Dictionary = player_judged_notes[player_id]
	return judged.has(note_key)

func _mark_judged_note(player_id: String, note_key: String) -> void:
	var judged: Dictionary = {}
	if player_judged_notes.has(player_id):
		judged = player_judged_notes[player_id]
	judged[note_key] = true
	player_judged_notes[player_id] = judged

func _get_preferred_lan_ip() -> String:
	var fallback := "127.0.0.1"
	# Passe 1 : chercher uniquement 192.168.x ou 10.x (Wi-Fi / LAN physique)
	for addr in IP.get_local_addresses():
		if addr.contains(":"): # Exclure IPv6
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	# Passe 2 : fallback sur toute IPv4 non-loopback non-link-local non-172
	for addr in IP.get_local_addresses():
		if addr.contains(":"):
			continue
		if addr.begins_with("127.") or addr.begins_with("169.254.") or addr.begins_with("172."):
			continue
		if fallback == "127.0.0.1":
			fallback = addr
	return fallback

func _on_start_match_pressed() -> void:
	if GameManager.is_playing:
		return
	result_panel.visible = false
	# Réinitialiser les scores
	team_scores["A"] = 0
	team_scores["B"] = 0
	player_judged_notes.clear()
	for player_id in players.keys():
		var player_data: Dictionary = players[player_id]
		player_data["score"] = 0
		player_data["combo"] = 0
		players[player_id] = player_data
	MultiplayerBridge.send_scoreboard(_build_player_array(), team_scores)
	_refresh_right_panel()
	_start_countdown()
