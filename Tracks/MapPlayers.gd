extends Control

var players_node
onready var map_camera = get_parent().get_node("ViewportContainer/MiniMap_ViewPort/Minimap_Camera")

func _process(delta):
	update()

func _draw():
	if players_node != null:
		for player in players_node.get_children():
			var player_location = map_camera.unproject_position(player.global_transform.origin)
			if player.id == Network.self_id:
				draw_circle(player_location, 10, Color(255, 0, 0))
			else:
				draw_circle(player_location, 10, Color(0, 0, 255))
