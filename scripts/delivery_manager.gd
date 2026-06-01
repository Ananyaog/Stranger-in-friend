extends Node

signal delivery_status_changed(delivered: int, total: int)
signal cash_changed(amount: int)
signal new_day_started(day_num: int)
signal shift_completed(earnings: int)
signal notification_posted(text: String, subtext: String)

var current_day: int = 1
var cash: int = 0
var packages_delivered_today: int = 0
var total_packages_today: int = 4
var total_packages_delivered: int = 0
var active_delivery_house_name: String = ""

var delivery_targets: Array = []
var active_target_node: Node3D = null

func start_new_shift() -> void:
	packages_delivered_today = 0
	total_packages_today = 4
	delivery_targets.clear()
	active_target_node = null
	
	while Inventory.remove_item_by_type("parcel"):
		pass
	
	if not Inventory.has_item_type("key"):
		Inventory.add_item("Motorbike Key", "key")
	
	# Inventory has 5 slots: Key + Flashlight = 2 used, so give 3 parcels initially
	for i in range(3):
		Inventory.add_item("Parcel #" + str(i + 1), "parcel")
		
	delivery_status_changed.emit(packages_delivered_today, total_packages_today)
	new_day_started.emit(current_day)
	call_deferred("_assign_initial_targets")
	notify("SHIFT STARTED", "Deliver 4 parcels tonight.")

func _assign_initial_targets() -> void:
	var world = get_tree().current_scene
	if not world:
		return
	var geometry = world.get_node_or_null("Geometry")
	if not geometry:
		return
		
	var houses = []
	for child in geometry.get_children():
		if child.name.begins_with("House") and child.has_node("DoorstepPoint"):
			var doorstep = child.get_node("DoorstepPoint")
			doorstep.reset_state()
			houses.append(doorstep)
				
	if houses.size() > 0:
		houses.shuffle()
		var target_count = min(total_packages_today, houses.size())
		for i in range(target_count):
			var doorstep = houses[i]
			delivery_targets.append(doorstep)
			doorstep.is_active_delivery = true
			doorstep.update_waypoint_visibility()
		_update_active_waypoint()
	else:
		print("[DeliveryManager] Warning: No houses with DoorstepPoint found!")

func _update_active_waypoint() -> void:
	var active_targets = []
	for target in delivery_targets:
		if is_instance_valid(target) and target.is_active_delivery and not target.is_delivered:
			active_targets.append(target)
			
	if active_targets.size() > 0:
		active_target_node = active_targets[0]
		var house = active_target_node.get_parent()
		active_delivery_house_name = house.name
		active_target_node.set_waypoint_glowing(true)
	else:
		active_target_node = null
		active_delivery_house_name = "None"
		
	delivery_status_changed.emit(packages_delivered_today, total_packages_today)

func deliver_package(doorstep_node: Node3D) -> void:
	if doorstep_node != active_target_node:
		notify("WRONG HOUSE", "This doorstep does not require a parcel drop-off.")
		return
	
	if not Inventory.has_item_type("parcel"):
		notify("NO PARCEL", "You don't have a package in your inventory!")
		return
		
	if not Inventory.remove_item_by_type("parcel"):
		return
		
	doorstep_node.is_delivered = true
	doorstep_node.is_active_delivery = false
	doorstep_node.set_waypoint_glowing(false)
	doorstep_node.update_waypoint_visibility()
	
	packages_delivered_today += 1
	total_packages_delivered += 1
	var reward = 85
	cash += reward
	
	cash_changed.emit(cash)
	notify("PARCEL DELIVERED", "+$" + str(reward) + " added to paycheck.")
	_update_active_waypoint()
	
	# Auto-replenish: if parcels remain to deliver but inventory is empty, load next parcel
	var remaining = total_packages_today - packages_delivered_today
	if remaining > 0 and Inventory.count_item_type("parcel") == 0:
		Inventory.add_item("Parcel #" + str(packages_delivered_today + 1), "parcel")
		notify("PARCEL LOADED", "Next package equipped from rack.")
	
	if packages_delivered_today >= total_packages_today:
		call_deferred("_complete_shift")

func _complete_shift() -> void:
	shift_completed.emit(cash)
	
	if total_packages_delivered >= 8:
		notify("ALL DELIVERIES COMPLETE", "Heading home for the night...")
		_fade_and_transition("res://scenes/cozy_house.tscn", 3.0)
	else:
		notify("SHIFT COMPLETED", "New shift starting...")
		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			current_day += 1
			start_new_shift()
		)

func _fade_and_transition(target_scene: String, duration: float) -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		for child in get_tree().current_scene.get_children():
			if child is CharacterBody3D:
				player = child
				break
	
	var fade_overlay: ColorRect = null
	if player:
		fade_overlay = player.get_node_or_null("HUD/FadeOverlay")
		player.is_mounted = true
	
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 0)
		var tween = get_tree().create_tween()
		tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), duration)
		tween.tween_callback(func():
			get_tree().change_scene_to_file(target_scene)
		)
	else:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func():
			get_tree().change_scene_to_file(target_scene)
		)

func notify(text: String, subtext: String) -> void:
	notification_posted.emit(text, subtext)
	print("[Notification] ", text, " - ", subtext)
