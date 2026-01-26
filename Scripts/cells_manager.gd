extends Node2D

@export var cell_scene: PackedScene
@export_range(0, 1) var spawn_chance: float = 0.7
@onready var progress_bar: ProgressBar = $CanvasLayer/CenterContainer/VBoxContainer/ProgressBar
@onready var dungeon_generator := $"../DungeonGenerator"

var total_cells: int = 0
var infected_cells_count: int = 0
var active_cells: Array[Area2D] = []

func _ready() -> void:
	dungeon_generator.dungeon_generated.connect(_instantiate_cells)
	if progress_bar:
		progress_bar.value = 0


func _instantiate_cells() -> void:
	_clear_cells()
	var potential_spots: int = 0
	for room in dungeon_generator.get_children():
		var markers_node = room.get_node_or_null("CellMarkers")
		
		if markers_node:
			for marker in markers_node.get_children():
				if marker is Marker2D: potential_spots += 1
				if marker is Marker2D and randf() <= spawn_chance:
					_spawn_cell(marker.global_position)

	_update_ui()
	print("--- CELL STATS ---")
	print("Avaiable places: ", potential_spots)
	print("Spawned cells: ", total_cells)
	print("Procentage of fullity: ", (float(total_cells) / potential_spots * 100), "%")
	print("---------------------------")

func _spawn_cell(pos: Vector2) -> void:
	var cell = cell_scene.instantiate()
	add_child(cell)
	cell.global_position = pos
	
	cell.cell_infected.connect(_on_cell_infected)
	
	active_cells.append(cell)
	total_cells += 1

func _on_cell_infected() -> void:
	infected_cells_count += 1
	_update_ui()
	
	if infected_cells_count >= total_cells and total_cells > 0:
		_on_victory()

func _update_ui() -> void:
	if progress_bar and total_cells > 0:
		var percentage = (float(infected_cells_count) / total_cells) * 100
		
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", percentage, 0.5).set_trans(Tween.TRANS_SINE)

func _on_victory() -> void:
	print("Cały dungeon przejęty! Infekcja kompletna.")

func _clear_cells() -> void:
	for cell in active_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	active_cells.clear()
	total_cells = 0
	infected_cells_count = 0
