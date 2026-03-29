extends Node

signal connected_to_server
signal disconnected_from_server
signal lobby_updated(players: Array, team_scores: Dictionary)
signal player_input_received(payload: Dictionary)
signal player_left(player_id: String)
signal public_url_received(url: String)

# L'URL qui imite la toute première connexion d'un client HTTP Socket.IO via WebSocket
@export var server_url: String = "ws://127.0.0.1:3000/socket.io/?EIO=4&transport=websocket"

var _socket := WebSocketPeer.new()
var _is_connected := false

func connect_as_host() -> void:
	if _is_connected:
		return
	# Attendre 3s que le serveur Node.js et localtunnel soient prêts
	await get_tree().create_timer(3.0).timeout
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

	if state == WebSocketPeer.STATE_CLOSED and _is_connected:
		_is_connected = false
		emit_signal("disconnected_from_server")

	if state != WebSocketPeer.STATE_OPEN:
		return

	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var text := packet.get_string_from_utf8()
		_handle_message(text)

func send_game_phase(phase: String, remaining: int = 0) -> void:
	_emit_socketio("host_phase", {"phase": phase, "remaining": remaining})

func send_feedback(player_id: String, result: String, points: int, combo: int, score: int, rank: int) -> void:
	_emit_socketio("feedback", {
		"playerId": player_id,
		"result": result,
		"points": points,
		"combo": combo,
		"score": score,
		"rank": rank
	})

func send_scoreboard(players: Array, team_scores: Dictionary) -> void:
	_emit_socketio("scoreboard", {
		"players": players,
		"teamScores": team_scores
	})

func request_lobby() -> void:
	_emit_socketio("get_lobby", {})

# Traduction du JSON en trame Socket.IO (code '42') !
func _emit_socketio(event_name: String, payload: Dictionary = {}) -> void:
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var msg = "42" + JSON.stringify([event_name, payload])
	_socket.send_text(msg)

func _handle_message(text: String) -> void:
	# === LOGIQUE INTERNE ENGINE.IO & SOCKET.IO DÉCODÉE EN GDSCRIPT ===
	
	if text.begins_with("0"):
		# Message 0: Engine.IO Open -> On demande tout de suite la connexion Socket.IO (Message 40)
		_socket.send_text("40")
	
	elif text.begins_with("2"):
		# Message 2: Engine.IO Ping -> On répond avec un Pong (Message 3) pour ne pas être kické !
		_socket.send_text("3")
		
	elif text.begins_with("40"):
		# Message 40: Socket.IO nous accepte officiellement ! On envoie 'host_join'
		if not _is_connected:
			_is_connected = true
			_emit_socketio("host_join", {})
			emit_signal("connected_to_server")
			
	elif text.begins_with("42"):
		# Message 42: C'est un événement Socket.IO. On traite le JSON "magique" de la forme ["mon_event", {data}]
		var json_str = text.substr(2)
		var parsed = JSON.parse_string(json_str)
		if typeof(parsed) == TYPE_ARRAY and parsed.size() >= 2:
			var event_name = str(parsed[0])
			var msg = parsed[1]
			
			if typeof(msg) == TYPE_DICTIONARY:
				match event_name:
					"lobby_update":
						var players: Array = msg.get("players", [])
						var team_scores: Dictionary = msg.get("teamScores", {})
						emit_signal("lobby_updated", players, team_scores)
					"player_input":
						emit_signal("player_input_received", msg)
					"player_left":
						emit_signal("player_left", str(msg.get("playerId", "")))
					"public_url":
						emit_signal("public_url_received", str(msg.get("url", "")))
