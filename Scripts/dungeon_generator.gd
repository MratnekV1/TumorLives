extends Node2D

@export var room_templates: Array[PackedScene]
@export var corridor_templates: Array[PackedScene]
@export var max_rooms: int = 15
@export var max_consecutive_corridors: int = 3

@export var wall_filler_scene: PackedScene

var rooms_placed_count: int = 0
var open_exits: Array[Marker2D] = []
var hierarchy: Dictionary = {}

var occupied_rects: Array[Rect2] = []
var template_size_cache: Dictionary = {}


func _ready():
	generate_dungeon_async()
	self.scale *= 8

func generate_dungeon_async():
	var start_scene = room_templates.pick_random()
	var start_room = start_scene.instantiate()
	add_child(start_room)
	
	occupied_rects.append(get_node_bounds(start_room))
	
	register_exits(start_room, null, 0)
	rooms_placed_count += 1
	
	while open_exits.size() > 0 and rooms_placed_count < max_rooms:
		var current_exit = open_exits.pop_front()
		if not is_instance_valid(current_exit): continue
		
		var current_chain = current_exit.get_meta("corridor_chain", 0)
		var parent_node = current_exit.get_parent().get_parent()
		
		var success = try_sequence(current_exit, corridor_templates, room_templates, current_chain)
		
		if not success:
			if current_chain > 0:
				remove_corridor_chain(parent_node)
			else:
				close_exit(current_exit)
		
	cleanup_unused_corridors()

func try_sequence(exit_a: Marker2D, list_1: Array[PackedScene], list_2: Array[PackedScene], chain: int) -> bool:
	if attempt_placement(exit_a, list_1, chain): return true
	if attempt_placement(exit_a, list_2, chain): return true
	return false

func attempt_placement(exit_a: Marker2D, templates: Array[PackedScene], chain: int) -> bool:
	var shuffled = templates.duplicate()
	shuffled.shuffle()

	for scene in shuffled:
		var is_corridor = corridor_templates.has(scene)
		if is_corridor and chain >= max_consecutive_corridors: continue

		var new_node = scene.instantiate()
		
		if try_place_segment(exit_a, new_node, is_corridor, chain):
			hierarchy[new_node] = exit_a.get_parent().get_parent()
			occupied_rects.append(get_node_bounds(new_node))
			if not is_corridor: rooms_placed_count += 1
			return true
		else:
			new_node.queue_free()
	return false

func try_place_segment(exit_a: Marker2D, node_b: Node2D, is_corridor: bool, current_chain: int) -> bool:
	add_child(node_b)
	var markers_b = node_b.get_node("Markers").get_children()
	var exit_b: Marker2D = markers_b.pick_random()
	
	if is_corridor:
		node_b.rotation = (exit_a.global_rotation + PI) - exit_b.rotation
	else:
		var found_match = false
		for m in markers_b:
			if is_opposite_direction(exit_a.global_rotation, m.global_rotation):
				exit_b = m
				found_match = true
				break
		if not found_match: return false
	
	node_b.global_position = exit_a.global_position - (exit_b.global_position - node_b.global_position)
	node_b.force_update_transform()
	
	var new_rect = get_node_bounds(node_b)
	for rect in occupied_rects:
		if rect.intersects(new_rect, 5):
			return false
	
	register_exits(node_b, exit_b, (current_chain + 1) if is_corridor else 0)
	return true

func get_node_bounds(node: Node2D) -> Rect2:
	var area = node.get_node("Area2D")
	var shape_node = area.get_node("CollisionShape2D")
	var shape = shape_node.shape
	if shape is RectangleShape2D:
		var size = shape.size
		return Rect2(shape_node.global_position - size/2, size)
	return Rect2()

func get_template_size(scene: PackedScene) -> Vector2:
	if template_size_cache.has(scene): return template_size_cache[scene]
	var temp = scene.instantiate()
	var size = get_node_bounds(temp).size
	temp.queue_free()
	template_size_cache[scene] = size
	return size

func remove_corridor_chain(node: Node2D):
	var current = node
	while is_instance_valid(current) and is_segment_corridor(current):
		if has_active_children(current): break
		
		var parent = hierarchy.get(current)
		remove_node_from_gen(current)
		current = parent

func cleanup_unused_corridors():
	var nodes = hierarchy.keys()
	nodes.reverse()
	for node in nodes:
		if is_instance_valid(node) and is_segment_corridor(node) and not has_active_children(node):
			remove_node_from_gen(node)
	
	for marker in open_exits:
		if is_instance_valid(marker): marker.queue_free()
	open_exits.clear()

func remove_node_from_gen(node: Node2D):
	var rect = get_node_bounds(node)
	occupied_rects.erase(rect)
	
	var markers = node.get_node("Markers").get_children()
	open_exits = open_exits.filter(func(m): return m not in markers)
	
	hierarchy.erase(node)
	node.queue_free()

func has_active_children(parent_node: Node2D) -> bool:
	for parent in hierarchy.values():
		if parent == parent_node: return true
	return false

func is_segment_corridor(node: Node2D) -> bool:
	return corridor_templates.any(func(scene): return scene.resource_path == node.scene_file_path)

func register_exits(room: Node2D, used_marker: Marker2D, chain_value: int):
	for marker in room.get_node("Markers").get_children():
		if marker != used_marker:
			marker.set_meta("corridor_chain", chain_value)
			open_exits.append(marker)

func is_opposite_direction(rot_a: float, rot_b: float) -> bool:
	return abs(abs(fmod(rot_a - rot_b, TAU)) - PI) < 0.1

func close_exit(marker: Marker2D):
	if is_instance_valid(marker): marker.queue_free()
