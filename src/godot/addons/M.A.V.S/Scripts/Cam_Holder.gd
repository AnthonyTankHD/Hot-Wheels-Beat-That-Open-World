extends Node3D

@export var player_id : int = 0 # ID for player in case of multiplayer
@export var cam_parent : Node3D # Camera Anchor node for easy access to the vehicle
@export var cam_holder : Node3D # Camera holder for easy rotation with analogue "We could use cam_parent but then we have to adjust its heigh"
@export var camera : Camera3D # Camera itself if necessary to change
@export var cam_arm : SpringArm3D # Spring arm used to prevent camera from clipping
@export var cam_position : Node3D # Position where we want our spring arm to be "Replaced with a single location for better compatibility with spring arm"
@export var cam_angle_limit : int = 20 # Limit camera angle for both X angle when moving manualy and for vehicle rotation
@export var orbit_speed : float = 2.0 # How fast we rotate camera manualy
@export var invert_cam_y : bool = false # Flip right-stick up/down (pause menu setting)
@export var orbit_smoothness : float = 5.0 # How smooth it rotates when moved manually
@export var auto_reset_delay : float = 1.0 # Seconds before reset starts
@export var auto_reset_speed : float = 2 # How fast it resets
# Default chase-camera distance. Was 4.0 — the car filled the whole
# screen and you could not see the wheels or the full car. 8.0 pulls
# back far enough to see the whole car with room around it.

var current_cam : int = 0 # Current camera position
var cam_rot_x : float = 0.0 # Rotation in X axis applied by gamepad
var cam_rot_y : float = 0.0 # Rotation in Y axis applied by gamepad
var cam_current_x : float = 0.0 # Smoothing and actuall rotation for orbital camera X
var cam_current_y : float = 0.0 # Smoothing and actuall rotation for orbital camera Y
var time_since_input : float = 0.0 # Delay timer before camera possitione itself back again
@onready var hood = cam_parent.get_parent().hood_cam # Reference to Hood camera location in the car

const X_SMOOTHNESS : float = 2.0 # Smoothing for manual camera rotation


func _ready() -> void:
	if cam_parent.get_parent().is_truck: # Check if our Vehicle is truck type
		self.position = Vector3(0, 3.0, 0) # Rise our camera a bit for better visiblity
		self.get_child(0).rotation_degrees.x = -15 # Angle our camera a bit for better visiblity

