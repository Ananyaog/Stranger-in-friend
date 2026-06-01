extends Interactable

func _ready() -> void:
	prompt_message = "Press [E] to Ride Motorbike"

func interact(player: CharacterBody3D) -> void:
	var parent_bike = get_parent()
	if parent_bike and parent_bike.has_method("mount_player"):
		parent_bike.mount_player(player)
