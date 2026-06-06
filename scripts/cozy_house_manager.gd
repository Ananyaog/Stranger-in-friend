extends Node3D

# ============================================================
# DIALOGUE CONTENT — Replace "Dialogue Here" with your own text
# ============================================================
var intro_dialogues: Array = [
	"After a long tiring day here Im.",  # 1
	"All this just to make it through a decent life",  # 2
	".....",  # 3
	"Should i quit this job ?",  # 4
	"I think i should but.. There's much more competiton out there.",  # 5
	"Some are grinding from their highschools for the job i'll apply for",  # 6
	"Ahh.. Leave it. Anyways, Im not a streamer who can just play and upload to get bundles of bucks... like most of the fat streamer does",  # 7
	"Im no",  # 8
]

var coffee_dialogues: Array = [
	"This house is old but feels much comfortable than those silent streets",  # 1
	"Let's watch some news alongwith this warm and hard coffee",  # 2
	"This should work for me",  # 3
]

var tv_dialogues: Array = [
	"Another creature sighting... people really are seeing something out there.",  # 1
	"Still, missing people aren't exactly something to joke about.",  # 2
	"Eh... probably just another news story. I should finish my coffee.",  # 3
]

var phone_dialogues: Array = [
	"Dialogue Here",  # 1
	"Dialogue Here",  # 2
	"Dialogue Here",  # 3
	"Dialogue Here",  # 4
	"Dialogue Here",  # 5
	"Dialogue Here",  # 6
	"Dialogue Here",  # 7
	"Dialogue Here",  # 8
	"Dialogue Here",  # 9
	"Dialogue Here",  # 10
]

# ============================================================
# GAME PHASES
# ============================================================
enum Phase {
	INTRO_DIALOGUE,
	WAIT_STAND_UP,
	FIND_MILK,
	FIND_COFFEE,
	BOIL_KETTLE_PROMPT,
	KETTLE_DIALOGUE,
	KETTLE_WAITING,
	FIND_CUP,
	WALK_TO_COUCH,
	WATCH_TV_PROMPT,
	TV_DIALOGUE,
	PHONE_RINGING,
	PHONE_DIALOGUE,
	FINAL_TRANSITION
}

var current_phase: int = Phase.INTRO_DIALOGUE

# --- Dialogue State ---
var dialogue_queue: Array = []
var dialogue_index: int = 0
var is_in_dialogue: bool = false

# --- Kettle ---
var is_kettle_boiling: bool = false
var kettle_timer: float = 0.0
var kettle_done: bool = false

var final_scene_started: bool = false

# --- Node References ---
var player_node: CharacterBody3D = null
var neck_node: Node3D = null
var camera_node: Camera3D = null
var raycast_node: RayCast3D = null

var fade_overlay: ColorRect = null
var prompt_label: Label = null
var objective_label: Label = null
var dialogue_panel: PanelContainer = null
var dialogue_label: Label = null
var continue_hint: Label = null
var tv_news_overlay: TextureRect = null
var phone_call_panel: PanelContainer = null
var phone_status_label: Label = null

var kettle_steam: CPUParticles3D = null
var mug_steam: CPUParticles3D = null
var fridge_door: Node3D = null
var fridge_light: OmniLight3D = null
var crt_screen_light: OmniLight3D = null
var tv_static_audio: AudioStreamPlayer3D = null
var clock_ticking_audio: AudioStreamPlayer3D = null
var kettle_boil_audio: AudioStreamPlayer3D = null
var siren_audio: AudioStreamPlayer3D = null

var milk_item: StaticBody3D = null
var coffee_item: StaticBody3D = null
var cup_item: StaticBody3D = null

var mouse_sensitivity: float = 0.002

