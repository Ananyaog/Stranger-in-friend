extends Interactable

func _ready() -> void:
	prompt_message = "Press [E] to Buy Fuel Canister ($20)"

func interact(_player: CharacterBody3D) -> void:
	var cost = 20
	if DeliveryManager.cash < cost:
		DeliveryManager.notify("INSUFFICIENT CASH", "A Fuel Canister costs $" + str(cost) + ". Deliver more parcels to earn cash!")
		return
		
	# Check if player has space in inventory
	if Inventory.add_item("Fuel Canister", "fuel"):
		DeliveryManager.cash -= cost
		DeliveryManager.cash_changed.emit(DeliveryManager.cash)
		DeliveryManager.notify("CANISTER PURCHASED", "Purchased Fuel Canister for $" + str(cost) + ".")
	else:
		DeliveryManager.notify("INVENTORY FULL", "No slots available! Free up space to carry fuel.")
