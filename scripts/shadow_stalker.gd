extends Area3D

@export var dissolve_distance: float = 6.0
var player: CharacterBody3D = null
var is_dissolving: bool = false

@onready var whisper_audio: AudioStreamPlayer3D = $WhisperPlayer
@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	# Find player
	var world = get_tree().current_scene
	if world:
		player = world.get_node_or_null("Player")

func _process(delta: float) -> void:
	if is_dissolving or not is_instance_valid(player):
		return
		
	# Look at the player horizontally (billboard effect)
	var look_pos = player.global_position
	look_pos.y = global_position.y
	look_at(look_pos, Vector3.UP)
	rotate_y(PI) # Flip sprite back if needed
	
	var dist = global_position.distance_to(player.global_position)
	
	# Trigger dissolve if player gets too close
	if dist < dissolve_distance:
		dissolve()
		return
		
	# Trigger dissolve if caught in player's flashlight beam
	if is_instance_valid(player) and is_instance_valid(player.camera) and "flashlight" in player and is_instance_valid(player.flashlight) and player.flashlight.visible:
		var dir_to_stalker = (global_position - player.camera.global_position).normalized()
		var camera_facing = -player.camera.global_transform.basis.z.normalized()
		var dot = camera_facing.dot(dir_to_stalker)
		
		# 0.95 corresponds to ~18 degrees cone angle
		if dot > 0.95 and dist < 20.0:
			# Verify line of sight to make sure the player actually sees the stalker (not hidden behind a house)
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(
				player.camera.global_position, 
				global_position + Vector3(0, 1.0, 0)
			)
			# Collision mask 1 = environment geometry (house/ground)
			query.collision_mask = 1 
			var result = space_state.intersect_ray(query)
			
			if result.is_empty():
				dissolve()

func dissolve() -> void:
	is_dissolving = true
	
	if whisper_audio:
		whisper_audio.play()
		
	# Dynamic dissolve tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
	
	if sprite:
		# Fade alpha to zero
		tween.tween_property(sprite, "modulate", Color(0, 0, 0, 0), 0.4)
		
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
	
	DeliveryManager.notify("UNSETTLING SHADOW DISRUPTED", "A dark silhouette dissolved in the mist...")