# ============================================================
# READY
# ============================================================
func _ready() -> void:
	player_node = get_node_or_null("CozyPlayer")
	
	# Kitchen
	kettle_steam = get_node_or_null("Kitchen/Counter/Kettle/SteamParticles")
	mug_steam = get_node_or_null("Kitchen/DiningTable/Mug/SteamParticles")
	fridge_door = get_node_or_null("Kitchen/Refrigerator/DoorPivot")
	fridge_light = get_node_or_null("Kitchen/Refrigerator/InteriorLight")
	kettle_boil_audio = get_node_or_null("Kitchen/Counter/Kettle/BoilAudio")
	
	# Living room
	crt_screen_light = get_node_or_null("LivingRoom/CRT_TV/ScreenGlow")
	tv_static_audio = get_node_or_null("LivingRoom/CRT_TV/StaticAudio")
	clock_ticking_audio = get_node_or_null("LivingRoom/TickingClock/ClockAudio")
	siren_audio = get_node_or_null("LivingRoom/SirenAudio")
	
	# Interactable items
	milk_item = get_node_or_null("Kitchen/Refrigerator/DoorPivot/MilkCarton")
	coffee_item = get_node_or_null("Kitchen/Counter/CoffeePowder")
	cup_item = get_node_or_null("Kitchen/CupShelf/CupItem")
	
	if kettle_steam: kettle_steam.emitting = false
	if mug_steam: mug_steam.emitting = false
	if fridge_light: fridge_light.visible = false

	# HUD references from player
	if player_node:
		fade_overlay = player_node.get_node_or_null("HUD/FadeOverlay")
		prompt_label = player_node.get_node_or_null("HUD/PromptContainer/PromptLabel")
		objective_label = player_node.get_node_or_null("HUD/TopLeftContainer/MarginContainer/VBoxContainer/ObjectiveLabel")
		dialogue_panel = player_node.get_node_or_null("HUD/DialoguePanel")
		dialogue_label = player_node.get_node_or_null("HUD/DialoguePanel/Margin/DialogueLabel")
		continue_hint = player_node.get_node_or_null("HUD/ContinueHint")
		tv_news_overlay = player_node.get_node_or_null("HUD/TVNewsOverlay")
		phone_call_panel = player_node.get_node_or_null("HUD/PhoneCallPanel")
		phone_status_label = player_node.get_node_or_null("HUD/PhoneCallPanel/Margin/VBox/StatusLabel")
		neck_node = player_node.get_node_or_null("Neck")
		camera_node = player_node.get_node_or_null("Neck/Camera3D")
		raycast_node = player_node.get_node_or_null("Neck/Camera3D/RayCast3D")
		player_node.is_mounted = true
		player_node.velocity = Vector3.ZERO
		
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Hide HUD initially
	_update_hud("", "")
	
	# Fade in from black, then start intro dialogues
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		fade_overlay.visible = true
		var tween = create_tween()
		tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 0), 2.0)
		tween.tween_callback(func():
			fade_overlay.visible = false
			current_phase = Phase.INTRO_DIALOGUE
			_start_dialogue_sequence(intro_dialogues)
		)
	else:
		current_phase = Phase.INTRO_DIALOGUE
		_start_dialogue_sequence(intro_dialogues)

	if clock_ticking_audio and not clock_ticking_audio.playing:
		clock_ticking_audio.play()
	if tv_static_audio and not tv_static_audio.playing:
		tv_static_audio.play()

