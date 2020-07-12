extends KinematicBody

var id : int = 0
var current_cam
puppet var slave_transform : Transform
puppet var slave_velocity : Vector3

var MOUSE_SENSITIVITY = 0.1
var VERTICAL_INVERT = -1
var HORIZONTAL_INVERT = -1

const GRAVITY = -100
const FORWARD_ACCELERATION = 0.015
const BACKWARD_ACCELERATION = 0.0066
const STRIFE_ACCELERATION = 0.01
const BOOST_ACCELERATION = 0.04
const BRAKE_ACCELERATION = 0.06
const DEACCEL = 0.04
const CRASH_THRESHOLD = 50

const MAX_BOOST_FUEL = 100

const MAX_FORWARD_SPEED = 150
const MAX_BACKWARD_SPEED = 33
const MAX_STRIFE_SPEED = 33
const MAX_BOOST_SPEED = 200
const TURN_SPEED = 8

var has_control = true
var is_braking = false
var is_boosting = false

onready var GroundDetect = $GroundDetect
onready var Vehicle = $Vehicle
onready var RotationHelper = $Vehicle/RotationHelper
onready var PauseMenu = $Pause
onready var Cam = $Vehicle/RotationHelper/Camera
onready var Boost_UI = $Vehicle/RotationHelper/Camera/BoostBar
onready var Speed_UI = $Vehicle/RotationHelper/Camera/SpeedBar
onready var DisplayName = $NameLocation/DisplayName
onready var NameCast = $NameLocation/NameCast

onready var cast_length = GroundDetect.cast_to.length()
var inputVector = Vector2()
var vel = Vector3.ZERO
var prev_vel = Vector3.ZERO
var dir = Vector3()
var last_transform : Transform

var speed = 0
var boost_fuel = 100
var lap_number = 0
var checkpoint = 0

var min_label_dist = 5
var max_label_dist = 500

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	PauseMenu.visible = false
	
func init(new_id, new_name, new_transform, new_velocity):
	id = new_id
	name = new_name
	global_transform = new_transform
	vel = new_velocity
	
	DisplayName.text = name
	
	if id == 0 or is_network_master():
		Network.connect('start_race', self, 'start_race')
		setup_UI()
	else:
		for node in Cam.get_children():
			node.visible = false
	
func setup_UI():
	if is_network_master():
		has_control = false
		Cam.get_node("StartTimer").visible = true
	Cam.current = true
	
	DisplayName.visible = false
	
	Boost_UI.max_value = MAX_BOOST_FUEL
	Boost_UI.min_value = 0
	Boost_UI.value = boost_fuel
	Speed_UI.max_value = MAX_BOOST_SPEED
	Speed_UI.min_value = 0
	Speed_UI.value = 0
	
func _update_ui():
	if id == 0 or is_network_master():
		Boost_UI.value = int(boost_fuel)
		Speed_UI.value = int(speed)
		
		if !Network.start_timer.is_stopped():
			Cam.get_node("StartTimer").text = str(Network.start_timer.time_left)
	else:
		current_cam = get_tree().get_root().get_camera()
		NameCast.global_transform.basis = Basis()
		NameCast.cast_to = current_cam.global_transform.origin - NameCast.global_transform.origin
		if !NameCast.is_colliding():
			if !current_cam.is_position_behind($NameLocation.global_transform.origin):
				var current_cam_dist = current_cam.global_transform.origin - $NameLocation.global_transform.origin
				if current_cam_dist.length() > min_label_dist and current_cam_dist.length() < max_label_dist:
					DisplayName.visible = true
					var screen_position = current_cam.unproject_position($NameLocation.global_transform.origin)
					var dist_size_ratio = (max_label_dist - current_cam_dist.length()) / max_label_dist
					dist_size_ratio = clamp(dist_size_ratio, 0.15, 0.95)
					DisplayName.rect_scale = Vector2(dist_size_ratio, dist_size_ratio)
					screen_position += Vector2(DisplayName.rect_scale.x * (-DisplayName.rect_size.x / 2), \
						DisplayName.rect_scale.x * -DisplayName.rect_size.y)
					DisplayName.rect_position = screen_position
				else:
					DisplayName.visible = false
			else:
				DisplayName.visible = false
		else:
			DisplayName.visible = false
	
func start_race():
	print("Go!")
	has_control = true
	Cam.get_node("StartTimer").visible = false
	
func _respawn():
	global_transform = last_transform
	vel = Vector3(0, 0, 0)
	has_control = true
	$Vehicle/RotationHelper/Camera/Crash.is_flashing = false
	
func checkpoint_reached(new_checkpoint):
	if checkpoint == new_checkpoint.serial:
		checkpoint = new_checkpoint.next_serial
		if new_checkpoint.serial == 0:
			lap_number += 1
		if get_tree().get_network_unique_id() == 0 or is_network_master():
			Cam.get_node("Checkpoint").update_display()
			
		boost_fuel += MAX_BOOST_FUEL / 4
		if boost_fuel > MAX_BOOST_FUEL:
			boost_fuel = MAX_BOOST_FUEL
	
func _process(_delta):
	if global_transform.origin.y < 0:
		_respawn()
	_update_ui()
	
func _physics_process(delta):
	if has_control:
		_process_input(delta)
	_process_movement(delta)
	
	if id > 0:
		if is_network_master():
			rset_unreliable('slave_transform', global_transform)
			rset('slave_velocity', vel)
		else:
			_process_slave()
			
		Network.players[id].name = name
		Network.players[id].pTransform = global_transform
		Network.players[id].pVelocity = vel
	
func _process_slave():
	if slave_velocity is Vector3:
		vel = slave_velocity
	if global_transform is Transform:
		global_transform = slave_transform
	else:
		move_and_slide(vel, Vector3(0, 1, 0))

