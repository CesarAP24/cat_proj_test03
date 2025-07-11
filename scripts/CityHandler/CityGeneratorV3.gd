extends Node3D
class_name CityGeneratorV3

# Core systems
var chunk_manager: SpatialChunkManager
var manzana_manager: ManzanaManager

# Current state
var current_districts: Array = []
var player_position: Vector2
var current_avenue_chunk: Vector2i
var current_street_chunk: Vector2i
var last_avenue_chunk: Vector2i
var last_street_chunk: Vector2i

# Configuration
@export_group("Chunk Configuration")
@export var avenue_chunk_size: int = 1300
@export var street_chunk_size: int = 200
@export var avenue_render_distance: int = 3
@export var street_render_distance: int = 4

@export_group("Points Per Chunk")
@export var max_avenue_points_per_chunk: int = 1
@export var max_street_points_per_chunk: int = 1

@export_group("Mesh Generation")
@export var mesh_generation_distance: float = 200.0
@export var block_padding: float = 10.0
@export var lot_size: int = 100

@export_group("Debug")
@export var show_debug_overlay: bool = true
@export var debug_chunk_type: String = "avenue"

# Internal state
var generation_in_progress: bool = false
var containers: Dictionary = {}
var cat_handler: Node3D
var debug_canvas: CanvasLayer
var debug_control: DebugOverlay

# === INITIALIZATION ===

func _ready():
	setup_core_systems()
	setup_debug_overlay()
	find_player_reference()
	call_deferred("generate_initial_city")

func setup_core_systems():
	create_chunk_manager()
	create_manzana_manager()
	create_mesh_containers()

func create_chunk_manager():
	chunk_manager = SpatialChunkManager.new()
	configure_chunk_manager()

func configure_chunk_manager():
	chunk_manager.avenue_chunk_size = avenue_chunk_size
	chunk_manager.street_chunk_size = street_chunk_size
	chunk_manager.avenue_render_distance = avenue_render_distance
	chunk_manager.street_render_distance = street_render_distance
	chunk_manager.max_avenue_points_per_chunk = max_avenue_points_per_chunk
	chunk_manager.max_street_points_per_chunk = max_street_points_per_chunk

func create_manzana_manager():
	manzana_manager = ManzanaManager.new()
	manzana_manager.initialize(chunk_manager, containers, mesh_generation_distance, block_padding, lot_size)

func create_mesh_containers():
	for container_name in ["Districts", "Blocks", "Buildings"]:
		var container = Node3D.new()
		container.name = container_name
		add_child(container)
		containers[container_name.to_lower()] = container

func setup_debug_overlay():
	debug_canvas = CanvasLayer.new()
	debug_canvas.layer = 100
	add_child(debug_canvas)
	debug_control = DebugOverlay.new(self)
	debug_canvas.add_child(debug_control)

func find_player_reference():
	cat_handler = get_node("../../CityTest")
	if not cat_handler:
		cat_handler = get_node("../CityTest")

# === MAIN UPDATE LOOP ===

func _process(_delta):
	update_player_position()
	handle_debug_input()
	debug_control.queue_redraw()
	
	if should_regenerate_city():
		call_deferred("regenerate_city")

func update_player_position():
	if cat_handler and cat_handler.has_method("obtener_centro"):
		var pos = cat_handler.obtener_centro()
		player_position = Vector2(pos.x, pos.z)
	else:
		player_position = Vector2.ZERO

func should_regenerate_city() -> bool:
	if generation_in_progress:
		return false
	
	return has_player_moved_to_new_chunk()

func has_player_moved_to_new_chunk() -> bool:
	var new_avenue_chunk = chunk_manager.get_avenue_chunk_coord(player_position.x, player_position.y)
	var new_street_chunk = chunk_manager.get_street_chunk_coord(player_position.x, player_position.y)
	
	var avenue_changed = current_avenue_chunk != new_avenue_chunk
	var street_changed = current_street_chunk != new_street_chunk
	
	if avenue_changed:
		last_avenue_chunk = current_avenue_chunk
		current_avenue_chunk = new_avenue_chunk
	
	if street_changed:
		last_street_chunk = current_street_chunk
		current_street_chunk = new_street_chunk
	
	return avenue_changed or street_changed

# === CITY GENERATION ===

