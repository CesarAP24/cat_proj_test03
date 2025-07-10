extends Node3D
class_name CityGeneratorV2

var chunk_manager: DoubleLayerChunkManager
var district_manager: StableDistrictManager
var block_manager: SemiStableBlockManager

@export_group("Chunk Configuration")
@export var avenue_chunk_size: int = 500
@export var street_chunk_size: int = 100
@export var avenue_render_distance: int = 3
@export var street_render_distance: int = 8

@export_group("Points Per Chunk")
@export var max_avenue_points_per_chunk: int = 4
@export var max_street_points_per_chunk: int = 16

@export_group("Mesh Generation")
@export var mesh_generation_distance: float = 200.0

@export_group("Geometry")
@export var avenue_padding: float = 12.0
@export var block_padding: float = 10.0
@export var lot_size: int = 100

@export_group("Debug")
@export var show_debug_overlay: bool = true
@export var debug_chunk_type: String = "avenue"

var player_position: Vector2
var current_avenue_chunk: Vector2i
var current_street_chunk: Vector2i
var last_avenue_chunk: Vector2i
var last_street_chunk: Vector2i

var generation_in_progress: bool = false
var current_districts: Array = []

var containers: Dictionary = {}

var debug_data: Dictionary = {
	"districts": [],
	"blocks": [],
	"stable_districts": 0,
	"stable_blocks": 0,
	"generation_stats": {}
}

var cat_handler: Node3D
var debug_canvas: CanvasLayer
var debug_control: DebugOverlay

