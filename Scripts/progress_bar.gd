extends Control

@onready var progress_bar = $CenterContainer/ProgressBar
var loading_done = false

func _ready():
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(SceneManager.target_scene_path)

func _process(_delta):
	if loading_done:
		return

	var status = ResourceLoader.load_threaded_get_status(SceneManager.target_scene_path, SceneManager.progress)
	progress_bar.value = SceneManager.progress[0] * 90
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_done = true
		_start_instantiation()

func _start_instantiation():
	var packed_scene = ResourceLoader.load_threaded_get(SceneManager.target_scene_path)
	
	var main_scene_instance = packed_scene.instantiate()
	
	if main_scene_instance.has_signal("dungeon_generated"):
		main_scene_instance.dungeon_generated.connect(_on_dungeon_ready.bind(main_scene_instance))
		
		if main_scene_instance.has_method("prepare_scene"):
			main_scene_instance.prepare_scene()
	else:
		_on_dungeon_ready(main_scene_instance)

func _on_dungeon_ready(instance):
	progress_bar.value = 100
	await get_tree().create_timer(0.2).timeout
	
	var root = get_tree().root
	var current_scene = get_tree().current_scene
	
	root.add_child(instance)
	get_tree().current_scene = instance
	current_scene.queue_free()
