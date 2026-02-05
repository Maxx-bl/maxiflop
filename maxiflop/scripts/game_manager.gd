extends Node

var player_count = 0

func _ready() -> void:
	player_count = get_tree().get_nodes_in_group("players").size()

func _process(_delta):
	print("Joueurs : ", player_count)
