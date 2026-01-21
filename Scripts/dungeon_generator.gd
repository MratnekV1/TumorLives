extends Node2D

@export var room_templates: Array[PackedScene]
@export var corridor_templates: Array[PackedScene]
@export var max_rooms: int = 15
@export var max_consecutive_corridors: int = 3

var rooms_placed_count: int = 0
var open_exits: Array[Marker2D] = []

var hierarchy: Dictionary = {}

func _ready():
	generate_dungeon_async()
	self.scale *= 1 # Make the Map Bigger

func generate_dungeon_async():
	var start_room = room_templates.pick_random().instantiate()
	add_child(start_room)
	register_exits(start_room, null, 0)
	rooms_placed_count += 1
	
	while open_exits.size() > 0 and rooms_placed_count < max_rooms:
		var current_exit = open_exits.pop_front()
		if not is_instance_valid(current_exit): continue
		
		var current_chain = current_exit.get_meta("corridor_chain", 0)
		var parent_node = current_exit.get_parent().get_parent()
		
		var success = false
		
		if current_chain == 0:
			success = try_sequence(current_exit, corridor_templates, room_templates, current_chain)
		else:
			success = try_sequence(current_exit, room_templates, corridor_templates, current_chain)
		
		if not success:
			if current_chain > 0:
				remove_corridor_chain(parent_node)
			else:
				close_exit(current_exit)
		
		await get_tree().process_frame

	cleanup_unused_corridors()

func try_sequence(exit_a: Marker2D, first_list: Array[PackedScene], second_list: Array[PackedScene], chain: int) -> bool:
	if attempt_placement(exit_a, first_list, chain):
		return true
	if attempt_placement(exit_a, second_list, chain):
		return true
	return false

func attempt_placement(exit_a: Marker2D, templates: Array[PackedScene], chain: int) -> bool:
	for i in range(3):
		var new_scene = templates.pick_random()
		var is_corridor = corridor_templates.has(new_scene)
		
		if is_corridor and chain >= max_consecutive_corridors:
			continue

		var new_node = new_scene.instantiate()
		if try_place_segment(exit_a, new_node, is_corridor, chain):
			hierarchy[new_node] = exit_a.get_parent().get_parent()
			
			if not is_corridor: 
				rooms_placed_count += 1
			return true
		else:
			new_node.queue_free()
	return false

func try_place_segment(exit_a: Marker2D, node_b: Node2D, is_corridor: bool, current_chain: int) -> bool:
	add_child(node_b)
	var markers_b = node_b.get_node("Markers").get_children()
	var exit_b: Marker2D = markers_b.pick_random()
	
	if is_corridor:
		var target_rotation = (exit_a.global_rotation + PI) - exit_b.rotation
		node_b.rotation = target_rotation
	else:
		var found_match = false
		for m in markers_b:
			if is_opposite_direction(exit_a.global_rotation, m.global_rotation):
				exit_b = m
				found_match = true
				break
		if not found_match: return false
	
	node_b.global_position = exit_a.global_position - (exit_b.global_position - node_b.global_position)
	
	
	if has_collision(node_b):
		return false
	
	var next_chain = (current_chain + 1) if is_corridor else 0
	register_exits(node_b, exit_b, next_chain)
	return true
	
func remove_corridor_chain(node: Node2D):
	var is_room = false
	for m in node.get_node("Markers").get_children():
		if m.get_meta("corridor_chain", 0) == 0:
			is_room = true; break
			
	if not is_room:
		var parent = hierarchy.get(node)
		var markers = node.get_node("Markers").get_children()
		open_exits = open_exits.filter(func(m): return m not in markers)
		
		hierarchy.erase(node)
		node.queue_free()
		
		if parent and parent in hierarchy:
			remove_corridor_chain(parent)

func cleanup_unused_corridors():
	var changed = true
	while changed:
		changed = false
		var nodes_to_remove = []

		for node in get_children():
			if not node in hierarchy or not is_segment_corridor(node):
				continue
			
			if not has_active_children(node):
				nodes_to_remove.append(node)
				changed = true
		
		for node in nodes_to_remove:
			hierarchy.erase(node)
			node.queue_free()

	for marker in open_exits:
		if is_instance_valid(marker):
			marker.queue_free()
	open_exits.clear()

func is_segment_corridor(node: Node2D) -> bool:
	var markers = node.get_node("Markers").get_children()
	if markers.size() > 0:
		return markers[0].get_meta("corridor_chain", 0) > 0
	return false

func has_active_children(parent_node: Node2D) -> bool:
	for child in hierarchy.keys():
		if hierarchy[child] == parent_node:
			return true
	return false

func register_exits(room: Node2D, used_marker: Marker2D, chain_value: int):
	for marker in room.get_node("Markers").get_children():
		if marker != used_marker:
			marker.set_meta("corridor_chain", chain_value)
			open_exits.append(marker)

func is_opposite_direction(rot_a: float, rot_b: float) -> bool:
	return abs(abs(fmod(rot_a - rot_b, TAU)) - PI) < 0.1

func has_collision(node_b: Node2D) -> bool:
	var area = node_b.get_node("Area2D")
	var shape_node = area.get_node("CollisionShape2D")
	var shape = shape_node.shape
	
	var space_state = get_world_2d().direct_space_state
	
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape_rid = shape.get_rid()
	params.transform = shape_node.global_transform
	params.collision_mask = area.collision_mask
	params.exclude = [area.get_rid()]
	params.collide_with_areas = true
	params.collide_with_bodies = false
	
	var results = space_state.intersect_shape(params)
	return results.size() > 0

func close_exit(marker: Marker2D):
	if is_instance_valid(marker):
		marker.queue_free()
