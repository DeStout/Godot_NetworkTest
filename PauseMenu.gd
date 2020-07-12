extends Control

var xmark_texture = preload("res://Assests/Materials/Ready_XMark.png")
var checkmark_texture = preload("res://Assests/Materials/Ready_CheckMark.png")

signal toggle_minimap_visible

onready var player_list = $PlayerList/PlayerList

func _ready():
	if is_network_master():
		$PlayersButton.disabled = false
		
		$HostButton.visible = false
		$ReadyButton.visible = true
		$JoinButton.visible = false
		$DisconnectButton.visible = true
		
		$Name_Field.text = Network.self_data.name
		$Name_Field.readonly = true
		$IP_Address.text = Network.self_data.IP_address
		$IP_Address.readonly = true
		
		Network.connect("add_player_list", self, "_add_player_list")
		Network.connect("remove_player_list", self, "_remove_player_list")
		Network.connect("player_ready", self, "_player_ready")
		Network.connect("server_ready", self, "_server_ready")
		connect("toggle_minimap_visible", get_parent(), "_toggle_minimap_visible")
		
func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		if get_tree().network_peer == null or is_network_master():
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				unpause()
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				$Name_Field.text = Network.self_data.name
				visible = true
				get_tree().paused = true
#			emit_signal("toggle_minimap_visible")

func unpause():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	visible = false
	get_tree().paused = false
	
func _on_HostButton_pressed():
	var player_name
	var ip_address
	if $Name_Field.text != "":
		player_name = $Name_Field.text
	if $IP_Address.text != "":
		ip_address = $IP_Address.text
	
	Network.create_server(player_name, ip_address, 16)
	_load_game()
	
func _on_JoinButton_pressed():
	var player_name
	var ip_address
	if $Name_Field.text != "":
		player_name = $Name_Field.text
	if $IP_Address.text != "":
		ip_address = $IP_Address.text
	
	Network.connect_to_server(player_name, ip_address)
	_load_game()
	
func _load_game():
	get_tree().change_scene("res://NetworkTest.tscn")
	unpause()

func quit_game():
	get_tree().quit()
	
func _on_ReadyButton_pressed():
	if $ReadyButton.pressed:
		$ReadyButton.icon = checkmark_texture
	else:
		$ReadyButton.icon = xmark_texture
	Network.set_player_ready(get_tree().get_network_unique_id(), $ReadyButton.pressed)
	
func _add_player_list(peer_id):
	if $PlayerList.visible:
		print("Add: " + str(peer_id))
		player_list.add_item(Network.players[peer_id].name, null, false)
		player_list.add_item(Network.player[peer_id].ready, null, false)
		player_list.set_item_selectable(player_list.get_item_count()-1, 0)
	
func _remove_player_list(peer_id):
	if $PlayerList.visible:
		print("Remove: " + str(peer_id))
		for player in range(player_list.get_item_count()):
			if player_list.get_item_text(player) == Network.players[peer_id].name:
				player_list.remove_item(player+1)
				player_list.remove_item(player)
			
func _player_ready(peer_id, new_ready):
	if $PlayerList.visible:
		for player in range(player_list.get_item_count()):
			if player_list.get_item_text(player) == Network.players[peer_id].name:
				if new_ready:
					player_list.set_item_text(player+1, "Ready")
				else:
					player_list.set_item_text(player+1, "")

func _toggle_player_list():
	if is_network_master():
		if !$PlayerList.visible:
			for player in Network.players:
				var player_name = Network.players[player].name
				if player == 1:
					player_name += " (Host)"
				player_list.add_item(player_name, null, false)
				if Network.players[player].ready:
					player_list.add_item("Ready", null, false)
				else:
					player_list.add_item("", null, false)
			$PlayerList.visible = true
		else:
			$PlayerList.visible = false
			player_list.clear()

func _server_ready():
	$ReadyButton.disabled = true
