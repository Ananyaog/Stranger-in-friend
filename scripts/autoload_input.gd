extends Node

func _ready() -> void:
	# Register movement controls
	register_action("move_forward", KEY_W)
	register_action("move_backward", KEY_S)
	register_action("move_left", KEY_A)
	register_action("move_right", KEY_D)
	
	# Action controls
	register_action("sprint", KEY_SHIFT)
	register_action("interact", KEY_E)
	register_action("flashlight", KEY_F)
	register_action("toggle_cursor", KEY_ESCAPE)
	
	# Slot hotbar keys
	register_action("slot_1", KEY_1)
	register_action("slot_2", KEY_2)
	register_action("slot_3", KEY_3)
	register_action("slot_4", KEY_4)
	register_action("slot_5", KEY_5)
	
	print("[InputInitializer] Dynamic input bindings successfully mapped.")

func register_action(action_name: String, keycode: Key) -> void:
	# Add action if it doesn't exist
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	# Verify if key event already exists in this action
	var events = InputMap.action_get_events(action_name)
	var already_mapped = false
	for event in events:
		if event is InputEventKey and event.physical_keycode == keycode:
			already_mapped = true
			break
	
	# Add key event if not mapped
	if not already_mapped:
		var key_event = InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, key_event)
