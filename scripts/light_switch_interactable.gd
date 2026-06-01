extends Interactable

## The Light3D node that this switch controls.
@export var target_light: Light3D

## A MeshInstance3D representing the status indicator indicator on the terminal.
@export var status_mesh: MeshInstance3D

## Custom materials (optional). If not set, standard glowing green/red materials are generated dynamically.
@export var active_material: Material
@export var inactive_material: Material

var is_on: bool = true

func _ready() -> void:
	prompt_message = "Press [E] to Toggle Light"
	
	# Create glowing status materials dynamically if not specified in the editor
	if not active_material:
		var green = StandardMaterial3D.new()
		green.albedo_color = Color(0.1, 0.9, 0.1)
		green.emission_enabled = true
		green.emission = Color(0.1, 0.9, 0.1)
		green.emission_energy_multiplier = 2.0
		green.roughness = 0.2
		active_material = green
		
	if not inactive_material:
		var red = StandardMaterial3D.new()
		red.albedo_color = Color(0.9, 0.1, 0.1)
		red.emission_enabled = true
		red.emission = Color(0.9, 0.1, 0.1)
		red.emission_energy_multiplier = 1.0
		red.roughness = 0.2
		inactive_material = red
		
	# Synchronize state on startup
	if target_light:
		target_light.visible = is_on
	_update_visuals()

func interact(_player: CharacterBody3D) -> void:
	is_on = not is_on
	if target_light:
		target_light.visible = is_on
		
	_update_visuals()
	print("[Interaction] Switch toggled by player. Light is now: ", "ON" if is_on else "OFF")

func _update_visuals() -> void:
	if status_mesh:
		var mat = active_material if is_on else inactive_material
		status_mesh.set_surface_override_material(0, mat)