func generate_initial_city():
	update_player_position()
	initialize_chunk_coordinates()
	regenerate_districts()

func initialize_chunk_coordinates():
	current_avenue_chunk = chunk_manager.get_avenue_chunk_coord(player_position.x, player_position.y)
	current_street_chunk = chunk_manager.get_street_chunk_coord(player_position.x, player_position.y)

func regenerate_city():
	if generation_in_progress:
		return
	
	generation_in_progress = true
	
	if has_avenue_chunk_changed():
		regenerate_districts()
	else:
		generate_nearby_manzanas()
	
	generation_in_progress = false

func has_avenue_chunk_changed() -> bool:
	return last_avenue_chunk != current_avenue_chunk

func regenerate_districts():
	generate_district_voronoi()
	generate_nearby_manzanas()

func generate_district_voronoi():
	var avenue_points = get_avenue_points_in_render_distance()
	var world_bounds = calculate_world_bounds()
	current_districts = VoronoiGenerator.generate_voronoi(PackedVector2Array(avenue_points), world_bounds)

func get_avenue_points_in_render_distance() -> Array:
	return chunk_manager.get_avenue_points_in_render_distance(player_position)

func calculate_world_bounds() -> Rect2:
	var avenue_size = chunk_manager.avenue_chunk_size
	var render_dist = chunk_manager.avenue_render_distance
	var center = Vector2(
		current_avenue_chunk.x * avenue_size + avenue_size / 2,
		current_avenue_chunk.y * avenue_size + avenue_size / 2
	)
	var total_size = avenue_size * (render_dist * 2 + 1)
	return Rect2(center - Vector2(total_size/2, total_size/2), Vector2(total_size, total_size))

func generate_nearby_manzanas():
	var street_points = get_street_points_in_render_distance()
	var district_assignments = assign_street_points_to_districts(street_points)
	
	for distrito_hash in district_assignments:
		var points_in_district = district_assignments[distrito_hash]
		generate_manzanas_for_district(distrito_hash, points_in_district)

func get_street_points_in_render_distance() -> Array:
	return chunk_manager.get_street_points_in_render_distance(player_position)

func assign_street_points_to_districts(street_points: Array) -> Dictionary:
	var assignment_result = chunk_manager.assign_street_points_to_districts(current_districts, street_points)
	return assignment_result[0]  # district_point_assignments


func generate_manzanas_for_district(distrito_hash: String, points_in_district: Array):
	if points_in_district.size() < 3:
		return
	
	var distrito_polygon = find_district_polygon_by_hash(distrito_hash)
	if distrito_polygon.is_empty():
		return
	
	var manzana_polygons = generate_voronoi_for_district(points_in_district, distrito_polygon)
	
	for point in points_in_district:
		var punto_hash = StabilityChecker.get_point_hash(point)
		var manzana_polygon = manzana_polygons.get(punto_hash, {"vertices": []})["vertices"]
		if manzana_polygon.size() >= 3:
			attempt_to_generate_manzana(point, manzana_polygon)


func find_district_polygon_by_hash(distrito_hash: String) -> PackedVector2Array:
	for distrito in current_districts:
		if chunk_manager.get_district_hash(distrito.site) == distrito_hash:
			return distrito.vertices
	return PackedVector2Array()

func generate_voronoi_for_district(points: Array, distrito_polygon: PackedVector2Array) -> Dictionary:
	return VoronoiGenerator.generate_voronoi_for_district(PackedVector2Array(points), distrito_polygon)

func attempt_to_generate_manzana(point: Vector2, manzana_polygon: Array):
	if is_point_close_enough_to_player(point):
		manzana_manager.generate_manzana_if_stable(point, manzana_polygon)

func is_point_close_enough_to_player(point: Vector2) -> bool:
	return player_position.distance_to(point) <= mesh_generation_distance

# === DEBUG FUNCTIONALITY ===

func handle_debug_input():
	if Input.is_action_just_pressed("debug_toggle"):
		toggle_debug_overlay()
	
	if Input.is_action_just_pressed("debug_mode_cycle"):
		cycle_debug_mode()
	
	handle_fallback_debug_keys()

