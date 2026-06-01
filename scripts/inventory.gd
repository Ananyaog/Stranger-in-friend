extends Node

signal inventory_changed

# Fixed 5-slot inventory
var slots: Array = [null, null, null, null, null]
var active_slot_index: int = 0

func add_item(item_name: String, item_type: String) -> bool:
	# Find an empty slot
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = {
				"name": item_name,
				"type": item_type
			}
			inventory_changed.emit()
			print("[Inventory] Added item: ", item_name, " in slot ", i)
			return true
	print("[Inventory] Inventory is full!")
	return false

func remove_item(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < slots.size():
		slots[slot_index] = null
		inventory_changed.emit()

func remove_item_by_type(item_type: String) -> bool:
	for i in range(slots.size()):
		if slots[i] != null and slots[i]["type"] == item_type:
			slots[i] = null
			inventory_changed.emit()
			print("[Inventory] Removed item type: ", item_type)
			return true
	return false

func has_item_type(item_type: String) -> bool:
	for slot in slots:
		if slot != null and slot["type"] == item_type:
			return true
	return false

func count_item_type(item_type: String) -> int:
	var count = 0
	for slot in slots:
		if slot != null and slot["type"] == item_type:
			count += 1
	return count

func get_active_item() -> Dictionary:
	if slots[active_slot_index] != null:
		return slots[active_slot_index]
	return {}

func select_slot(index: int) -> void:
	if index >= 0 and index < slots.size():
		active_slot_index = index
		inventory_changed.emit()
