extends Label

var flash_timer = Timer.new()
var is_flashing = false setget toggle_flash

func _ready():
	flash_timer.connect('timeout', self, 'flash')
	flash_timer.one_shot = false
	add_child(flash_timer)
	visible = false

func toggle_flash(flash):
	is_flashing = flash
	if is_flashing == false:
		visible = false
		flash_timer.stop()
	else:
		flash()
	
func flash():
	if is_flashing:
		flash_timer.start(0.5)
		visible = !visible
