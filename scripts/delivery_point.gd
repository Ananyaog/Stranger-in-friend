extends Interactable

## References to visual indicators in the 3D world
@export var waypoint_marker: Node3D # Floating waypoint arrow
@export var doorstep_glow: MeshInstance3D # Glowing circle on floor

var is_active_delivery: bool = false
var is_delivered: bool = false

func _ready() -> void:
	prompt_message = "Press [E] to Drop Off Package"
	
	# Generate glowing materials dynamically if not assigned
	if doorstep_glow and doorstep_glow.mesh:
		var pulse_mat = StandardMaterial3D.new()
		pulse_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.6) # Cool translucent orange
		pulse_mat.emission_enabled = true
		pulse_mat.emission = Color(1.0, 0.4, 0.0)
		pulse_mat.emission_energy_multiplier = 2.0
		pulse_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		doorstep_glow.set_surface_override_material(0, pulse_mat)
		
	reset_state()

func reset_state() -> void:
	is_active_delivery = false
	is_delivered = false
	update_waypoint_visibility()
	set_waypoint_glowing(false)

func interact(player: CharacterBody3D) -> void:
	if not is_active_delivery:
		DeliveryManager.notify("NO DELIVERY REQUIRED", "This house did not order a package tonight.")
		return
		
	if is_delivered:
		DeliveryManager.notify("ALREADY DELIVERED", "A parcel has already been placed at this porch.")
		return
		
	# Call DeliveryManager to handle parcel dropoff
	DeliveryManager.deliver_package(self)

func set_waypoint_glowing(glowing: bool) -> void:
	if doorstep_glow:
		doorstep_glow.visible = glowing
		
	# Make the floating marker spin or glow brighter if active
	if waypoint_marker:
		waypoint_marker.visible = is_active_delivery and not is_delivered
		if glowing:
			waypoint_marker.scale = Vector3(1.2, 1.2, 1.2)
		else:
			waypoint_marker.scale = Vector3(1.0, 1.0, 1.0)

func update_waypoint_visibility() -> void:
	var visible_state = is_active_delivery and not is_delivered
	if waypoint_marker:
		waypoint_marker.visible = visible_state
	if doorstep_glow:
		doorstep_glow.visible = visible_state

func _process(delta: float) -> void:
	# Rotate the floating marker dynamically to look premium
	if waypoint_marker and waypoint_marker.visible:
		waypoint_marker.rotate_y(delta * 2.0)
		# Add a gentle vertical float
		waypoint_marker.position.y = 1.8 + sin(Time.get_ticks_msec() * 0.003) * 0.15
