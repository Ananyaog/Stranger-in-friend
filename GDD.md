# Game Design Document (GDD)
## Project: Suburban Horrors - Parcel Delivery Simulator (Godot 4.x)

---

## 1. Overview & Concept
**Suburban Horrors: Parcel Delivery Simulator** is an atmospheric, first-person retro-indie 3D horror simulator. The player takes on the role of a nightly parcel delivery driver, navigating a quiet, fog-drenched suburban neighborhood during the late evening hours. What starts as a mundane, relaxing delivery shift slowly devolves into an unsettling psychological horror experience.

### 1.1 Core Experience
* **Contrast of Mundane & Unsettling**: A slow-paced, relaxing physical delivery loop paired with escalating atmospheric dread.
* **Immersive Interaction**: Hands-on physical manipulation of package placement, motorcycle keys, and gasoline canisters.
* **Moody Retro Aesthetics**: Volumetric lights, dim orange streetlights piercing through blue volumetric fog, metallic wet asphalt reflections, and low-poly architectures inspired by classic horror titles.
* **Procedural Horror Triggers**: Creepy events (streetlights blowing out, fog thickening, shifting shadows) tied directly to player delivery progression.

---

## 2. Core Mechanics

### 2.1 First-Person Player Controller
When walking, the player moves on foot to inspect doorsteps and interact with objects.
* **Movement (WASD)**: Grounded movement with linear interpolation (`lerp`) to simulate physical momentum.
* **Sprint (Shift)**: Boosts movement speed from `3.5` to `6.0` when running forward. FOV dynamically scales from `75.0°` to `82.0°` using standard interpolation.
* **Organic Head Bobbing**: Sinusoidal camera movements (`sin(t)` and `cos(t*0.5)`) simulate weight and steps.
* **Shoulder Flashlight (F Key)**: Projects a shadow-casting beam of light. Flashlight beam dots are tracked programmatically to disrupt stalking anomalies.

### 2.2 🎒 5-Slot Inventory Hotbar
The player possesses a physical 5-slot inventory, bound to keys **1–5**:
1. **Motorbike Key** (Required to start the motorcycle).
2. **Flashlight** (Utility item that enables personal lighting and deters stalkers).
3. **Parcels** (Occupies slots; must be active/selected or possessed to drop off at doorsteps).
4. **Fuel Canisters** (Can be retrieved from the Gas Station pumps to refuel the bike).

### 2.3 🏍️ Rideable Motorbike
The primary vehicle for travel between suburban houses.
* **Mounting / Dismounting**: Pressing **E** when looking at the bike transitions the player state. The player node is hidden, collisions are bypassed, and the camera swaps to a smooth third-person motorcycle perspective.
* **Ignition & Key Check**: The bike will not start unless the player possesses the **Motorbike Key** in their inventory.
* **Fuel Management**: Drains gas dynamically during acceleration (1.8% per second). Running out of gas stops the bike, requiring physical canister refueling.
* **Refueling**: Equipping a `Fuel Canister` in the active hotbar slot and interacting with the bike refills the tank by `45%`.
* **Dashboard Navigation Pointer**: A mechanical 3D compass arrow on the bike's dashboard rotates in real-time, pointing directly at the doorstep of the active parcel delivery target.

### 2.4 📦 Parcel Delivery System
* **Randomized Waypoints**: Each night/shift, 4–5 houses are selected as active delivery targets.
* **Glowing Doorsteps**: Active targets are marked by spinning, floating 3D billboarding arrows and a glowing orange circle on the porch.
* **Dropoff Mechanics**: The player must dismount, walk up to the doorstep with a `Parcel` in their inventory, and press **E** to complete the dropoff.

---

## 3. World Design & Suburban Layout

The game level is mapped around a brutalist-suburban modular environment:
* **The Street Grid**: A clean concrete-metallic asphalt road grid connecting six stylized suburban houses.
* **Porch Structures**: Every house features a raised wooden/concrete porch, a lit front doorway, and an interactive doorstep zone.
* **The Neon Gas Station**: Located in the corner of the sector, featuring retro green/magenta neon lights, a fuel rack spawning interactable **Fuel Canisters**, and fueling pumps.
* **Warm and Cool Light Contrast**: Large orange streetlights throw shadows down streets, contrasting with a cool, low-intensity blue volumetric moonlight.