func _physics_process(delta: float) -> void:
	var vehicle = cam_parent.get_parent() # Reference to our vehicle itself

	# Detect reverse movement
	var velocity = vehicle.get_linear_velocity() # Gets vehicle velocity
	velocity.y = 0 # We don't care about Y movement soo keep it 0
	var forward_dir = vehicle.global_transform.basis.z # Gets the direction of the vehicle, always make it towards +Z
	var moving_reverse = forward_dir.dot(velocity) < -1  # dot < -1 = moving forward, -1 is here to prevent camera seizures when on handbrake
	

	# Input for Orbital camera movement "Applies only for behind cams"
	if current_cam != 2: # Ignore if camer is placed on the hood
		var look_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) # Rotates camera along X axis
		var look_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y) # Rotates camera along Y axis
		if invert_cam_y:
			look_y = -look_y
		# Same as Above but allows to use Numpad keys to rotate camera if one dont have joypad
		look_x += int(Input.is_action_pressed("Camera Right")) - int(Input.is_action_pressed("Camera Left"))
		look_y += int(Input.is_action_pressed("Camera Down")) - int(Input.is_action_pressed("Camera Up"))
		
		var has_input = abs(look_x) > 0.05 or abs(look_y) > 0.05 # Small Deadzone, rotate camera only if analogue is tilted


		if has_input: # Checks if we actually try to rotate camera
			time_since_input = 0.0 # Resets our timer while we move our camera
			cam_rot_y -= look_x * orbit_speed * delta # Moves camera
			cam_rot_x -= look_y * orbit_speed * delta
		else:
			time_since_input += delta # Adds to our timer
			if vehicle.veh_speed > abs(1.0):
				if time_since_input > auto_reset_delay: # Counts idle time before reseting angle of our camera
					cam_rot_x = lerp(cam_rot_x, 0.0, auto_reset_speed * delta) # Resets camera angle
					cam_rot_y = lerp(cam_rot_y, 0.0, auto_reset_speed * delta)

		# Clamps X rotation of the camera so we cant flip it more than 20dgr
		cam_rot_x = clamp(cam_rot_x, deg_to_rad(-cam_angle_limit), deg_to_rad(cam_angle_limit))

		# Flips the camera rotation if driving in reverse
		var target_y = cam_rot_y 
		if moving_reverse: # Compares if we move in reverse or not
			target_y += PI  # Flips 180° in radians
		cam_current_y = lerp_angle(cam_current_y, target_y, orbit_smoothness * delta) # Flips camera 180° relative to the camera orientation itself

		# Smoothing X rotation of camera
		cam_current_x = lerp(cam_current_x, cam_rot_x, X_SMOOTHNESS * delta)

		# Now we apply our rotation to our camera, We dont rotate cam itself only a Node3D
		var rot = cam_holder.rotation_degrees # We take current camera rotation
		rot.x = rad_to_deg(cam_current_x) # We change X and Y rotation of our camera and convert it from radiants to degrees
		rot.y = rad_to_deg(cam_current_y)
		rot.z = 0 # We set Z axis as 0 cuz we don't need to rotate it
		cam_holder.rotation_degrees = rot # Apply rotation to camera holder
		
		# Anchor rotation: make it rotate with the car independentaly to our manual camera rotation
		var current_rot = cam_parent.rotation

		# We take rotation of our vehicle
		var target_gy = vehicle.global_rotation.y

		# Calculate shortest angular difference between Camera Anchor and Vehicle in -180 to 180dgr
		var delta_y = wrapf(target_gy - current_rot.y, -PI, PI)

		# Let's clamp rotation soo it does not rotate 360dgr when we drive in circle
		var max_diff = deg_to_rad(cam_angle_limit) # 20dgr is enough
		delta_y = clamp(delta_y, -max_diff, max_diff) # We clamp the angle to be 20dgr relative to vehicle angle

		# Smoothing out camera soo it moves smooth
		current_rot.y += delta_y * 0.1  # We adjust it to be smooth
		cam_parent.rotation = current_rot # Apply rotation to the camera

		# Keep the chase camera LEVEL on banks and slopes. The anchor
		# copies the car's full transform via RemoteTransform3D, so
		# on banked track (Attic) and slopes (Mini Golf) it inherits
		# the car's roll and the whole frame goes diagonal. The anchor
		# is top_level, so its rotation IS the world rotation: zero
		# the world roll/pitch here, yaw keeps following the car above.
		# (Belt and braces below: the holder's own world roll is also
		# forced to 0, so the camera stays level even if the remote
		# transform re-applies the car's roll after this runs.)
		cam_parent.rotation.x = 0.0
		cam_parent.rotation.z = 0.0
		# Force the camera holder's WORLD roll to 0. Its local roll is
		# set to 0 above, but that is relative to the (rolled) anchor;
		# this keeps the forward direction exactly (rolling around the
		# view axis never changes it) and only levels the horizon.
		var holder_global := global_rotation
		global_rotation = Vector3(holder_global.x, holder_global.y, 0.0)
		
# We run this on input event
# This is here to change cameras
func _input(event):
	if event.is_action_pressed("Camera Change"): # Run function when camera switch button is pressed
		switch_camera()

func switch_camera():
	current_cam = (current_cam + 1) % 3 # Clamp numper of cameras between 0 - 2

	match current_cam: # Match our Camera ID with specific setup
		0:
			cam_position.rotation_degrees.x = 0.0 # We set rotation for our camera target to keep it default, this cant be global or it will take parent rotation and add it up
			camera.reparent(cam_arm) # We reparent camera back to spring arm
			cam_arm.spring_length = 8.0 # Chase cam sits 8m back so the whole car is visible
			camera.rotation_degrees.x = 0.0 # We reset camera angle for each axis just in case
			camera.rotation_degrees.y = 0.0
			camera.rotation_degrees.z = 0.0
			if cam_parent.get_parent().is_truck: # Updates camer for trucks types to be consisten
				self.position = Vector3(0, 3.0, 0)
				self.get_child(0).rotation_degrees.x = -15
			
		1:
			cam_position.rotation_degrees.x = 7.5 # Same here we tilt camera position to be a bit lower and closer
			cam_arm.spring_length = 8.0 # Chase cam sits 8m back so the whole car is visible
			if cam_parent.get_parent().is_truck: # Updates camer for trucks types to be consisten
				self.position = Vector3(0, 2.0, 0)
				self.get_child(0).rotation_degrees.x = -15
			if hood == null: # We check if our car have hood cam and if not just skip back to first cam position
				current_cam = -1
			
		2:
			camera.reparent(hood) # Parent camera to the hood marker
			camera.global_position = hood.global_position # Sets position of camera to hood marker
			camera.rotation_degrees.x = hood.rotation_degrees.x # Resets camera degrees to face forward
			camera.rotation_degrees.y = 180.0 # Flips camera, otherwise it will be facing the windshield
			camera.rotation_degrees.z = 0.0