func handle_fallback_debug_keys():
	if Input.is_key_pressed(KEY_F2) and not has_meta("_f2_pressed"):
		toggle_debug_overlay()
		set_meta("_f2_pressed", true)
	elif not Input.is_key_pressed(KEY_F2):
		remove_meta("_f2_pressed")
	
	if Input.is_key_pressed(KEY_F3) and not has_meta("_f3_pressed"):
		cycle_debug_mode()
		set_meta("_f3_pressed", true)
	elif not Input.is_key_pressed(KEY_F3):
		remove_meta("_f3_pressed")

func toggle_debug_overlay():
	show_debug_overlay = !show_debug_overlay
	print("🎛️ Debug overlay: %s" % ("ON" if show_debug_overlay else "OFF"))

func cycle_debug_mode():
	match debug_chunk_type:
		"avenue":
			debug_chunk_type = "street"
			print("🔄 Debug mode: STREET chunks")
		"street":
			debug_chunk_type = "both"
			print("🔄 Debug mode: BOTH chunks")
		"both":
			debug_chunk_type = "avenue"
			print("🔄 Debug mode: AVENUE chunks")
		_:
			debug_chunk_type = "avenue"
			print("🔄 Debug mode: AVENUE chunks (default)")

# === DEBUG OVERLAY CLASS ===