class DebugOverlay extends Control:
	var city: CityGeneratorV2
	
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
		
		draw_chunk_grid()
		draw_geometry_layers()
		draw_info_panel()
	
	func draw_chunk_grid():
		if city.debug_chunk_type == "avenue":
			var chunks = city.chunk_manager.get_avenue_chunks_around(city.player_position)
			for chunk in chunks:
				draw_chunk_bounds(chunk, city.chunk_manager.avenue_chunk_size, Color.BLUE)
		else:
			var chunks = city.chunk_manager.get_street_chunks_around(city.player_position)
			for chunk in chunks:
				draw_chunk_bounds(chunk, city.chunk_manager.street_chunk_size, Color.GREEN)
	
	func draw_chunk_bounds(chunk: Dictionary, size: int, color: Color):
		var cam = get_viewport().get_camera_3d()
		var corners_3d = [
			Vector3(chunk.chunk_x * size, 0, chunk.chunk_y * size),
			Vector3((chunk.chunk_x + 1) * size, 0, chunk.chunk_y * size),
			Vector3((chunk.chunk_x + 1) * size, 0, (chunk.chunk_y + 1) * size),
			Vector3(chunk.chunk_x * size, 0, (chunk.chunk_y + 1) * size)
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
				draw_line(corners_2d[i], corners_2d[(i + 1) % 4], color, 2.0)
	
	func draw_geometry_layers():
		if city.debug_chunk_type == "avenue":
			draw_polygon_layer(city.debug_data.districts, Color.YELLOW, 3.0)
		else:
			draw_polygon_layer(city.debug_data.blocks, Color.CYAN, 1.0)
	
	func draw_polygon_layer(polygons: Array, color: Color, width: float):
		var cam = get_viewport().get_camera_3d()
		
		for poly_data in polygons:
			var vertices = poly_data.get("vertices", poly_data.get("polygon", []))
			if vertices.size() < 3: 
				continue
			
			var screen_points = []
			var visible = true
			
			for vertex in vertices:
				var world_pos = Vector3(vertex.x, 0.5, vertex.y)
				if cam.to_local(world_pos).z > 0:
					visible = false
					break
				screen_points.append(cam.unproject_position(world_pos))
			
			if visible and screen_points.size() >= 3:
				for i in range(screen_points.size()):
					draw_line(screen_points[i], screen_points[(i + 1) % screen_points.size()], color, width)
	
	func draw_info_panel():
		var chunk_info = city.chunk_manager.get_debug_info()
		var district_info = city.district_manager.get_memory_usage()
		var block_info = city.block_manager.get_memory_usage()
		
		var info = [
			"Mode: %s chunks" % city.debug_chunk_type,
			"Avenidas: %d chunks" % chunk_info.avenue_chunks_loaded,
			"Calles: %d chunks (%d assigned)" % [chunk_info.street_chunks_loaded, chunk_info.get("total_assigned_points", 0)],
			"Player: (%.0f,%.0f)" % [city.player_position.x, city.player_position.y],
			"Memoria: %.1fMB total" % [district_info.memory_estimate_mb + block_info.memory_estimate_mb]
		]
		
		for i in range(info.size()):
			draw_string(ThemeDB.fallback_font, Vector2(10, 30 + i * 20), info[i], 
					   HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _ready():
	setup_system()
	setup_debug_overlay()
	find_cat_handler()
	call_deferred("generate_city_initial")

func setup_system():
	chunk_manager = DoubleLayerChunkManager.new()
	district_manager = StableDistrictManager.new()
	block_manager = SemiStableBlockManager.new()
	
	chunk_manager.avenue_chunk_size = avenue_chunk_size
	chunk_manager.street_chunk_size = street_chunk_size
	chunk_manager.avenue_render_distance = avenue_render_distance
	chunk_manager.street_render_distance = street_render_distance
	chunk_manager.max_avenue_points_per_chunk = max_avenue_points_per_chunk
	chunk_manager.max_street_points_per_chunk = max_street_points_per_chunk
	
	setup_containers()
	
	district_manager.district_became_stable.connect(_on_district_became_stable)
	district_manager.district_became_fully_stable.connect(_on_district_became_fully_stable)
	block_manager.cache_limit_reached.connect(_on_cache_limit_reached)

func setup_containers():
	for name in ["Districts", "Blocks", "Buildings"]:
		var container = Node3D.new()
		container.name = name
		add_child(container)
		containers[name.to_lower()] = container

func setup_debug_overlay():
	debug_canvas = CanvasLayer.new()
	debug_canvas.layer = 100
	add_child(debug_canvas)
	debug_control = DebugOverlay.new(self)
	debug_canvas.add_child(debug_control)

func find_cat_handler():
	cat_handler = get_node("../../CityTest")
	if not cat_handler:
		cat_handler = get_node("../CityTest")

func _process(_delta):
	update_player_position()
	
	if show_debug_overlay:
		debug_control.queue_redraw()
	
	if not generation_in_progress and needs_update():
		generation_in_progress = true
		call_deferred("handle_chunk_change")

func update_player_position():
	if cat_handler and cat_handler.has_method("obtener_centro"):
		var pos = cat_handler.obtener_centro()
		player_position = Vector2(pos.x, pos.z)
	else:
		player_position = Vector2.ZERO

func needs_update() -> bool:
	var new_avenue_chunk = chunk_manager.get_avenue_chunk_coord(player_position.x, player_position.y)
	var new_street_chunk = chunk_manager.get_street_chunk_coord(player_position.x, player_position.y)
	
	if current_avenue_chunk != new_avenue_chunk:
		last_avenue_chunk = current_avenue_chunk
		current_avenue_chunk = new_avenue_chunk
		return true
	elif current_street_chunk != new_street_chunk:
		last_street_chunk = current_street_chunk  
		current_street_chunk = new_street_chunk
		return true
	
	return false

func handle_chunk_change():
	var start_time = Time.get_ticks_msec()
	
	if last_avenue_chunk != current_avenue_chunk:
		on_avenue_chunk_changed()
	else:
		on_street_chunk_changed()
	
	var generation_time = Time.get_ticks_msec() - start_time
	debug_data.generation_stats["last_generation_time"] = generation_time
	
	generation_in_progress = false

func on_avenue_chunk_changed():
	chunk_manager.clear_district_assignments()
	block_manager.clear_aux_cache()
	GeometryStabilityChecker.clear_stability_cache()
	hide_all_geometry()
	regenerate_full_geometry()

func on_street_chunk_changed():
	regenerate_blocks_only()

func generate_city_initial():
	update_player_position()
	current_avenue_chunk = chunk_manager.get_avenue_chunk_coord(player_position.x, player_position.y)
	current_street_chunk = chunk_manager.get_street_chunk_coord(player_position.x, player_position.y)
	regenerate_full_geometry()

func regenerate_full_geometry():
	var avenue_chunks = chunk_manager.get_avenue_chunks_around(player_position)
	var avenue_points = []
	
	for chunk in avenue_chunks:
		avenue_points.append_array(chunk.avenue_points.map(func(p): return p.position))
	
	if avenue_points.size() < 3:
		return
	
	var bounds = get_world_bounds()
	var generated_districts = VoronoiGenerator.generate_voronoi(PackedVector2Array(avenue_points), bounds)
	
	current_districts = generated_districts
	debug_data.districts = generated_districts
	debug_data.generation_stats["districts_generated"] = generated_districts.size()
	
	chunk_manager.assign_all_current_points_to_districts(current_districts)
	
	var stable_district_count = 0
	for district in generated_districts:
		if process_district(district):
			stable_district_count += 1
	
	debug_data.stable_districts = stable_district_count

func process_district(district: Dictionary) -> bool:
	var avenue_point = district.site
	var district_hash = district_manager.get_district_hash(avenue_point)
	
	if district_manager.has_stable_district(district_hash):
		var cached_district = district_manager.load_stable_district(district_hash)
		show_district_from_cache(district_hash, cached_district)
		return true
	
	var is_stable = GeometryStabilityChecker.is_district_geometrically_stable(avenue_point, chunk_manager)
	
	var district_meshes = create_district_meshes(district)
	show_district_meshes(district_meshes)
	
	if is_stable:
		var street_points = chunk_manager.get_points_for_district(district_hash)
		var district_data = {
			"polygon": district.vertices,
			"avenue_point": district.site,
			"assigned_street_points": street_points,
			"stable_blocks": {},
			"is_fully_stable": false,
			"bounds": GeometryUtils.get_polygon_bounds(district.vertices)
		}
		district_manager.save_stable_district(district_hash, district_data, district_meshes)
		return true
	
	return false

func show_district_from_cache(district_hash: String, cached_district: Dictionary):
	if district_manager.has_cached_meshes(district_hash):
		district_manager.set_district_visibility(district_hash, true)
	else:
		var district_meshes = create_district_meshes_from_cached_data(cached_district)
		show_district_meshes(district_meshes)
		district_manager.save_stable_district(district_hash, cached_district, district_meshes)

func create_district_meshes(district: Dictionary) -> Array:
	var district_hash = district_manager.get_district_hash(district.site)
	var street_points = chunk_manager.get_points_for_district(district_hash)
	
	if street_points.size() < 3:
		return []
	
	var district_bounds = GeometryUtils.get_polygon_bounds(district.vertices)
	var blocks_geometry = VoronoiGenerator.generate_voronoi(PackedVector2Array(street_points), district_bounds)
	
	debug_data.blocks.append_array(blocks_geometry)
	
	var all_meshes = []
	var stable_blocks_created = 0
	
	for block in blocks_geometry:
		var block_hash = block_manager.get_block_hash(block.site)
		
		if block_manager.has_cached_meshes(block_hash):
			var cached_meshes = block_manager.get_cached_meshes(block_hash)
			all_meshes.append_array(cached_meshes)
			block_manager.set_block_visibility(block_hash, true)
		else:
			var is_block_stable = GeometryStabilityChecker.is_block_geometrically_stable(
				block.site, chunk_manager, true
			)
			
			var block_meshes = create_block_meshes(block)
			if block_meshes.size() > 0:
				all_meshes.append_array(block_meshes)
				
				var block_data = {
					"point": block.site,
					"polygon": block.vertices,
					"is_stable": is_block_stable,
					"is_currently_visible": true
				}
				
				if is_block_stable:
					block_manager.save_semi_stable_block(block_hash, block_data, block_meshes)
					stable_blocks_created += 1
	
	debug_data.stable_blocks += stable_blocks_created
	return all_meshes

func create_district_meshes_from_cached_data(cached_district: Dictionary) -> Array:
	var street_points = cached_district.assigned_street_points
	
	if street_points.size() < 3:
		return []
	
	var district_bounds = cached_district.get("bounds", Rect2())
	var blocks_geometry = VoronoiGenerator.generate_voronoi(PackedVector2Array(street_points), district_bounds)
	
	var all_meshes = []
	
	for block in blocks_geometry:
		var block_hash = block_manager.get_block_hash(block.site)
		
		if block_manager.has_cached_meshes(block_hash):
			var cached_meshes = block_manager.get_cached_meshes(block_hash)
			all_meshes.append_array(cached_meshes)
			block_manager.set_block_visibility(block_hash, true)
		else:
			var block_meshes = create_block_meshes(block)
			if block_meshes.size() > 0:
				all_meshes.append_array(block_meshes)
				
				var block_data = {
					"point": block.site,
					"polygon": block.vertices,
					"is_stable": true,
					"is_currently_visible": true
				}
				
				block_manager.save_semi_stable_block(block_hash, block_data, block_meshes)
	
	return all_meshes

func create_block_meshes(block: Dictionary) -> Array:
	var padded_polygon = GeometryUtils.create_padded_polygon(block.vertices, block_padding)
	
	if padded_polygon.size() < 3:
		return []
	
	var lots = PolygonSubdivider.subdivide_polygon(padded_polygon, lot_size)
	var created_meshes = []
	var lot_center = GeometryUtils.get_polygon_center(padded_polygon)
	var distance_to_player = player_position.distance_to(lot_center)
	
	if distance_to_player <= mesh_generation_distance:
		for lot in lots:
			if lot.polygon.size() >= 3:
				var building = BuildingMeshGenerator.create_building(lot.polygon, lot_center)
				if building:
					containers.buildings.add_child(building)
					created_meshes.append(building)
	
	return created_meshes

func show_district_meshes(meshes: Array):
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.visible = true

func hide_district_meshes(meshes: Array):
	for mesh in meshes:
		if is_instance_valid(mesh):
			mesh.visible = false

func regenerate_blocks_only():
	for district in current_districts:
		process_district(district)

func hide_all_geometry():
	for hash in district_manager.stable_districts:
		district_manager.set_district_visibility(hash, false)
	
	for hash in block_manager.aux_blocks:
		block_manager.set_block_visibility(hash, false)

func get_world_bounds() -> Rect2:
	var avenue_size = chunk_manager.avenue_chunk_size
	var render_dist = chunk_manager.avenue_render_distance
	var center = Vector2(
		current_avenue_chunk.x * avenue_size + avenue_size / 2,
		current_avenue_chunk.y * avenue_size + avenue_size / 2
	)
	var total_size = avenue_size * (render_dist * 2 + 1)
	return Rect2(center - Vector2(total_size/2, total_size/2), Vector2(total_size, total_size))

func _on_district_became_stable(district_hash: String):
	pass
	
func _on_district_became_fully_stable(district_hash: String):
	pass
	
func _on_cache_limit_reached(removed_count: int):
	pass
	
func toggle_debug():
	show_debug_overlay = !show_debug_overlay

func toggle_debug_mode():
	debug_chunk_type = "street" if debug_chunk_type == "avenue" else "avenue"

func force_regeneration():
	generation_in_progress = true
	chunk_manager.clear_district_assignments()
	hide_all_geometry()
	block_manager.clear_aux_cache()
	GeometryStabilityChecker.clear_stability_cache()
	regenerate_full_geometry()
	generation_in_progress = false

func get_system_stats() -> Dictionary:
	return {
		"chunk_manager": chunk_manager.get_debug_info(),
		"district_manager": district_manager.get_debug_info(),
		"block_manager": block_manager.get_debug_info(),
		"stability_cache": GeometryStabilityChecker.get_cache_stats(),
		"generation_stats": debug_data.generation_stats
	}
