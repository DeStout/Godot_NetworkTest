extends Label

var lap = 0
var checkpoint = 0
var previous_checkpoint = 0

func _ready():
	if get_tree().get_network_unique_id() == 0 or is_network_master():
		visible = true
		lap = owner.lap_number
		checkpoint = owner.checkpoint
		
		text = "Checkpoint: " + str(checkpoint) \
			+ "\nLap: " + str(lap)
	else:
		visible = false

func update_display():
	if get_tree().get_network_unique_id() == 0 or is_network_master():
		lap = owner.lap_number
		previous_checkpoint = checkpoint
		checkpoint = owner.checkpoint
		if checkpoint == 0:
			text = "Checkpoint: " + str(previous_checkpoint+1) \
				+ "\nLap: " + str(lap)
		else:
			text = "Checkpoint: " + str(checkpoint) \
				+ "\nLap: " + str(lap)
