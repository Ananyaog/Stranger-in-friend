extends CharacterBody3D

# --- Motorbike Specs ---
@export var MAX_SPEED: float = 12.0
@export var ACCELERATION: float = 1.8 # Gradual realistic speed buildup
@export var STEERING_SPEED: float = 1.4 # Smooth turn radius
@export var DECELERATION: float = 2.0 # Realistic momentum gliding
@export var FUEL_CONSUMPTION_RATE: float = 1.8 # Percent per second when throttle is down

var fuel: float = 100.0
var refuel_cost_accumulator: float = 0.0
var is_ridden: bool = false
var player_ref: CharacterBody3D = null

# --- Nodes Reference ---
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var dashboard_arrow: Node3D = $Dashboard/CompassArrow
@onready var headlight: SpotLight3D = $Headlight
@onready var ignition_audio: AudioStreamPlayer3D = $Audio/IgnitionPlayer
@onready var engine_audio: AudioStreamPlayer3D = $Audio/EnginePlayer
@onready var interactive_body: StaticBody3D = $MotorbikeBody

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _input(event: InputEvent) -> void:
	if is_ridden and event.is_action_pressed("interact"):
		dismount_player()

func _ready() -> void:
	# Bike starts idle
	if camera:
		camera.current = false
	if headlight:
		headlight.visible = true # Always on headlight for evening safety
	_update_audio()

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not is_ridden:
		# Slow down naturally if unridden
		velocity.x = lerp(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, DECELERATION * delta)
		move_and_slide()
		return

	# --- GAS STATION REFUEL ZONE CHECK ---
	var pump_pos = Vector3(32.7945, global_position.y, -11.5766)
	var world_scene = get_tree().current_scene
	if world_scene:
		var gas_station = world_scene.get_node_or_null("Geometry/GasStation")
		if gas_station:
			pump_pos = gas_station.global_position
			pump_pos.y = global_position.y
	
	var distance_to_pump = global_position.distance_to(pump_pos)
	var in_refuel_zone = distance_to_pump < 4.0
	
	if in_refuel_zone:
		if player_ref and player_ref.prompt_label:
			if Input.is_action_pressed("sprint"):
				if fuel < 100.0:
					var fuel_to_add = 25.0 * delta
					var added_cost = fuel_to_add * 0.50 # $0.50 per 1% fuel ($5 per 10%)
					if DeliveryManager.cash > 0 or refuel_cost_accumulator >= 1.0:
						fuel = min(100.0, fuel + fuel_to_add)
						refuel_cost_accumulator += added_cost
						if refuel_cost_accumulator >= 1.0:
							var dollars_to_deduct = floor(refuel_cost_accumulator)
							DeliveryManager.cash = max(0, DeliveryManager.cash - int(dollars_to_deduct))
							refuel_cost_accumulator -= dollars_to_deduct
							DeliveryManager.cash_changed.emit(DeliveryManager.cash)
						player_ref.prompt_label.text = "[Refueling...] Fuel: " + str(floor(fuel)) + "% (Cost: $0.50/%)"
					else:
						player_ref.prompt_label.text = "NOT ENOUGH CASH! Requires $0.50 per 1% fuel."
				else:
					player_ref.prompt_label.text = "FUEL TANK FULL!"
			else:
				player_ref.prompt_label.text = "[Refuel Zone] Hold [SHIFT] to Refuel ($0.50/%)"
			player_ref.prompt_label.visible = true
			if player_ref.crosshair:
				player_ref.crosshair.color = Color(0.2, 0.9, 0.2, 0.8)
	else:
		if player_ref and player_ref.prompt_label and player_ref.prompt_label.text.begins_with("[Refuel"):
			player_ref.prompt_label.text = ""
			player_ref.prompt_label.visible = false

	# --- RIDING CONTROLS (WASD) ---
	var throttle = 0.0
	if fuel > 0.0:
		if Input.is_action_pressed("move_forward"):
			throttle = 1.0
		elif Input.is_action_pressed("move_backward"):
			throttle = -0.5 # Reverse speed

	# Handle Steering
	var steer = 0.0
	if Input.is_action_pressed("move_left"):
		steer = 1.0
	elif Input.is_action_pressed("move_right"):
		steer = -1.0

	# Rotate bike based on steering and movement
	var actual_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	if actual_speed > 0.5 or throttle != 0.0:
		# Direction of steering reverses if going backward
		var steer_direction = steer if throttle >= 0.0 else -steer
		rotate_y(steer_direction * STEERING_SPEED * delta)

	# Fuel consumption
	if throttle != 0.0 and fuel > 0.0:
		fuel = max(0.0, fuel - FUEL_CONSUMPTION_RATE * delta)
		if fuel <= 0.0:
			throttle = 0.0
			DeliveryManager.notify("OUT OF FUEL", "Your bike sputtered to a halt. Retrieve fuel canisters from the station.")

	# Calculate speed
	var forward_dir = -transform.basis.z
	var target_vel = forward_dir * throttle * MAX_SPEED
	
	# Realistic braking / progressive acceleration
	var current_accel = ACCELERATION
	var moving_forward = Vector3(velocity.x, 0.0, velocity.z).dot(forward_dir) > 0.1
	var moving_backward = Vector3(velocity.x, 0.0, velocity.z).dot(forward_dir) < -0.1
	
	if (throttle < 0.0 and moving_forward) or (throttle > 0.0 and moving_backward):
		current_accel = 5.0 # Hard braking deceleration
		
	velocity.x = lerp(velocity.x, target_vel.x, current_accel * delta)
	velocity.z = lerp(velocity.z, target_vel.z, current_accel * delta)

	move_and_slide()
	_update_audio()

	# --- Dynamic Dashboard Waypoint Compass ---
	if dashboard_arrow and is_instance_valid(DeliveryManager.active_target_node):
		var target_pos = DeliveryManager.active_target_node.global_position
		var local_target = dashboard_arrow.to_local(target_pos)
		local_target.y = 0.0 # Flatten axis
		if local_target.length() > 0.1:
			var angle = atan2(-local_target.x, -local_target.z)
			dashboard_arrow.rotation.y = lerp_angle(dashboard_arrow.rotation.y, angle, delta * 6.0)

