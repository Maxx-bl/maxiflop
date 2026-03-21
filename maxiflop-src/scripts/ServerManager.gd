extends Node

# PID du processus node lancé, -1 si pas démarré
var _server_pid: int = -1

func _ready() -> void:
	_start_server()
	# Arrêter le serveur proprement à la fermeture du jeu
	get_tree().root.close_requested.connect(_stop_server)

func _start_server() -> void:
	# Chemin vers server.js, relatif à l'exécutable du jeu
	var exe_dir := OS.get_executable_path().get_base_dir()
	var server_path := exe_dir.path_join("maxiflop-server/server.js")

	# En mode éditeur Godot, chercher dans le dossier du projet
	if OS.has_feature("editor"):
		server_path = ProjectSettings.globalize_path("res://").path_join("../maxiflop-server/server.js")

	# Normaliser le chemin selon l'OS
	server_path = server_path.simplify_path()

	# Trouver node selon l'OS
	var node_exe: String
	if OS.get_name() == "Windows":
		node_exe = "node.exe"
	else:
		node_exe = "node"

	print("[ServerManager] Lancement : %s %s" % [node_exe, server_path])

	var pid := OS.create_process(node_exe, [server_path])
	if pid > 0:
		_server_pid = pid
		print("[ServerManager] Serveur démarré (PID %d)" % pid)
	else:
		push_warning("[ServerManager] Impossible de démarrer le serveur Node.js. Lancez-le manuellement avec : node %s" % server_path)

func _stop_server() -> void:
	if _server_pid > 0:
		print("[ServerManager] Arrêt du serveur (PID %d)" % _server_pid)
		OS.kill(_server_pid)
		_server_pid = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_stop_server()
