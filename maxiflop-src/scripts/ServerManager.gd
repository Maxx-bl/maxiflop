extends Node

# PID du processus node lancé, -1 si pas démarré
var _server_pid: int = -1

func _ready() -> void:
	# NETTOYAGE : Tuer tout ancien serveur resté bloqué sur le port 3000
	_cleanup_port_3000()
	_start_server()
	# Arrêter le serveur proprement à la fermeture du jeu
	get_tree().root.close_requested.connect(stop_server)

func _cleanup_port_3000() -> void:
	print("[ServerManager] Nettoyage du port 3000...")
	if OS.get_name() == "Windows":
		# Commande pour trouver le PID sur le port 3000 et le tuer
		var cmd = "for /f \"tokens=5\" %a in ('netstat -aon ^| findstr :3000') do taskkill /F /PID %a"
		OS.execute("cmd.exe", ["/c", cmd])
	else:
		OS.execute("sh", ["-c", "lsof -ti:3000 | xargs kill -9"])
	print("[ServerManager] Port 3000 nettoyé.")

func _start_server() -> void:
	# Chemin vers server.js, relatif à l'exécutable du jeu
	var exe_dir := OS.get_executable_path().get_base_dir()
	var server_path := exe_dir.path_join("maxiflop-server/server.js")

	# En mode éditeur Godot, chercher dans le dossier du projet
	if OS.has_feature("editor"):
		server_path = ProjectSettings.globalize_path("res://").path_join("../maxiflop-server/server.js")

	# Normaliser le chemin selon l'OS
	server_path = server_path.simplify_path()
	var server_dir := server_path.get_base_dir()

	# Vérifier que les packages sont à jour (npm install)
	print("[ServerManager] Vérification des packages (npm install)...")
	if OS.get_name() == "Windows":
		OS.execute("cmd.exe", ["/c", "cd /d \"" + server_dir + "\" && npm install"])
	else:
		OS.execute("sh", ["-c", "cd \"" + server_dir + "\" && npm install"])

	# Trouver node selon l'OS
	var node_exe: String
	if OS.get_name() == "Windows":
		node_exe = "node.exe"
	else:
		node_exe = "node"

	print("[ServerManager] Lancement : %s %s" % [node_exe, server_path])

	# Lancement silencieux en arrière-plan
	var pid := OS.create_process(node_exe, [server_path])

	if pid > 0:
		_server_pid = pid
		print("[ServerManager] Serveur démarré (PID %d)" % pid)
	else:
		push_warning("[ServerManager] Impossible de démarrer le serveur Node.js. Lancez-le manuellement avec : node %s" % server_path)

func stop_server() -> void:
	if _server_pid > 0:
		print("[ServerManager] Arrêt du serveur (PID %d)" % _server_pid)
		
		if OS.get_name() == "Windows":
			# /F = force, /T = tree (tue les enfants comme cloudflared)
			OS.execute("taskkill", ["/F", "/T", "/PID", str(_server_pid)])
		else:
			OS.kill(_server_pid)
			
		_server_pid = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop_server()