# ============================================================
# INPUT
# ============================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and neck_node:
		if player_node:
			player_node.rotate_y(-event.relative.x * mouse_sensitivity)
		neck_node.rotate_x(-event.relative.y * mouse_sensitivity)
		neck_node.rotation.x = clamp(neck_node.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

# ============================================================
# PROCESS
# ============================================================
func _process(delta: float) -> void:
	if final_scene_started:
		return
	
	# Kettle boil timer
	if is_kettle_boiling and not kettle_done:
		kettle_timer += delta
		# Show boil progress only when not in dialogue
		if not is_in_dialogue and prompt_label and current_phase == Phase.KETTLE_WAITING:
			prompt_label.text = "[Boiling...] " + str(int(clamp(kettle_timer, 0, 5))) + "s / 5s"
			prompt_label.visible = true
		if kettle_timer >= 5.0:
			kettle_done = true
			_on_kettle_finished()
	
	# TV flicker
	if crt_screen_light and randf() > 0.85:
		crt_screen_light.light_energy = randf_range(0.4, 0.85)
	
	# E key handler
	if Input.is_action_just_pressed("interact"):
		if is_in_dialogue:
			_advance_dialogue()
		else:
			_handle_phase_interaction()

# ============================================================
# DIALOGUE SYSTEM
# ============================================================
func _start_dialogue_sequence(dialogues: Array) -> void:
	dialogue_queue = dialogues
	dialogue_index = 0
	is_in_dialogue = true
	_show_current_dialogue()

func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= dialogue_queue.size():
		is_in_dialogue = false
		_hide_dialogue()
		_on_dialogue_sequence_finished()
	else:
		_show_current_dialogue()

func _show_current_dialogue() -> void:
	if dialogue_panel and dialogue_label:
		dialogue_label.text = dialogue_queue[dialogue_index]
		dialogue_panel.visible = true
	if continue_hint:
		continue_hint.visible = true

func _hide_dialogue() -> void:
	if dialogue_panel:
		dialogue_panel.visible = false
	if continue_hint:
		continue_hint.visible = false

func _on_dialogue_sequence_finished() -> void:
	match current_phase:
		Phase.INTRO_DIALOGUE:
			current_phase = Phase.WAIT_STAND_UP
			_update_hud("Press [E] to Stand Up", "Objective: Prepare coffee")
		Phase.KETTLE_DIALOGUE:
			if kettle_done:
				_transition_after_kettle()
			else:
				current_phase = Phase.KETTLE_WAITING
				_update_hud("[Waiting for water to boil...]", "Objective: Wait for kettle")
		Phase.TV_DIALOGUE:
			_start_phone_ringing()
		Phase.PHONE_DIALOGUE:
			_start_final_transition()

# ============================================================
# PHASE INTERACTIONS (non-dialogue E presses)
# ============================================================
func _handle_phase_interaction() -> void:
	match current_phase:
		Phase.WAIT_STAND_UP:
			_stand_up()
		Phase.FIND_MILK:
			var target = _get_raycast_target()
			if target and target.name == "FridgeInteractable":
				_open_refrigerator()
			elif target == milk_item:
				_grab_milk()
		Phase.FIND_COFFEE:
			var target = _get_raycast_target()
			if target == coffee_item:
				_grab_coffee()
		Phase.BOIL_KETTLE_PROMPT:
			var target = _get_raycast_target()
			if target and target.name == "KettleInteractable":
				_start_kettle()
		Phase.FIND_CUP:
			var target = _get_raycast_target()
			if target == cup_item:
				_grab_cup()
		Phase.WALK_TO_COUCH:
			var target = _get_raycast_target()
			if target and target.name == "CouchInteractable":
				_sit_down()
		Phase.WATCH_TV_PROMPT:
			_start_watching_tv()
		Phase.PHONE_RINGING:
			_answer_phone()

func _get_raycast_target() -> Node:
	if raycast_node and raycast_node.is_colliding():
		return raycast_node.get_collider()
	return null

# ============================================================
# HUD HELPERS
# ============================================================
func _update_hud(prompt: String, objective: String) -> void:
	if prompt_label:
		if prompt == "":
			prompt_label.visible = false
		else:
			prompt_label.text = prompt
			prompt_label.visible = true
	if objective_label:
		if objective == "":
			objective_label.visible = false
		else:
			objective_label.text = objective
			objective_label.visible = true

# ============================================================
# GAME ACTIONS
# ============================================================
func _stand_up() -> void:
	if not player_node:
		return
	if neck_node:
		var tween = create_tween()
		tween.tween_property(neck_node, "transform:origin:y", 1.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	player_node.is_mounted = false
	current_phase = Phase.FIND_MILK
	_update_hud("", "Objective: Get milk from refrigerator")

func _open_refrigerator() -> void:
	if not fridge_door:
		return
	var tween = create_tween()
	tween.tween_property(fridge_door, "rotation:y", deg_to_rad(-110.0), 0.6).set_trans(Tween.TRANS_SINE)
	if fridge_light:
		fridge_light.visible = true
	_update_hud("Press [E] to Take Milk Carton", "Objective: Take milk")

func _grab_milk() -> void:
	if not milk_item:
		return
	milk_item.visible = false
	milk_item.collision_layer = 0
	if fridge_door:
		var tween = create_tween()
		tween.tween_property(fridge_door, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	if fridge_light:
		fridge_light.visible = false
	current_phase = Phase.FIND_COFFEE
	_update_hud("", "Objective: Find coffee powder")

func _grab_coffee() -> void:
	if not coffee_item:
		return
	coffee_item.visible = false
	coffee_item.collision_layer = 0
	current_phase = Phase.BOIL_KETTLE_PROMPT
	_update_hud("", "Objective: Boil water using electric kettle")

func _start_kettle() -> void:
	is_kettle_boiling = true
	kettle_timer = 0.0
	kettle_done = false
	if kettle_steam:
		kettle_steam.emitting = true
	if kettle_boil_audio:
		kettle_boil_audio.play()
	current_phase = Phase.KETTLE_DIALOGUE
	_update_hud("", "Objective: Wait for kettle")
	_start_dialogue_sequence(coffee_dialogues)

func _on_kettle_finished() -> void:
	is_kettle_boiling = false
	if kettle_boil_audio:
		kettle_boil_audio.stop()
	# If dialogues already ended and we're waiting, transition now
	if current_phase == Phase.KETTLE_WAITING:
		_transition_after_kettle()

func _transition_after_kettle() -> void:
	current_phase = Phase.FIND_CUP
	_update_hud("", "Objective: Find a coffee cup")

func _grab_cup() -> void:
	if not cup_item:
		return
	cup_item.visible = false
	cup_item.collision_layer = 0
	
	# Move steam to camera (held coffee mug effect)
	if mug_steam and camera_node:
		var mug_parent = mug_steam.get_parent()
		if mug_parent:
			mug_parent.remove_child(mug_steam)
		camera_node.add_child(mug_steam)
		mug_steam.position = Vector3(0.15, -0.25, -0.4)
		mug_steam.emitting = true
	if kettle_steam:
		kettle_steam.emitting = false
	
	current_phase = Phase.WALK_TO_COUCH
	_update_hud("Press [E] to Sit on Couch", "Objective: Return to couch")

func _sit_down() -> void:
	if not player_node:
		return
	if neck_node:
		var tween = create_tween()
		tween.tween_property(neck_node, "transform:origin:y", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	player_node.global_position = Vector3(0.0, player_node.global_position.y, 0.0)
	player_node.rotation.y = deg_to_rad(180.0)
	player_node.is_mounted = true
	current_phase = Phase.WATCH_TV_PROMPT
	_update_hud("Press [E] to Watch TV", "Objective: Watch some TV")

# ============================================================
# TV WATCHING
# ============================================================
func _start_watching_tv() -> void:
	# Try to load and show the news broadcast image
	if tv_news_overlay:
		var img = Image.new()
		var err = img.load("res://Assets/news_broadcast.png")
		if err == OK:
			var tex = ImageTexture.create_from_image(img)
			tv_news_overlay.texture = tex
		tv_news_overlay.visible = true
	
	current_phase = Phase.TV_DIALOGUE
	_update_hud("", "")
	_start_dialogue_sequence(tv_dialogues)

# ============================================================
# PHONE CALL CUTSCENE
# ============================================================
func _start_phone_ringing() -> void:
	# Hide TV overlay
	if tv_news_overlay:
		tv_news_overlay.visible = false
	
	# Stop mug steam
	if mug_steam:
		mug_steam.emitting = false
	
	current_phase = Phase.PHONE_RINGING
	
	# Camera looks down (taking out phone)
	if camera_node:
		var tween = create_tween()
		tween.tween_property(camera_node, "rotation:x", deg_to_rad(25.0), 0.8).set_trans(Tween.TRANS_SINE)
	
	# Show phone panel with ringing
	if phone_call_panel:
		phone_call_panel.visible = true
	if phone_status_label:
		phone_status_label.text = "INCOMING CALL\n\nOld School Friend\n\nRINGING..."
	
	# After a pause, show answer prompt
	var ring_timer = get_tree().create_timer(2.5)
	ring_timer.timeout.connect(func():
		if phone_status_label:
			phone_status_label.text = "INCOMING CALL\n\nOld School Friend"
		_update_hud("Press [E] to Answer", "")
	)

func _answer_phone() -> void:
	if phone_status_label:
		phone_status_label.text = "CONNECTED\n\nOld School Friend"
	
	current_phase = Phase.PHONE_DIALOGUE
	_update_hud("", "")
	_start_dialogue_sequence(phone_dialogues)

# ============================================================
# FINAL TRANSITION
# ============================================================
func _start_final_transition() -> void:
	final_scene_started = true
	
	# Hide phone panel
	if phone_call_panel:
		phone_call_panel.visible = false
	
	# Camera returns to normal
	if camera_node:
		var tween = create_tween()
		tween.tween_property(camera_node, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	_update_hud("", "")
	
	# Brief pause then horror transition
	var glitch_timer = get_tree().create_timer(1.2)
	glitch_timer.timeout.connect(func():
		# TV goes red
		if crt_screen_light:
			crt_screen_light.light_energy = 5.0
			crt_screen_light.light_color = Color(1, 0, 0, 1)
		
		# Distant siren
		if siren_audio:
			siren_audio.play()
		
		# Fade to black
		if fade_overlay:
			fade_overlay.visible = true
			var fade_tween = create_tween()
			fade_tween.tween_property(fade_overlay, "color", Color(0, 0, 0, 1), 2.5)
			fade_tween.tween_callback(func():
				DeliveryManager.current_day += 1
				DeliveryManager.packages_delivered_today = 0
				get_tree().change_scene_to_file("res://scenes/world.tscn")
			)
		else:
			var fallback = get_tree().create_timer(2.5)
			fallback.timeout.connect(func():
				DeliveryManager.current_day += 1
				DeliveryManager.packages_delivered_today = 0
				get_tree().change_scene_to_file("res://scenes/world.tscn")
			)
	)
