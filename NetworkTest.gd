extends Node

var players_node

var instance_player = preload("res://Player.tscn")
var num_laps = 3

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	
	if !get_tree().get_root().has_node("Players"):
		players_node = Node.new()
		players_node.name = "Players"
		get_tree().get_root().add_child(players_node)
	else:
		players_node = get_tree().get_root().get_node("Players")
		delete_all_players()
	$Track/Players.players_node = players_node
	
	if get_tree().network_peer == null:
		_spawn_local_player()
	else:
		Network.current_scene = self

func _spawn_local_player():
	var local_player = instance_player.instance()
	players_node.add_child(local_player)
	local_player.init(0, "Player1", $Spawns/Spawn1.global_transform, Vector3.ZERO)

func spawn_net_player(player_id):
	var player_number = players_node.get_child_count() + 1
	var player_name = Network.players[player_id].name
	var player_transform = get_node("Spawns/Spawn"+str(player_number)).global_transform
	
	if !players_node.has_node(player_name):
		var new_player = instance_player.instance()
		new_player.set_network_master(player_id)
		players_node.add_child(new_player)
		new_player.init(player_id, player_name, player_transform, Vector3.ZERO)
		print("Player Spawn: " + str(player_id) + " - " + player_name)
		
		Network.players[player_id].name = player_name
		Network.players[player_id].pTransform = player_transform
		Network.players[player_id].pVelocity = Vector3.ZERO
	else:
		print("Warning: Skipping Duplicate Player: " + str(player_id) + " - " + player_name)
		
func delete_net_player(player_id):
	for player in players_node.get_children():
		if player.id == player_id:
			players_node.remove_child(player)
			player.queue_free()
			
func delete_all_players():
	for player in players_node.get_children():
		player.queue_free()
		players_node.remove_child(player)
