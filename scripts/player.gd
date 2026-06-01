extends CharacterBody3D

# --- Movement Parameters ---
@export var WALK_SPEED: float = 3.5
@export var SPRINT_SPEED: float = 6.0
@export var JUMP_VELOCITY: float = 4.0
@export var ACCELERATION: float = 8.0
@export var DECELERATION: float = 12.0
@export var MOUSE_SENSITIVITY: float = 0.002

# --- Camera Bobbing ---
@export var BOB_FREQUENCY: float = 2.0
@export var BOB_AMPLITUDE: float = 0.05
var t_bob: float = 0.0

# --- FOV Dynamic Effects ---
@export var BASE_FOV: float = 75.0
@export var SPRINT_FOV: float = 82.0
@export var FOV_LERP_SPEED: float = 8.0

# --- Nodes Reference ---
@onready var neck: Node3D = get_node_or_null("Neck")
@onready var camera: Camera3D = get_node_or_null("Neck/Camera3D")
@onready var raycast: RayCast3D = get_node_or_null("Neck/Camera3D/RayCast3D")
@onready var flashlight: SpotLight3D = get_node_or_null("Neck/Camera3D/Flashlight")

# HUD Elements
@onready var prompt_label: Label = get_node_or_null("HUD/PromptContainer/PromptLabel")
@onready var crosshair: ColorRect = get_node_or_null("HUD/CenterContainer/Crosshair")
@onready var gas_value_label: Label = get_node_or_null("HUD/TopLeftContainer/MarginContainer/VBoxContainer/GasInfo/Value")
@onready var parcel_value_label: Label = get_node_or_null("HUD/TopLeftContainer/MarginContainer/VBoxContainer/ParcelInfo/Value")
@onready var cash_value_label: Label = get_node_or_null("HUD/TopLeftContainer/MarginContainer/VBoxContainer/CashInfo/Value")
@onready var day_value_label: Label = get_node_or_null("HUD/TopLeftContainer/MarginContainer/VBoxContainer/DayInfo/Value")
@onready var notification_panel: PanelContainer = get_node_or_null("HUD/NotificationPanel")
@onready var notification_title: Label = get_node_or_null("HUD/NotificationPanel/Margin/VBox/Title")
@onready var notification_subtitle: Label = get_node_or_null("HUD/NotificationPanel/Margin/VBox/Subtitle")
@onready var hotbar_slots: HBoxContainer = get_node_or_null("HUD/HotbarPanel/Margin/SlotsContainer")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_default_pos: Vector3
var is_cursor_locked: bool = true
var is_mounted: bool = false
var current_motorbike: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_default_pos = camera.position if camera else Vector3.ZERO
	
	if prompt_label:
		prompt_label.text = ""
		prompt_label.visible = false
		
	# Hide notification panel on start
	if notification_panel:
		notification_panel.visible = false
		
	# Connect Delivery Manager signals (safely disconnect first to avoid duplicates after scene changes)
	if DeliveryManager.delivery_status_changed.is_connected(_on_delivery_status_changed):
		DeliveryManager.delivery_status_changed.disconnect(_on_delivery_status_changed)
	if DeliveryManager.cash_changed.is_connected(_on_cash_changed):
		DeliveryManager.cash_changed.disconnect(_on_cash_changed)
	if DeliveryManager.new_day_started.is_connected(_on_new_day_started):
		DeliveryManager.new_day_started.disconnect(_on_new_day_started)
	if DeliveryManager.notification_posted.is_connected(_show_notification):
		DeliveryManager.notification_posted.disconnect(_show_notification)
	
	DeliveryManager.delivery_status_changed.connect(_on_delivery_status_changed)
	DeliveryManager.cash_changed.connect(_on_cash_changed)
	DeliveryManager.new_day_started.connect(_on_new_day_started)
	DeliveryManager.notification_posted.connect(_show_notification)
	
	# Connect Inventory signals
	if Inventory.inventory_changed.is_connected(_on_inventory_changed):
		Inventory.inventory_changed.disconnect(_on_inventory_changed)
	Inventory.inventory_changed.connect(_on_inventory_changed)
	
	# Only start the delivery shift sequence if we are actually in the main World scene!
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "World":
		# Set up default items on startup (Key, parcels, flashlight)
		Inventory.add_item("Motorbike Key", "key")
		Inventory.add_item("Flashlight", "flashlight")
		
		# Start initial shift
		DeliveryManager.start_new_shift()
		_on_inventory_changed()

