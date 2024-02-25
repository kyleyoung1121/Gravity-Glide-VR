extends Node3D

var xr_interface: XRInterface
var swing_rigid_body : RigidBody3D
var wind_sound_player: AudioStreamPlayer

# Starting force applied to the swing
var force_magnitude = 2


func _ready():
	# Set up XR
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized successfully")
		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
	else:
		print("OpenXR not initialized, please check if your headset is connected")
	
	# Grab relevant items for swing process
	swing_rigid_body = get_node("SwingRigidBody3D")
	wind_sound_player = get_node("SwingRigidBody3D/PlayerXR/WindSound")
	
	# Set the initial values for the wind sound
	wind_sound_player.volume_db = 0
	wind_sound_player.pitch_scale = 1

# Keep track of the direction we are *trying* to go
var going_backwards = true


func _process(delta):
	#print(swing_rigid_body.angular_velocity.x)
	print("Constant Force: ", swing_rigid_body.constant_force)
	#print("Constant Torque: ", swing_rigid_body.constant_torque)
	print("Angle Vel: ", swing_rigid_body.angular_velocity)
	
	# Flip motor direction when we hit our peak
	if swing_rigid_body.angular_velocity.x < 0 and not going_backwards:
		update_force(swing_rigid_body.constant_force.z * -1)
		going_backwards = not going_backwards
		clear_torque()
	
	# Flip motor direction when we hit our peak
	if swing_rigid_body.angular_velocity.x > 0 and going_backwards:
		update_force(swing_rigid_body.constant_force.z * -1)
		going_backwards = not going_backwards
		clear_torque()
	
	set_wind_sound(abs(swing_rigid_body.angular_velocity.x))


func _input(event):
	# If the user presses 'enter,' start the ride
	if event.is_action_pressed("ui_text_newline"):
		# For a brief duration, set the constant force to 10 to jump-start the movement
		update_force(10)
		await get_tree().create_timer(0.1).timeout
		# Once the ride is moving, we can return to our desired force value
		update_force(force_magnitude)
		clear_torque()
	
	# If the user presses 'space,' increase the ride speed
	if event.is_action_pressed("ui_select"):
		swing_rigid_body.add_constant_force(Vector3(0, 0, 0.3 * swing_rigid_body.constant_force.z))


# Clear the existing constant force and set the new value
func update_force(desired_speed):
	swing_rigid_body.add_constant_force(Vector3(0, 0, -1 * swing_rigid_body.constant_force.z))
	swing_rigid_body.add_constant_force(Vector3(0, 0, desired_speed))


# Clear the x, y, and z torque components
func clear_torque():
	# Add the opposite of the current value. Split into 3 lines for readability
	swing_rigid_body.add_constant_torque(Vector3(-1 * swing_rigid_body.constant_torque.x, 0, 0))
	swing_rigid_body.add_constant_torque(Vector3(0, -1 * swing_rigid_body.constant_torque.y, 0))
	swing_rigid_body.add_constant_torque(Vector3(0, 0, -1 * swing_rigid_body.constant_torque.z))


# Adjust volume and pitch according to my discovered speed-scale
func set_wind_sound(speed):
	wind_sound_player.volume_db = speed * 20
	wind_sound_player.pitch_scale = speed + 1
	# Ensure that maximums are not exceeded
	if wind_sound_player.volume_db > 22:
		wind_sound_player.volume_db = 22
	if wind_sound_player.pitch_scale > 2.5:
		wind_sound_player.pitch_scale = 2.5


# Loop the wind audio
func _on_wind_sound_finished():
	wind_sound_player.play()
