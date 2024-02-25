extends Node3D

var xr_interface: XRInterface

var swing_rigid_body : RigidBody3D
var impulse_location : Marker3D
var force_magnitude = 1.5


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
	impulse_location = get_node("SwingRigidBody3D/ImpulseLocation")
	
	#update_force(0)
	

var going_backwards = true

func _process(delta):
	#print(swing_rigid_body.angular_velocity.x)
	print("Constant Force Z: ", swing_rigid_body.constant_force.z)
	print("Constant Torque: ", swing_rigid_body.constant_torque)
	
	if swing_rigid_body.angular_velocity.x < -0.1 and not going_backwards:
		update_force(swing_rigid_body.constant_force.z * -1)
		going_backwards = not going_backwards
		
	if swing_rigid_body.angular_velocity.x > 0.1 and going_backwards:
		update_force(swing_rigid_body.constant_force.z * -1)
		going_backwards = not going_backwards


func _input(event):
	if event.is_action_pressed("ui_text_newline"):
		update_force(force_magnitude)
	
	if event.is_action_pressed("ui_select"):
		update_force(swing_rigid_body.constant_force.z * -1)


func update_force(desired_speed):
	swing_rigid_body.add_constant_force(Vector3(0, 0, -1 * swing_rigid_body.constant_force.z))
	swing_rigid_body.add_constant_force(Vector3(0, 0, desired_speed))
