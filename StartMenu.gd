extends Control

func on_ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_StartButton_pressed():
	get_tree().change_scene("res://NetworkTest.tscn")
	
func _on_QuitButton_pressed():
	get_tree().quit()
