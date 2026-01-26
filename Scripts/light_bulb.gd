extends PointLight2D

# --- Ustawienia Unoszenia (Bobbing) ---
@export_group("Bobbing Settings")
@export var bobbing_enabled: bool = true
@export var float_speed: float = 2.0
@export var float_amplitude: float = 10.0

# --- Ustawienia Mrugania (Flicker) ---
@export_group("Flicker Settings")
@export var flicker_enabled: bool = true
@export var min_energy_mult: float = 0.7
@export var max_energy_mult: float = 1.3
@export var flicker_speed: float = 0.1 # Czas między zmianami

var base_energy: float
var base_y_pos: float
var time_passed: float = 0.0
var flicker_timer: float = 0.0
var phase_offset: float = 0.0

func _ready() -> void:
	randomize()
	base_energy = energy
	base_y_pos = position.y
	phase_offset = randf()

func _process(delta: float) -> void:
	time_passed += delta
	
	if bobbing_enabled:
		_handle_bobbing()
		
	if flicker_enabled:
		_handle_flicker(delta)

func _handle_bobbing() -> void:
	position.y = base_y_pos + sin((time_passed * float_speed) + phase_offset) * float_amplitude

func _handle_flicker(delta: float) -> void:
	flicker_timer -= delta
	
	if flicker_timer <= 0:
		var random_mult = randf_range(min_energy_mult, max_energy_mult)
		
		flicker_timer = randf_range(0.05, flicker_speed)
		
		var t = create_tween()
		t.tween_property(self, "energy", base_energy * random_mult, flicker_timer)
