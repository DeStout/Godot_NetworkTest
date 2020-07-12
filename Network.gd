extends Node

var current_scene = null setget _current_scene_changed

signal start_race
signal add_player_list
signal remove_player_list
signal player_ready
signal server_ready

var start_timer = Timer.new()
const SERVER_WAIT_TIME = 180
const FULL_WAIT_TIME = 5

const DEFAULT_IP = '127.0.0.1'
const DEFAULT_PORT = 31400
const MAX_CONNECTIONS = 16

var upnp = UPNP.new()

var self_id = 0
var players = {}
var self_data = {}

func _ready():
	pause_mode = Node.PAUSE_MODE_PROCESS
	
	start_timer.connect('timeout', self, '_start_race')
	start_timer.one_shot = true
	add_child(start_timer)
	
#	get_tree().connect("connected_to_server", self, "_connected")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	
	reset_data()
	
func reset_data():
	self_data = {name = "", pTransform = Transform(), pVelocity = Vector3(0, 0, 0), \
		IP_address = DEFAULT_IP, ready = false}

func _current_scene_changed(new_scene):
	current_scene = new_scene
	populate_scene()
	
func clear_network_peer():
	if get_tree().network_peer != null:
		get_tree().network_peer.close_connection()
		get_tree().set_network_peer(null)
	
func create_server(new_name, player_ip, player_connections = MAX_CONNECTIONS):
	if new_name == null:
		new_name = "Host"
	if player_ip == null:
		player_ip = DEFAULT_IP
		
	var upnp_result = upnp.discover()
	var port_result = upnp.add_port_mapping(DEFAULT_PORT)
	
	reset_data()
	clear_network_peer()
	
	var peer = NetworkedMultiplayerENet.new()
	var connection = peer.create_server(DEFAULT_PORT, player_connections)
	peer.set_bind_ip(player_ip)
	print("IP Address: " + player_ip)
	get_tree().set_network_peer(peer)
	print("Server Connection Code: " + str(connection))
	
	self_data.name = new_name
	self_id = 1
	self_data.IP_address = player_ip
	players[1] = self_data
	
	start_timer.start(SERVER_WAIT_TIME)
	
func connect_to_server(new_name, player_ip):
	if new_name == null:
		new_name = "Player"
	if player_ip == null:
		player_ip = DEFAULT_IP
		
	clear_network_peer()
	
	var peer = NetworkedMultiplayerENet.new()
	var connection = peer.create_client(player_ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)
	self_id = get_tree().get_network_unique_id()
	print("Client Connection Code: " + str(connection))
	
	self_data.name = new_name
	self_data.IP_address = player_ip
	
func _server_disconnected():
	print("Server Disconnected =(")
	get_tree().quit()
	
func _player_connected(peer_id):
	print('Player Connected: ' + str(peer_id))
	if get_tree().is_network_server():
		for player in players:
			rpc_id(peer_id, '_set_player_info', player, players[player])
		rpc_id(peer_id, '_send_server_info', self_id, self_data)
	
remotesync func _set_player_info(peer_id, info):
	players[peer_id] = info
	if current_scene != null:
		current_scene.spawn_net_player(peer_id)
		emit_signal("add_player_list", peer_id)
	else:
		print("Warning: Current_Scene is null")
		
remote func _send_server_info(peer_id, info):
	if get_tree().is_network_server():
		rpc('_set_player_info', peer_id, info)
		rpc_id(peer_id, "set_start_timer", start_timer.time_left)
	else:
		if self_data.name == "Player":
			self_data.name += str(players.size() + 1)
		rpc_id(1, '_send_server_info', self_id, self_data)
		
remotesync func set_start_timer(time_left):
	start_timer.start(time_left)
	
	if time_left == FULL_WAIT_TIME:
		emit_signal("server_ready")
	
remotesync func _start_race():
	print("Start")
	emit_signal("start_race")
	
func _player_disconnected(peer_id):
	print('Player Disconnected: ' + str(peer_id) + " - " + players[peer_id].name)
	emit_signal("remove_player_list", peer_id)
	players.erase(peer_id)
	current_scene.delete_net_player(peer_id)

func populate_scene():
	if players.size() > 0:
		print("Populating Scene")
		for peer_id in players:
			current_scene.spawn_net_player(peer_id)
	else:
		print("Warning: Cannot Populate")
		
remote func set_player_ready(peer_id, new_ready):
	if self_id == peer_id:
		self_data.ready = new_ready
		players[self_id] = self_data
		rpc('set_player_ready', self_id, new_ready)
	else:
		players[peer_id].ready = new_ready
		emit_signal("player_ready", peer_id, new_ready)
		
	if self_id == 1:
		for player in players:
			if !players[player].ready:
				return
		print("All Players Ready")
		if start_timer.time_left > FULL_WAIT_TIME:
			rpc('set_start_timer', FULL_WAIT_TIME)