---

## 4. The Horror System & Escalation Loop
Paranormal progression is overseen by the event-driven **Horror Manager**:
* **Atmospheric Progression (Shifts/Days)**: Each new night, the global fog density increases (`0.03` -> `0.08`), and the ambient moonlight grows progressively darker and colder.
* **Flickering Outages**: Reaching delivery milestones triggers sudden electrical faults, causing streetlights to sputter, flicker violently, and die permanently, plunging sectors into darkness.
* **Shadow Stalkers**: Eerie, red-eyed silhouettes that spawn in unlit side streets and dark house corners.
  * **Visual Clues**: Stalkers stand motionless, watching the player from the mist.
  * **Line-of-Sight Check**: A dot-product projection checks if the player is looking at the stalker while the flashlight is ON (`dot > 0.95`). 
  * **Raycast Occlusion**: A physical raycast ensures house walls block the glare.
  * **Dissolution**: Catching a stalker in the flashlight beam or walking within 6 meters causes it to dissolve in a creepy whisper audio cue and fade tween.

---

## 5. Technical Architecture

The project files are modularly structured:
```
godot_fpv_game/
├── project.godot            # Engine configurations & registered Autoload singletons
├── GDD.md                   # This Game Design Document
├── default_env.tres         # Volumetric fog, SSAO, SSR, ACES tonemap settings
├── scripts/
│   ├── autoload_input.gd    # Programmatic InputMap initialization
│   ├── inventory.gd         # Singleton: slot list, hotbar selections
│   ├── delivery_manager.gd  # Singleton: shift count, randomized house pools, payday
│   ├── interactable.gd      # Decoupled base class for physical interactions
│   ├── player.gd            # FPV movement, inventory select, notifications, Raycasting
│   ├── motorbike.gd         # Vehicle movement, gasoline consumption, ignition key
│   ├── motorbike_interactable.gd # Relay to trigger vehicle mount
│   ├── delivery_point.gd    # Glowing delivery circle & spinning billboard waypoints
│   ├── gas_pump.gd          # Dispenses fuel canisters to inventory
│   ├── shadow_stalker.gd    # Dot-product flashlight check and dissolve tweens
│   └── horror_manager.gd    # Handles streetlight blackouts and AI stalker spawns
└── scenes/
    ├── player.tscn          # Player node, camera rig, flashlight, HUD, slot hotbar UI
    ├── motorbike.tscn       # Rideable low-poly bike, ignition audio, dashboard compass
    ├── house.tscn           # Suburban home prefab with front porch
    ├── gas_station.tscn     # Glowing neon refueling point
    ├── shadow_stalker.tscn  # Creepy silhouette sprite with glowing emission eyes
    └── world.tscn           # Main sandbox level combining roads, houses, streetlights
```

---

## 6. Controls Reference

| Action | Keybinding | Mechanism |
|---|---|---|
| **Walk Movement** | `W` `A` `S` `D` | Walks the player in physical space |
| **Sprint** | `Shift` (Hold) | Speed increases, FOV widens smoothly |
| **Mouse Look** | `Mouse Motion` | Aims camera and direction (vertical clamped) |
| **Interact** | `E` | Mounts bike / refuels / picks up canister / delivers packages |
| **Flashlight** | `F` | Toggles shadow-casting flashlight (requires Flashlight item) |
| **Select Slots** | `1` `2` `3` `4` `5` | Swaps active inventory item |
| **Unlock Cursor** | `ESC` | Toggles cursor lock for editor/free mouse |

---

## 7. Setup & Play Instructions
1. Extract the packaged project archive `godot_fpv_game.zip`.
2. Launch the **Godot 4 Editor** (4.0+ supported).
3. Select **Import**, choose `project.godot` from the folder, and select **Import & Edit**.
4. Press **F5** to start the simulator! Follow the glowing dashboard compass arrow to begin your parcel deliveries.