func _input(event: InputEvent) -> void:
	if is_mounted:
		# If mounted, the motorbike script handles mouse steering or player can dismount
		if event.is_action_pressed("interact") and current_motorbike:
			current_motorbike.dismount_player()
		return

	# Recapture mouse focus automatically when clicking the game window
	if event is InputEventMouseButton and event.pressed:
		if not is_cursor_locked:
			is_cursor_locked = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Handle mouse look
	if is_cursor_locked and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		neck.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
		
	# Toggle mouse lock with Escape key
	if event.is_action_pressed("toggle_cursor"):
		is_cursor_locked = not is_cursor_locked
		if is_cursor_locked:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Inventory Slot selection (Keys 1 to 5)
	for i in range(5):
		if event.is_action_pressed("slot_" + str(i + 1)):
			Inventory.select_slot(i)

func _physics_process(delta: float) -> void:
	if is_mounted:
		# Keep player locked in position to motorbike
		if current_motorbike:
			global_position = current_motorbike.global_position + Vector3(0, 0.4, 0)
			# Sync gas levels UI with dynamic consumption
			var is_throttling = (Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward")) and current_motorbike.fuel > 0.0
			var rate = current_motorbike.FUEL_CONSUMPTION_RATE if is_throttling else 0.0
			_update_gas_ui(current_motorbike.fuel, rate)
		return

	# Update gas level from the world's motorbike node if available
	var world = get_parent()
	if world:
		var bike = world.get_node_or_null("Motorbike")
		if bike:
			_update_gas_ui(bike.fuel, 0.0)

	# --- Keyboard Arrow Camera Turn Bypass (Trackpad Workaround) ---
	var kb_look := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		kb_look.x = -1.0
	elif Input.is_key_pressed(KEY_RIGHT):
		kb_look.x = 1.0
	if Input.is_key_pressed(KEY_UP):
		kb_look.y = -1.0
	elif Input.is_key_pressed(KEY_DOWN):
		kb_look.y = 1.0
		
	if kb_look != Vector2.ZERO:
		var kb_sensitivity = 1.6 # Speed of keyboard camera rotation
		rotate_y(-kb_look.x * kb_sensitivity * delta)
		neck.rotate_x(-kb_look.y * kb_sensitivity * delta)
		neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

	# Normal first-person movement
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Toggle Flashlight (Must possess the Flashlight item in inventory)
	if Input.is_action_just_pressed("flashlight"):
		if Inventory.has_item_type("flashlight"):
			if not is_instance_valid(flashlight):
				flashlight = get_node_or_null("Neck/Camera3D/Flashlight")
			
			if is_instance_valid(flashlight):
				flashlight.visible = not flashlight.visible
				print("[Player] Flashlight toggled: ", "ON" if flashlight.visible else "OFF")
			else:
				print("[Player] Flashlight node not found or invalid in scene tree.")
				DeliveryManager.notify("FLASHLIGHT FAULT", "Flashlight hardware is unavailable.")
		else:
			DeliveryManager.notify("NO FLASHLIGHT", "You must carry the Flashlight item in inventory!")

	# Gather input directions
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine if sprinting (Shift)
	var is_sprinting := Input.is_action_pressed("sprint") and input_dir.y < -0.1
	var current_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
	
	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = lerp(velocity.z, 0.0, DECELERATION * delta)

	move_and_slide()
	
	# --- Dynamic FOV Adjustment ---
	if camera:
		var target_fov = SPRINT_FOV if (is_sprinting and direction != Vector3.ZERO) else BASE_FOV
		camera.fov = lerp(camera.fov, target_fov, FOV_LERP_SPEED * delta)

	# --- Organic Camera Bobbing ---
	if camera:
		if is_on_floor() and direction != Vector3.ZERO and velocity.length() > 0.5:
			t_bob += delta * velocity.length() * BOB_FREQUENCY
			var bob_offset = Vector3.ZERO
			bob_offset.y = sin(t_bob) * BOB_AMPLITUDE
			bob_offset.x = cos(t_bob * 0.5) * BOB_AMPLITUDE * 0.4
			camera.position = camera_default_pos + bob_offset
		else:
			t_bob = 0.0
			camera.position = camera.position.lerp(camera_default_pos, delta * 10.0)

	# --- Interaction Processing ---
	_process_interaction()

func _process_interaction() -> void:
	if not raycast:
		return
		
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		if collider is Interactable:
			var prompt_msg = collider.get_prompt()
			
			# Bike specific interaction checks
			if collider.name == "MotorbikeBody" or collider.name.contains("Motorbike"):
				if not Inventory.has_item_type("key"):
					prompt_label.text = "[Locked] Requires Motorbike Key"
					prompt_label.visible = true
					crosshair.color = Color(0.9, 0.2, 0.2, 0.8) # Red lock
					return
				else:
					# If carrying fuel canister, show refuel prompt
					var active_item = Inventory.get_active_item()
					if active_item != {} and active_item["type"] == "fuel":
						prompt_label.text = "Press [E] to Refuel Motorbike"
						prompt_label.visible = true
						crosshair.color = Color(0.2, 0.9, 0.2, 0.8)
						
						if Input.is_action_just_pressed("interact"):
							var bike = collider.get_parent()
							if bike.has_method("refuel"):
								bike.refuel()
						return
			
			prompt_label.text = prompt_msg
			prompt_label.visible = true
			crosshair.color = Color(0.2, 0.9, 0.2, 0.8) # Active Green
			
			if Input.is_action_just_pressed("interact"):
				collider.interact(self)
			return
			
	# Default state
	prompt_label.visible = false
	crosshair.color = Color(1.0, 1.0, 1.0, 0.4) # Faded white

# --- Signals and UI Updates ---
func _on_delivery_status_changed(delivered: int, total: int) -> void:
	if parcel_value_label:
		var remaining = max(0, total - delivered)
		parcel_value_label.text = str(remaining) + " Parcels Left"

func _on_cash_changed(amount: int) -> void:
	if cash_value_label:
		cash_value_label.text = "$" + str(amount)

func _on_new_day_started(day_num: int) -> void:
	if day_value_label:
		day_value_label.text = "Day " + str(day_num)

func _update_gas_ui(fuel_percent: float, consumption_rate: float = 0.0) -> void:
	if gas_value_label:
		if consumption_rate > 0.0:
			gas_value_label.text = str(floor(fuel_percent)) + "% Fuel (-" + str(consumption_rate) + "/s)"
		else:
			gas_value_label.text = str(floor(fuel_percent)) + "% Fuel (Stable)"

func _show_notification(title_text: String, subtitle_text: String) -> void:
	if notification_panel:
		notification_title.text = title_text
		notification_subtitle.text = subtitle_text
		notification_panel.visible = true
		
		# Auto-hide notification banner after 3 seconds
		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			notification_panel.visible = false
		)

func _on_inventory_changed() -> void:
	if not hotbar_slots:
		return
		
	# Repopulate hotbar cells
	for slot_idx in range(5):
		var slot_node = hotbar_slots.get_child(slot_idx)
		var label_node = slot_node.get_node("Label")
		var selection_border = slot_node.get_node_or_null("Border")
		
		var item = Inventory.slots[slot_idx]
		if item != null:
			label_node.text = item["name"]
			slot_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			label_node.text = "[ Empty ]"
			slot_node.modulate = Color(1.0, 1.0, 1.0, 0.4)
			
		# Highlight active selected slot
		if selection_border:
			selection_border.visible = (slot_idx == Inventory.active_slot_index)
