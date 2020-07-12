tool
extends MeshInstance

export var serial = 0 setget _set_next_serial
export var next_serial = 0

func _ready():
	pass
	
func _set_next_serial(new_serial):
	serial = new_serial
	update_next_serial(true)
		
func update_next_serial(first):
	if Engine.is_editor_hint():
		next_serial = 0
		for sib_serial in get_parent().get_children():
			if sib_serial.serial > serial:
				next_serial = serial + 1
				return
			if first:
				sib_serial.update_next_serial(false)
			property_list_changed_notify()

func _on_Area_body_entered(body):
	if body.has_method("checkpoint_reached"):
		body.checkpoint_reached(self)
