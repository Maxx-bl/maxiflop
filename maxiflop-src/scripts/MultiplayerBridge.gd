extends Node

signal connected_to_server
signal disconnected_from_server
signal lobby_updated(players: Array, team_scores: Dictionary)
signal player_input_received(payload: Dictionary)
signal player_left(player_id: String)

@export var server_url: String = "ws://127.0.0.1:8080/ws"

var _socket := WebSocketPeer.new()
var _is_connected := false

func connect_as_host() -> void:
	if _is_connected:
		return
	var err := _socket.connect_to_url(server_url)
	if err != OK:
		push_warning("Connexion WS impossible: %s" % str(err))

func disconnect_socket() -> void:
	if _is_connected:
		_socket.close()
	_is_connected = false

func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _is_connected:
		_is_connected = true
		_send_json({"type": "host_join"})
		emit_signal("connected_to_server")
	elif state == WebSocketPeer.STATE_CLOSED and _is_connected:
		_is_connected = false
		emit_signal("disconnected_from_server")

	if state != WebSocketPeer.STATE_OPEN:
		return

	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var text := packet.get_string_from_utf8()
		_handle_message(text)

func send_game_phase(phase: String, remaining: int = 0) -> void:
	_send_json({"type": "host_phase", "phase": phase, "remaining": remaining})

func send_feedback(player_id: String, result: String, points: int, combo: int, score: int, rank: int) -> void:
	_send_json({
		"type": "feedback",
		"playerId": player_id,
		"result": result,
		"points": points,
		"combo": combo,
		"score": score,
		"rank": rank
	})

func send_scoreboard(players: Array, team_scores: Dictionary) -> void:
	_send_json({
		"type": "scoreboard",
		"players": players,
		"teamScores": team_scores
	})

func _send_json(payload: Dictionary) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(payload))

func _handle_message(raw_text: String) -> void:
	var parsed = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var msg: Dictionary = parsed
	var msg_type: String = str(msg.get("type", ""))

	match msg_type:
		"lobby_update":
			var players: Array = msg.get("players", [])
			var team_scores: Dictionary = msg.get("teamScores", {})
			emit_signal("lobby_updated", players, team_scores)
		"player_input":
			emit_signal("player_input_received", msg)
		"player_left":
			emit_signal("player_left", str(msg.get("playerId", "")))