class DebugOverlay extends Control:
	var city: CityGeneratorV3
	
	func _init(generator):
		city = generator
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	func _draw():
		if not city or not city.show_debug_overlay:
			return
		
		var cam = get_viewport().get_camera_3d()
		if not cam:
			return
		
		var is_top_view = (-cam.global_transform.basis.z).angle_to(Vector3.DOWN) <= PI * 0.42
		if not is_top_view:
			draw_info_panel()
			return
		
		draw_chunk_visualization()
		draw_info_panel()
	
	func draw_chunk_visualization():
		match city.debug_chunk_type:
			"avenue":
				draw_avenue_chunks()
				draw_district_polygons()  # Mostrar distritos en modo avenue
			"street":
				draw_street_chunks()
				draw_stable_manzanas()
			"both":
				draw_avenue_chunks()
				draw_district_polygons()  # Mostrar distritos
				draw_street_chunks()
				draw_stable_manzanas()
	
	func draw_avenue_chunks():
		var center_chunk = city.chunk_manager.get_avenue_chunk_coord(city.player_position.x, city.player_position.y)
		
		for dx in range(-city.avenue_render_distance, city.avenue_render_distance + 1):
			for dy in range(-city.avenue_render_distance, city.avenue_render_distance + 1):
				var chunk_coord = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
				var bounds = Rect2(
					chunk_coord.x * city.avenue_chunk_size,
					chunk_coord.y * city.avenue_chunk_size,
					city.avenue_chunk_size,
					city.avenue_chunk_size
				)
				draw_rect_3d(bounds, Color.BLUE, 2.0)
	
	func draw_street_chunks():
		var center_chunk = city.chunk_manager.get_street_chunk_coord(city.player_position.x, city.player_position.y)
		
		for dx in range(-city.street_render_distance, city.street_render_distance + 1):
			for dy in range(-city.street_render_distance, city.street_render_distance + 1):
				var chunk_coord = Vector2i(center_chunk.x + dx, center_chunk.y + dy)
				var bounds = Rect2(
					chunk_coord.x * city.street_chunk_size,
					chunk_coord.y * city.street_chunk_size,
					city.street_chunk_size,
					city.street_chunk_size
				)
				draw_rect_3d(bounds, Color.GREEN, 1.0)
	
	func draw_stable_manzanas():
		if not city.manzana_manager:
			return
		
		var cam = get_viewport().get_camera_3d()
		
		# Dibujar manzanas generadas del manager
		var stable_manzanas = city.manzana_manager.get_debug_info()
		for manzana_info in stable_manzanas:
			var polygon = manzana_info.get("polygon", PackedVector2Array())
			var is_generated = manzana_info.get("malla_generada", false)
			var color = Color.LIME_GREEN if is_generated else Color.ORANGE
			
			if polygon.size() >= 3:
				draw_polygon_3d(cam, polygon, color, "GEN" if is_generated else "PEND")
		
		# Dibujar TODAS las manzanas visibles (generadas y no generadas)
		draw_all_visible_manzanas(cam)
	
	func draw_rect_3d(rect: Rect2, color: Color, width: float):
		var cam = get_viewport().get_camera_3d()
		var corners_3d = [
			Vector3(rect.position.x, 0, rect.position.y),
			Vector3(rect.end.x, 0, rect.position.y),
			Vector3(rect.end.x, 0, rect.end.y),
			Vector3(rect.position.x, 0, rect.end.y)
		]
		
		var corners_2d = []
		var all_visible = true
		for corner in corners_3d:
			if cam.to_local(corner).z > 0:
				all_visible = false
				break
			corners_2d.append(cam.unproject_position(corner))
		
		if all_visible:
			for i in range(4):
				draw_line(corners_2d[i], corners_2d[(i + 1) % 4], color, width)
	
	func draw_polygon_3d(cam: Camera3D, polygon: PackedVector2Array, color: Color, label: String = ""):
		var screen_points = []
		var all_visible = true
		
		for vertex in polygon:
			var world_pos = Vector3(vertex.x, 0.5, vertex.y)
			if cam.to_local(world_pos).z > 0:
				all_visible = false
				break
			screen_points.append(cam.unproject_position(world_pos))
		
		if all_visible and screen_points.size() >= 3:
			for i in range(screen_points.size()):
				draw_line(screen_points[i], screen_points[(i + 1) % screen_points.size()], color, 2.0)
			
			draw_colored_polygon(PackedVector2Array(screen_points), Color(color.r, color.g, color.b, 0.2))
			
			if label != "":
				var center_screen = Vector2.ZERO
				for p in screen_points:
					center_screen += p
				center_screen /= screen_points.size()
				draw_string(ThemeDB.fallback_font, center_screen, label, 
						   HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)
	
	func draw_district_polygons():
		if not city.current_districts or city.current_districts.is_empty():
			return
		
		var cam = get_viewport().get_camera_3d()
		
		for distrito in city.current_districts:
			var polygon = distrito.get("vertices", PackedVector2Array())
			if polygon.size() >= 3:
				draw_polygon_3d(cam, polygon, Color.CYAN, "DISTRICT")
	
	func draw_all_visible_manzanas(cam: Camera3D):
		# Obtener todas las manzanas visibles (generadas en este frame)
		var street_points = city.get_street_points_in_render_distance()
		var district_assignments = city.assign_street_points_to_districts(street_points)
		
		for distrito_hash in district_assignments:
			var points_in_district = district_assignments[distrito_hash]
			if points_in_district.size() < 3:
				continue
			
			var distrito_polygon = city.find_district_polygon_by_hash(distrito_hash)
			if distrito_polygon.is_empty():
				continue
			
			var manzana_polygons = city.generate_voronoi_for_district(points_in_district, distrito_polygon)
			
			for point in points_in_district:
				var punto_hash = StabilityChecker.get_point_hash(point)
				var manzana_data = manzana_polygons.get(punto_hash, {})
				var polygon = manzana_data.get("vertices", PackedVector2Array())
				
				if polygon.size() >= 3:
					# Solo dibujar si NO está en el manager (para evitar duplicados)
					if not city.manzana_manager.has_manzana(punto_hash):
						draw_polygon_3d(cam, polygon, Color.YELLOW, "VIS")
	
	func draw_info_panel():
		var chunk_info = city.chunk_manager.get_debug_info()
		var manzana_info = city.manzana_manager.get_stats() if city.manzana_manager else {"stable_count": 0, "generated_count": 0}
		
		var info = [
			"Mode: %s chunks" % city.debug_chunk_type.to_upper(),
			"Avenue chunks: %d (%d points)" % [chunk_info.avenue_chunks_loaded, chunk_info.total_avenue_points],
			"Street chunks: %d (%d points)" % [chunk_info.street_chunks_loaded, chunk_info.total_street_points],
			"Stable manzanas: %d" % manzana_info.stable_count,
			"Generated meshes: %d" % manzana_info.generated_count,
			"Player: (%.0f,%.0f)" % [city.player_position.x, city.player_position.y],
			"[F2] Toggle Debug | [F3] Cycle Mode",
			"[Blue] = Avenue Chunks | [Green] = Street Chunks",
			"[Cyan] = District Polygons",
			"[Lime] = Generated Manzanas | [Orange] = Pending Manzanas",
			"[Yellow] = All Visible Manzanas"
		]
		
		for i in range(info.size()):
			draw_string(ThemeDB.fallback_font, Vector2(10, 30 + i * 20), info[i], 
					   HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
