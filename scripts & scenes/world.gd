extends Node3D

var xr_interface: XRInterface
var swing_rigid_body : RigidBody3D
var hinge_joint: HingeJoint3D
var wind_sound_player: AudioStreamPlayer
var ride_music_player: AudioStreamPlayer3D
var direction_lock_timer: Timer
var ride_finish_timer: Timer
var ride_speedup_timer: Timer
var info_text: Label3D

# Starting force applied to the swing
var force_magnitude = 2.5
var direction_change_lock = false

# Keep track of the direction we are *trying* to go
var going_backwards = true


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
	hinge_joint = get_node("HingeJoint3D")
	wind_sound_player = get_node("SwingRigidBody3D/PlayerXR/WindSound")
	direction_lock_timer = get_node("SwingRigidBody3D/DirectionChangeTimer")
	ride_finish_timer = get_node("RideFinishTimer")
	ride_speedup_timer = get_node("RideSpeedupTimer")
	ride_music_player = get_node("RideMusic")
	info_text = get_node("InfoText")
	
	swing_rigid_body.mass = 1
	swing_rigid_body.gravity_scale = 1
	
	# Set the initial values for the wind sound
	wind_sound_player.volume_db = 0
	wind_sound_player.pitch_scale = 1
	
	# Ensure that the info text is visible on program start
	info_text.visible = true


func _process(delta):
	#print(swing_rigid_body.angular_velocity.x)
	#print("Constant Force: ", swing_rigid_body.constant_force)
	#print("Constant Torque: ", swing_rigid_body.constant_torque)
	#print("Angle Vel: ", swing_rigid_body.angular_velocity)
	#print("Angle: ", swing_rigid_body.rotation)
	
	# Only consider changing directions when we haven't done so recently
	if not direction_change_lock:
		# Flip motor direction when we hit our peak
		if swing_rigid_body.angular_velocity.x < 0 and not going_backwards:
			update_force(swing_rigid_body.constant_force.z * -1)
			going_backwards = not going_backwards
			direction_lock_timer.start()
			direction_change_lock = true
			clear_torque()
		
		# Flip motor direction when we hit our peak
		if swing_rigid_body.angular_velocity.x > 0 and going_backwards:
			update_force(swing_rigid_body.constant_force.z * -1)
			going_backwards = not going_backwards
			direction_lock_timer.start()
			direction_change_lock = true
			clear_torque()
	
	set_wind_sound(abs(swing_rigid_body.angular_velocity.x))


func _input(event):
	# If the user presses 'enter,' start the ride
	if event.is_action_pressed("start_ride"):
		# For a brief duration, set the constant force to 10 to jump-start the movement
		update_force(10)
		await get_tree().create_timer(0.1).timeout
		# Once the ride is moving, we can return to our desired force value
		update_force(force_magnitude)
		clear_torque()
		# Clear the info text when the ride starts
		info_text.visible = false
		# Start the timers for the ride
		ride_finish_timer.start()
		ride_speedup_timer.start()


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
	if wind_sound_player.pitch_scale > 2.0:
		wind_sound_player.pitch_scale = 2.0


func ride_complete():
	print("Ride done!")
	info_text.visible = true
	swing_rigid_body.linear_damp = 0
	swing_rigid_body.angular_damp = 0
	clear_torque()
	update_force(0)
	swing_rigid_body.mass = 1
	swing_rigid_body.gravity_scale = 1
	going_backwards = true
	force_magnitude = 2.5
	direction_change_lock = false


# Loop the wind audio
func _on_wind_sound_finished():
	wind_sound_player.play()


func _on_ride_music_finished():
	ride_music_player.play()


func _on_direction_change_timer_timeout():
	direction_change_lock = false


func _on_ride_finish_timer_timeout():
	update_force(0)
	await get_tree().create_timer(5).timeout
	# After allowing the ride to swing unpowered, apply the breaks (damping)
	swing_rigid_body.linear_damp = 0.3
	swing_rigid_body.angular_damp = 0.3
	await get_tree().create_timer(3).timeout
	swing_rigid_body.linear_damp = 0.6
	swing_rigid_body.angular_damp = 0.6
	await get_tree().create_timer(3).timeout
	swing_rigid_body.linear_damp = 0.9
	swing_rigid_body.angular_damp = 0.9
	await get_tree().create_timer(3).timeout
	ride_complete()

func _on_ride_speedup_timer_timeout():
	# Increase speed of the ride
	swing_rigid_body.add_constant_force(Vector3(0, 0, 0.3 * swing_rigid_body.constant_force.z))
	# Start the speedup timer again
	ride_speedup_timer.start()
