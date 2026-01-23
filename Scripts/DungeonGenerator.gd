extends Node2D

## Configuration
@export_group("Templates")
@export var room_templates: Array[PackedScene]
@export var corridor_templates: Array[PackedScene]
@export var wall_filler_scene: PackedScene

@export_group("Generation Settings")
@export var max_rooms: int = 20
@export var max_consecutive_corridors: int = 2

## Internal State
var rooms_placed_count: int = 0
var open_exits: Array[Marker2D] = []
var occupied_rects: Array[Rect2] = []
var template_data_cache: Dictionary = {}

func _ready() -> void:
	randomize()
	cache_all_templates()
	generate_dungeon()
	
	await get_tree().process_frame
	
	self.scale *= 8
	

func cache_all_templates() -> void:
	for scene in room_templates + corridor_templates:
		if not scene: continue
		var node = scene.instantiate()
		var area = node.get_node_or_null("Area2D")
		var markers_node = node.get_node_or_null("Markers")
		
		var markers_info = []
		if markers_node:
			for m in markers_node.get_children():
				# Zapisujemy lokalną pozycję i rotację markerów
				markers_info.append({"pos": m.position, "rot": m.rotation_degrees})
		
		var rect = Rect2()
		if area:
			var first_shape = true
			for child in area.get_children():
				if child is CollisionShape2D and child.shape:
					var shape_rect = child.shape.get_rect()
					# Przesuwamy lokalny prostokąt kształtu o pozycję CollisionShape2D
					shape_rect.position += child.position
					
					if first_shape:
						rect = shape_rect
						first_shape = false
					else:
						rect = rect.merge(shape_rect)
		
		template_data_cache[scene] = {"rect": rect, "markers": markers_info}
		node.queue_free()

func generate_dungeon() -> void:
	instantiate_first_room()
	
	var attempts = 0
	while open_exits.size() > 0 and rooms_placed_count < max_rooms and attempts < 100:
		var current_exit = open_exits.pop_front()
		if not is_instance_valid(current_exit): continue
		
		# Pobieramy dane wyjścia ZANIM spróbujemy coś postawić
		var exit_global_pos = current_exit.global_position
		var exit_global_rot = current_exit.global_rotation_degrees
		
		if not _try_place_next_segment(current_exit, exit_global_pos, exit_global_rot):
			place_wall_filler(exit_global_pos, exit_global_rot)
		
		attempts += 1
	
	# Zamknij resztę
	for exit in open_exits:
		if is_instance_valid(exit):
			place_wall_filler(exit.global_position, exit.global_rotation_degrees)

func _try_place_next_segment(exit_node: Marker2D, exit_pos: Vector2, exit_rot: float) -> bool:
	var chain = exit_node.get_meta("corridor_chain", 0)
	
	# Jeśli przekroczono limit korytarzy, wymuś pokój. 
	# W przeciwnym razie daj 50% szans na pokój najpierw, żeby uniknąć samych korytarzy.
	var pools = []
	if chain >= max_consecutive_corridors:
		pools = [room_templates]
	else:
		# Mieszamy kolejność, żeby nie zawsze korytarz był pierwszy
		pools = [room_templates, corridor_templates]
		pools.shuffle()
	
	for pool in pools:
		var templates = pool.duplicate()
		templates.shuffle()
		for scene in templates:
			if try_place_room(scene, exit_pos, exit_rot, chain):
				return true
	return false

func try_place_room(scene: PackedScene, exit_pos: Vector2, exit_rot: float, chain: int) -> bool:
	var data = template_data_cache[scene]
	# Szukamy wejścia, które patrzy w stronę przeciwną do wyjścia (np. wyjście 0 -> wejście 180)
	var target_entry_rot = wrapf(exit_rot + 180.0, 0, 360)
	
	for m_info in data.markers:
		if abs(wrapf(m_info.rot, 0, 360) - target_entry_rot) < 1.0:
			# OBLICZENIE POZYCJI:
			# Nowy Root = Pozycja Wyjścia - Lokalna Pozycja Markera Wejściowego
			var room_global_pos = exit_pos - m_info.pos
			
			# Obliczamy obszar zajmowany przez nowy segment w przestrzeni świata
			var new_rect = Rect2(room_global_pos + data.rect.position, data.rect.size)
			
			# Margines zapobiegający błędnym kolizjom na stykach
			if not is_overlapping(new_rect.grow(-1.0)):
				place_actual_room(scene, room_global_pos, m_info.pos, chain)
				return true
	return false

func is_overlapping(new_rect: Rect2) -> bool:
	for rect in occupied_rects:
		if new_rect.intersects(rect):
			return true
	return false

func place_actual_room(scene: PackedScene, g_pos: Vector2, used_m_pos: Vector2, chain: int):
	var new_room = scene.instantiate()
	add_child(new_room)
	new_room.global_position = g_pos
	
	# WYMUSZENIE AKTUALIZACJI: Markery muszą znać swoją nową pozycję globalną
	new_room.force_update_transform()
	
	var data = template_data_cache[scene]
	occupied_rects.append(Rect2(g_pos + data.rect.position, data.rect.size))
	
	var is_corridor = corridor_templates.has(scene)
	var next_chain = (chain + 1) if is_corridor else 0
	
	var markers_node = new_room.get_node_or_null("Markers")
	if markers_node:
		for marker in markers_node.get_children():
			# Nie dodajemy do kolejki markera, który właśnie połączyliśmy
			if not marker.position.is_equal_approx(used_m_pos):
				marker.set_meta("corridor_chain", next_chain)
				open_exits.append(marker)
	
	rooms_placed_count += 1

func instantiate_first_room() -> void:
	if room_templates.is_empty(): return
	var scene = room_templates.pick_random()
	var room = scene.instantiate()
	add_child(room)
	room.global_position = Vector2.ZERO
	room.force_update_transform()
	
	var data = template_data_cache[scene]
	occupied_rects.append(Rect2(data.rect.position, data.rect.size))
	
	for marker in room.get_node("Markers").get_children():
		marker.set_meta("corridor_chain", 0)
		open_exits.append(marker)
	rooms_placed_count += 1

func place_wall_filler(pos: Vector2, rot: float):
	if wall_filler_scene:
		var wall = wall_filler_scene.instantiate()
		add_child(wall)
		wall.global_position = pos
		# Filler powinien być obrócony tak jak wyjście
		wall.rotation_degrees = rot
