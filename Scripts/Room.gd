# Room.gd
extends Node2D
class_name DungeonRoom

@onready var markers_container: Node2D = $Markers
@onready var room_area: Area2D = $Area2D

# Zwraca listę wszystkich markerów (wejść/wyjść)
func get_markers() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in markers_container.get_children():
		if child is Marker2D:
			markers.append(child)
	return markers

# Zwraca Area2D do sprawdzania kolizji
func get_area() -> Area2D:
	return room_area