# --- Bike Interactions ---
func mount_player(player: CharacterBody3D) -> void:
	if is_ridden:
		return
		
	# Bike requires key to start
	if not Inventory.has_item_type("key"):
		DeliveryManager.notify("NO KEY", "You need your Motorbike Key in inventory to start the engine.")
		return

	is_ridden = true
	player_ref = player
	
	# Disable player physics collision and hide
	player.is_mounted = true
	player.current_motorbike = self
	player.visible = false
	player.process_mode = PROCESS_MODE_DISABLED # Pauses player physics while riding
	
	# Switch camera to bike third-person
	if camera:
		camera.current = true
		
	if ignition_audio:
		ignition_audio.play()
		
	DeliveryManager.notify("IGNITION STARTED", "WASD to Drive. Press [E] to Dismount.")

func dismount_player() -> void:
	if not is_ridden or not player_ref:
		return

	is_ridden = false
	
	# Un-hide player and enable physics
	player_ref.is_mounted = false
	player_ref.current_motorbike = null
	player_ref.visible = true
	player_ref.process_mode = PROCESS_MODE_INHERIT
	
	# Spawn player slightly to the left of the bike, level with floor
	var left_dir = -transform.basis.x
	player_ref.global_position = global_position + left_dir * 1.2 + Vector3(0, 0.2, 0)
	player_ref.global_rotation.y = global_rotation.y # Sync rotation
	
	# Switch camera back to player FPV
	player_ref.camera.current = true
	player_ref = null
	
	_update_audio()
	DeliveryManager.notify("DISMOUNTED", "Walking freely.")

func refuel() -> void:
	if Inventory.remove_item_by_type("fuel"):
		fuel = min(100.0, fuel + 45.0)
		DeliveryManager.notify("MOTORBIKE REFUELLED", "Refilled tank by 45%. Fuel Level: " + str(floor(fuel)) + "%")
	else:
		DeliveryManager.notify("NO FUEL IN HAND", "Equip a Fuel Canister first!")

func _update_audio() -> void:
	# Simulate basic engine humming
	if is_ridden and fuel > 0.0:
		if not engine_audio.playing:
			engine_audio.play()
		var speed_percent = Vector3(velocity.x, 0.0, velocity.z).length() / MAX_SPEED
		engine_audio.pitch_scale = lerp(0.8, 1.6, speed_percent)
	else:
		if engine_audio.playing:
			engine_audio.stop()


