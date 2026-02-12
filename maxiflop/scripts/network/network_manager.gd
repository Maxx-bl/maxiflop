extends Node

const SERVER_PORT : int = 8080

func create_server():
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	#créer un peer network sur un port par dflt
	enet_network_peer.create_server(SERVER_PORT)
	# on met le serveur sur l'api multiplayer peer
	get_tree().get_multiplayer().multiplayer_peer = enet_network_peer
	print("serveur créé !")
	
func create_client(host_ip: String = "localhost", host_port: int = SERVER_PORT):
	var enet_network_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	#se connecter sur la machine hote (on peut remplacer loopback par l'ip
	enet_network_peer.create_client("localhost", SERVER_PORT)
	get_tree().get_multiplayer().multiplayer_peer = enet_network_peer
	print("client connecté!")
