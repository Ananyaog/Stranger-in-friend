class_name Interactable
extends CollisionObject3D

## The message shown in the player HUD when aiming at this object.
@export var prompt_message: String = "Interact"

## Returns the customized message shown on screen.
func get_prompt() -> String:
	return prompt_message

## Virtual method to be overridden by custom interactable objects.
## The player node is passed in to allow reference of player-specific states if needed.
func interact(_player: CharacterBody3D) -> void:
	print("Interacted with base Interactable node: ", name)
