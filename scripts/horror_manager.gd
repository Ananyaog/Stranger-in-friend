extends Node

@export var shadow_stalker_scene: PackedScene = null

var world_env: WorldEnvironment = null
var streetlights: Array = []
var active_stalker: Node3D = null

# Spooky spawn coordinates (alleyways, house corners, side roads)
var spawn_points: Array = [
	Vector3(-4.5, 0.0, -12.5),
	Vector3(12.0, 0.0, -4.5),
	Vector3(-14.0, 0.0, 5.0),
	Vector3(15.0, 0.0, 16.0),
	Vector3(-2.0, 0.0, 19.5)
]

func _ready() -> void:
	var world = get_parent()
	if world:
		world_env = world.get_node_or_null("WorldEnvironment")
		
	# Connect to Delivery Manager triggers
	DeliveryManager.delivery_status_changed.connect(_on_delivery_status_changed)
	DeliveryManager.new_day_started.connect(_on_new_day_started)
	
	# Scan for streetlights deferred
	call_deferred("_gather_streetlights")

func _gather_streetlights() -> void:
	var world = get_parent()
	if world:
		var lighting = world.get_node_or_null("Lighting")
		if lighting:
			for child in lighting.get_children():
				if child.name.begins_with("Streetlight"):
					streetlights.append(child)
	print("[HorrorManager] Registered ", streetlights.size(), " streetlights for flicker events.")

func _on_new_day_started(day_num: int) -> void:
	# Keep fog at a moderate level for good visibility
	if world_env and world_env.environment:
		var env = world_env.environment
		
		var fog_multiplier = 0.015 + (day_num - 1) * 0.005
		env.volumetric_fog_density = min(0.03, fog_multiplier)
		
		# Maintain bright evening colors (warm twilight / dusk ambient)
		var r = max(0.2, 0.35 - (day_num - 1) * 0.03)
		var g = max(0.15, 0.25 - (day_num - 1) * 0.03)
		var b = max(0.25, 0.4 - (day_num - 1) * 0.04)
		env.ambient_light_color = Color(r, g, b, 1.0)
		
		print("[HorrorManager] Shift Atmosphere Advanced. Fog Density: ", env.volumetric_fog_density)

func _on_delivery_status_changed(delivered: int, total: int) -> void:
	if delivered == 0:
		return
		
	# Trigger spooky events at delivery milestones
	if delivered == 1:
		flicker_random_streetlight()
	
		# Double flicker event
		flicker_random_streetlight()
		# Add a delay and flicker another
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(flicker_random_streetlight)


func flicker_random_streetlight() -> void:
	if streetlights.size() == 0:
		return
		
	streetlights.shuffle()
	var selected_light = streetlights[0]
	
	# Find the OmniLight3D inside the selected streetlight structure
	var light_node = selected_light.get_node_or_null("OmniLight3D")
	if not light_node:
		# Fallback to search child nodes
		for child in selected_light.get_children():
			if child is OmniLight3D:
				light_node = child
				break
				
	if light_node:
		var flicker_tween = create_tween()
		# Rapid flickering sequence
		flicker_tween.tween_callback(func(): light_node.visible = false)
		flicker_tween.tween_interval(0.1)
		flicker_tween.tween_callback(func(): light_node.visible = true)
		flicker_tween.tween_interval(0.2)
		flicker_tween.tween_callback(func(): light_node.visible = false)
		flicker_tween.tween_interval(0.1)
		flicker_tween.tween_callback(func(): light_node.visible = true)
		flicker_tween.tween_interval(0.3)
		# Sputter out completely
		flicker_tween.tween_callback(func(): 
			light_node.visible = false
		)

func spawn_stalker() -> void:
	# Avoid spawning duplicate active stalkers
	if is_instance_valid(active_stalker):
		active_stalker.queue_free()
		
	if not shadow_stalker_scene:
		return
		
	# Pick a random spawn coordinate
	spawn_points.shuffle()
	var spawn_pos = spawn_points[0]
	
	# Verify player is not looking directly at that spawn point before placing it
	var world = get_parent()
	var player = world.get_node_or_null("Player")
	if player:
		# If spawn point is too close, pick another
		var dist = player.global_position.distance_to(spawn_pos)
		if dist < 10.0:
			spawn_pos = spawn_points[1]
			
	# Instance shadow figure
	active_stalker = shadow_stalker_scene.instantiate()
	active_stalker.global_position = spawn_pos
	world.add_child(active_stalker)
	print("[HorrorManager] Shadow Stalker spawned at: ", spawn_pos)
