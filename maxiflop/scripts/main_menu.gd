extends Control


func _on_host_game_pressed() -> void:
	NetworkManager.create_server()


func _on_join_game_pressed() -> void:
	NetworkManager.create_client()


func _on_test_pressed() -> void:
	#enable rpc
	_send_test_msg.rpc("Hello")
	
#any peer : pour que npt qui co au server puisse s'y connecter
#call_remote : pour pas que ca run que locally mais sur les peer connectés
@rpc("any_peer", "call_remote")
func _send_test_msg(message: String):
	print("Message [%s] recu sur le peer [%s], provenant de [%s]." %
	[message,
	get_tree().get_multiplayer().get_unique_id(),
	get_tree().get_multiplayer().get_remote_sender_id()])