func _process_input(delta):
	dir = Vector3()
	inputVector = Vector3()
	var playerTransform = self.get_global_transform().basis
	
	if Input.is_action_pressed("Accelerate"):
		inputVector.y += 1
	if Input.is_action_pressed("Brake"):
		inputVector.y += -1
	if Input.is_action_pressed("Strife_Right"):
		inputVector.x += 1
	if Input.is_action_pressed("Strife_Left"):
		inputVector.x += -1
		
	if Input.is_action_pressed("Boost"):
		is_boosting = true
	else:
		is_boosting = false
	
	#
	# Rotate camera and Player
	#
	if RotationHelper.rotation_degrees.y != 0:
		var yRot = RotationHelper.rotation_degrees.y
		yRot = yRot + (0 - yRot) * (delta * TURN_SPEED)
		RotationHelper.rotation_degrees.y = yRot
		rotate_object_local(Vector3(0, 1, 0), deg2rad(yRot * delta * TURN_SPEED))
	
	#
	# Set movement speeds
	#
	inputVector = inputVector.normalized()
	if inputVector.y >= 0:
		if is_boosting and boost_fuel > 0:
			dir += -playerTransform.z.normalized() * inputVector.y * MAX_BOOST_SPEED
		else:
			dir += -playerTransform.z.normalized() * inputVector.y * MAX_FORWARD_SPEED
	else:
		dir += -playerTransform.z.normalized() * inputVector.y * MAX_BACKWARD_SPEED
	if abs(inputVector.x) > 0:
		dir += playerTransform.x.normalized() * inputVector.x * MAX_STRIFE_SPEED
			
func _process_movement(delta):
	vel += Vector3(0, GRAVITY, 0) * delta
	
	#
	# Crash if change in vel > threshold
	#
	if Vector2(prev_vel.x, prev_vel.z).length() - Vector2(vel.x, vel.z).length() > CRASH_THRESHOLD:
#		print("Crash\n")
		inputVector = Vector3()
		dir = Vector3()
		has_control = false
		$ControlTimer.start()
		if get_tree().get_network_unique_id() == 0 or is_network_master():
			$Vehicle/RotationHelper/Camera/Crash.is_flashing = true
	
	#
	# Align to the ground normal and hover
	#
	if GroundDetect.is_colliding():
		var ground_point = GroundDetect.get_collision_point()
		var ground_normal = GroundDetect.get_collision_normal()
		var ray_origin = GroundDetect.global_transform.origin
		var ray_cast_point = (ground_point - ray_origin).normalized() * cast_length
		
		#
		# Match transform to ground normals
		#
		if transform.basis.y.dot(ground_normal) > 0:
			global_transform.basis = global_transform.basis.slerp(align_to_normal(ground_normal), delta*3)
			
		#
		# Generate hover thrust
		#
		var step = 0.9 / delta
		var vel_ray_norm = (vel.dot(ray_cast_point) * ray_cast_point)
		var proj_surf = (ground_point - ray_origin) + vel_ray_norm
		var gravity = (Vector3(0, -GRAVITY, 0) * delta) * -ray_cast_point.normalized()
		
		var delta_vel = (-proj_surf / step) + gravity
		vel += delta_vel
		
		last_transform = Transform(Basis(ground_normal), ground_point + Vector3(0, 2, 0))
	else:
		#
		# Realign transform if in the air
		#
		global_transform.basis = global_transform.basis.slerp(align_to_normal(Vector3(0, 1, 0)), delta*0.75)
	
	var hvel = vel
	hvel.y = 0
	dir.y = 0
	
	#
	# Excelleration
	#
	if GroundDetect.is_colliding():
		var accel = Vector2()
		if dir.dot(hvel) > 0:
			if inputVector.y >= 0:
				if is_boosting and boost_fuel > 0:
					accel.y = BOOST_ACCELERATION
					boost_fuel -= 0.95
					if boost_fuel < 0:
						boost_fuel = 0
				else:
					accel.y = FORWARD_ACCELERATION
			else:
				if vel.z < 0:
					accel.y = BRAKE_ACCELERATION
				else:
					accel.y = BACKWARD_ACCELERATION
			if abs(inputVector.x) > 0:
				accel.x = STRIFE_ACCELERATION
			else:
				accel.x = DEACCEL
		else:
			accel.x = DEACCEL
			accel.y = DEACCEL
	
		hvel.x = hvel.x + (dir.x - hvel.x) * (accel.x)
		hvel.z = hvel.z + (dir.z - hvel.z) * (accel.y)
		vel.x = hvel.x
		vel.z = hvel.z
	
	prev_vel = vel
	speed = Vector2(vel.x, vel.z).length()
	vel = move_and_slide(vel, Vector3(0, 1, 0))
	
func _input(event):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			RotationHelper.rotate_x(deg2rad(event.relative.y * MOUSE_SENSITIVITY * VERTICAL_INVERT))
			RotationHelper.rotate_y(deg2rad(event.relative.x * MOUSE_SENSITIVITY * HORIZONTAL_INVERT))
			
			var helperRotation = RotationHelper.rotation_degrees
			helperRotation.x = clamp(helperRotation.x, -10, 10)
			helperRotation.y = clamp(helperRotation.y, -30, 30)
			helperRotation.z = 0
			RotationHelper.rotation_degrees = helperRotation
			
func align_to_normal(normal):
	var result = Basis()
	result.x = normal.cross(transform.basis.z)
	result.y = normal
	result.z = transform.basis.x.cross(normal)
	return result.orthonormalized()

func _toggle_minimap_visible():
	$MiniMap.visible = !$MiniMap.visible
