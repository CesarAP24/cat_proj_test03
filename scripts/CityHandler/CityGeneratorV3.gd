extends Node3D
class_name CityGeneratorV3

var chunk_manager: SpatialChunkManager
var stable_district_cache: StableDistrictCache
var unstable_street_cache: UnstableStreetCache
var mesh_visibility_manager: MeshVisibilityManager

var current_districts: Array = []
var district_stability_map: Dictionary = {}
var unstable_meshes_list: Array[MeshInstance3D] = []

@export_group("Chunk Configuratioexln")
@export var avenue_chunk_size: int = 500
@export var street_chunk_size: int = 100
@export var avenue_render_distance: int = 3
@export var street_render_distance: int = 8

@export_group("Points Per Chunk")
@export var max_avenue_points_per_chunk: int = 4
@export var max_street_points_per_chunk: int = 16

@export_group("Mesh Generation")
@export var mesh_generation_distance: float = 200.0
@export var block_padding: float = 10.0
@export var lot_size: int = 100

@export_group("Debug")
@export var show_debug_overlay: bool = true
@export var debug_chunk_type: String = "avenue"  # "avenue", "street", "both"

var player_position: Vector2
var current_avenue_chunk: Vector2i
var current_street_chunk: Vector2i
var last_avenue_chunk: Vector2i
var last_street_chunk: Vector2i

var generation_in_progress: bool = false
var containers: Dictionary = {}

var cat_handler: Node3D
var debug_canvas: CanvasLayer
var debug_control: DebugOverlay

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
		
		draw_chunk_grid()
		draw_info_panel()
	
	func draw_chunk_grid():
		if city.debug_chunk_type == "avenue":
			draw_stable_districts()
			draw_avenue_chunks()
		elif city.debug_chunk_type == "street":
			draw_street_chunks()
			draw_stable_blocks()
		elif city.debug_chunk_type == "both":
			draw_avenue_chunks()
			draw_street_chunks()
			draw_stable_blocks()
			draw_avenue_chunks()
	
	func draw_avenue_chunks():
		var chunks_bounds = []
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
				chunks_bounds.append(bounds)
		
		for bounds in chunks_bounds:
			draw_rect_3d(bounds, Color.BLUE, 2.0)
	
	func draw_street_chunks():
		var chunks_bounds = []
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
				chunks_bounds.append(bounds)
		
		for bounds in chunks_bounds:
			draw_rect_3d(bounds, Color.GREEN, 1.0)
	
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
	
	func draw_stable_districts():
		var cam = get_viewport().get_camera_3d()
		
		for distrito_hash in city.stable_district_cache.stable_districts:
			var distrito_polygon = city.get_district_polygon_by_hash(distrito_hash)
			if distrito_polygon.is_empty():
				continue
			
			var screen_points = []
			var all_visible = true
			
			for vertex in distrito_polygon:
				var world_pos = Vector3(vertex.x, 1.0, vertex.y)
				if cam.to_local(world_pos).z > 0:
					all_visible = false
					break
				screen_points.append(cam.unproject_position(world_pos))
			
			if all_visible and screen_points.size() >= 3:
				for i in range(screen_points.size()):
					draw_line(screen_points[i], screen_points[(i + 1) % screen_points.size()], Color.LIME_GREEN, 3.0)
				
				if screen_points.size() >= 3:
					draw_colored_polygon(PackedVector2Array(screen_points), Color(0, 1, 0, 0.1))
				
				var center_screen = Vector2.ZERO
				for p in screen_points:
					center_screen += p
				center_screen /= screen_points.size()
				draw_circle(center_screen, 8.0, Color.LIME_GREEN)
				draw_string(ThemeDB.fallback_font, center_screen + Vector2(10, 5), "STABLE", 
						   HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	func draw_stable_blocks():
		var cam = get_viewport().get_camera_3d()
		
		# 1. Dibujar manzanas de distritos estables (CYAN)
		for distrito_hash in city.stable_district_cache.stable_districts:
			var distrito_data = city.stable_district_cache.stable_districts[distrito_hash]
			var manzanas_estables = distrito_data.get("manzanas_estables", {})
			
			for punto_hash in manzanas_estables:
				var manzana_data = manzanas_estables[punto_hash]
				var polygon = manzana_data.get("polygon", PackedVector2Array())
				
				if polygon.size() >= 3:
					draw_polygon_3d(cam, polygon, Color.CYAN, "STABLE")
		
		# 2. Dibujar manzanas del cache auxiliar (AMARILLO)
		for punto_hash in city.unstable_street_cache.unstable_street_blocks:
			var block_data = city.unstable_street_cache.unstable_street_blocks[punto_hash]
			var polygon = block_data.get("polygon", PackedVector2Array())
			
			if polygon.size() >= 3:
				draw_polygon_3d(cam, polygon, Color.YELLOW, "AUX")
		
		# 3. Dibujar manzanas semi-estables (NARANJA)
		# Estas son manzanas visibles que no están en ningún cache
		draw_semi_stable_blocks(cam)
	
	func draw_semi_stable_blocks(cam: Camera3D):
		# Obtener manzanas que están visibles pero no cacheadas
		var semi_stable_blocks = city.get_semi_stable_blocks_info()
		
		for block_info in semi_stable_blocks:
			var polygon = block_info.get("polygon", PackedVector2Array())
			if polygon.size() >= 3:
				draw_polygon_3d(cam, polygon, Color.ORANGE, "SEMI")
	
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
	
	func draw_info_panel():
		var chunk_info = city.chunk_manager.get_debug_info()
		var district_info = city.stable_district_cache.get_cache_stats()
		var street_info = city.unstable_street_cache.get_cache_stats()
		var mesh_info = city.mesh_visibility_manager.get_mesh_count()
		
		var info = [
			"Mode: %s chunks" % city.debug_chunk_type.to_upper(),
			"Ave: %d chunks, %d puntos" % [chunk_info.avenue_chunks_loaded, chunk_info.total_avenue_points],
			"Street: %d chunks, %d puntos" % [chunk_info.street_chunks_loaded, chunk_info.total_street_points],
			"Distritos estables: %d (%d manzanas)" % [district_info.stable_districts, district_info.total_manzanas],
			"Cache aux: %d bloques (%.1f%%)" % [street_info.cached_blocks, street_info.cache_usage_percent],
			"Mallas: %d total, %d visible" % [mesh_info.total_meshes, mesh_info.visible_meshes],
			"Player: (%.0f,%.0f)" % [city.player_position.x, city.player_position.y],
			"[F2] Toggle Debug | [F3] Cycle Mode",
			"[Verde] = Distritos Estables",
			"[Cyan] = Manzanas Estables (distrito estable)",
			"[Amarillo] = Manzanas Estables (cache aux)",
			"[Naranja] = Manzanas Semi-estables"
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
	chunk_manager = SpatialChunkManager.new()
	stable_district_cache = StableDistrictCache.new()
	unstable_street_cache = UnstableStreetCache.new()
	
	setup_containers()
	mesh_visibility_manager = MeshVisibilityManager.new(containers)
	
	chunk_manager.avenue_chunk_size = avenue_chunk_size
	chunk_manager.street_chunk_size = street_chunk_size
	chunk_manager.avenue_render_distance = avenue_render_distance
	chunk_manager.street_render_distance = street_render_distance
	chunk_manager.max_avenue_points_per_chunk = max_avenue_points_per_chunk
	chunk_manager.max_street_points_per_chunk = max_street_points_per_chunk
	
	stable_district_cache.district_became_stable.connect(_on_district_became_stable)
	stable_district_cache.district_became_fully_stable.connect(_on_district_became_fully_stable)
	unstable_street_cache.cache_limit_reached.connect(_on_cache_limit_reached)

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
	
	# Manejar input de debug
	handle_debug_input()
	
	debug_control.queue_redraw()
	
	if not generation_in_progress and needs_update():
		generation_in_progress = true
		call_deferred("update")

func handle_debug_input():
	# F2 - Toggle debug overlay
	if Input.is_action_just_pressed("debug_toggle"):  # Necesitarás agregar esta acción al InputMap
		toggle_debug()
	
	# F3 - Cycle debug mode
	if Input.is_action_just_pressed("debug_mode_cycle"):  # Necesitarás agregar esta acción al InputMap
		cycle_debug_mode()
	
	# Fallback usando código de teclas si no tienes las acciones configuradas
	if Input.is_key_pressed(KEY_F2) and not has_meta("_f2_pressed"):
		if not has_method("_f2_pressed"):
			toggle_debug()
			set_meta("_f2_pressed", true)
	elif not Input.is_key_pressed(KEY_F2):
		remove_meta("_f2_pressed")
	
	if Input.is_key_pressed(KEY_F3) and not has_meta("_f3_pressed"):
		cycle_debug_mode()
		set_meta("_f3_pressed", true)
	elif not Input.is_key_pressed(KEY_F3):
		remove_meta("_f3_pressed")

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

func update():
	ocultar_mallas_no_estables()
	
	if last_avenue_chunk != current_avenue_chunk:
		update_avenidas()
	else:
		update_calles()
	
	generation_in_progress = false

func ocultar_mallas_no_estables():
	mesh_visibility_manager.hide_all_unstable_meshes()

func update_calles():
	var puntos = chunk_manager.get_street_points_in_render_distance(player_position)
	var assignment_result = chunk_manager.assign_street_points_to_districts(current_districts, puntos)
	var mapa_distrito_puntos = assignment_result[0]
	var mapa_punto_distrito = assignment_result[1]
	
	var manzanas = aplicar_voronoi_por_distrito(mapa_distrito_puntos)
	
	for punto in puntos:
		var punto_hash = StabilityChecker.get_point_hash(punto)
		
		if unstable_street_cache.has_cached_block(punto_hash):
			unstable_street_cache.show_block(punto_hash)
			continue
		
		var curr_distrito = mapa_punto_distrito.get(punto_hash, "")
		if curr_distrito != "" and stable_district_cache.has_stable_district(curr_distrito):
			if stable_district_cache.district_has_point(curr_distrito, punto_hash):
				stable_district_cache.show_point_mesh(curr_distrito, punto_hash)
				continue
		
		mesh_visibility_manager.hide_meshes_for_point(punto_hash)
		var manzana_polygon = manzanas.get(punto_hash, [])
		if manzana_polygon.size() >= 3:
			var malla = generar_malla_punto(manzana_polygon, false)
			mesh_visibility_manager.show_meshes_for_point(punto_hash, malla)
			
			if StabilityChecker.is_street_point_stable(punto, chunk_manager):
				if district_stability_map.get(curr_distrito, false):
					stable_district_cache.add_stable_block_to_district(curr_distrito, punto_hash, malla, punto, manzana_polygon)
				else:
					unstable_street_cache.save_block(punto_hash, malla, manzana_polygon)

func update_avenidas():
	var puntos_avenida = chunk_manager.get_avenue_points_in_render_distance(player_position)
	
	var bounds = get_world_bounds()
	var nuevos_distritos = VoronoiGenerator.generate_voronoi(PackedVector2Array(puntos_avenida), bounds)
	current_districts = nuevos_distritos
	
	var puntos_calle = chunk_manager.get_street_points_in_render_distance(player_position)
	var estabilidad_calle = StabilityChecker.get_stability_map_for_points(puntos_calle, chunk_manager)
	
	var assignment_result = chunk_manager.assign_street_points_to_districts(nuevos_distritos, puntos_calle)
	var mapa_distrito_puntos = assignment_result[0]
	var mapa_punto_distrito = assignment_result[1]
	
	district_stability_map.clear()
	for distrito in nuevos_distritos:
		var distrito_hash = chunk_manager.get_district_hash(distrito.site)
		district_stability_map[distrito_hash] = StabilityChecker.is_district_stable(distrito_hash, distrito.site, chunk_manager)
	
	unstable_street_cache.clear_cache()
	
	for distrito in nuevos_distritos:
		var distrito_hash = chunk_manager.get_district_hash(distrito.site)
		var current_puntos_calle = mapa_distrito_puntos.get(distrito_hash, [])
		
		if stable_district_cache.has_stable_district(distrito_hash):
			stable_district_cache.show_district_meshes(distrito_hash)
			
			var puntos_cacheados = stable_district_cache.get_cached_points(distrito_hash)
			for punto_cacheado in puntos_cacheados:
				current_puntos_calle.erase(punto_cacheado)
			
			if current_puntos_calle.size() > 0:
				procesar_puntos_calle_restantes(distrito_hash, current_puntos_calle)
			
			continue
		
		if district_stability_map.get(distrito_hash, false):
			procesar_puntos_calle_restantes(distrito_hash, current_puntos_calle)
			continue
		
		var curr_manzanas = aplicar_voronoi_distrito(distrito, current_puntos_calle)
		
		for punto_calle in current_puntos_calle:
			var punto_hash = StabilityChecker.get_point_hash(punto_calle)
			var manzana_polygon = curr_manzanas.get(punto_hash, [])
			
			if manzana_polygon.size() >= 3:
				var malla = generar_malla_punto(manzana_polygon, false)
				mesh_visibility_manager.show_meshes_for_point(punto_hash, malla)
				mesh_visibility_manager.register_unstable_mesh(punto_hash, malla)
				
				if estabilidad_calle.get(punto_hash, false):
					unstable_street_cache.save_block(punto_hash, malla, manzana_polygon)

func procesar_puntos_calle_restantes(distrito_hash: String, puntos_calle: Array):
	if puntos_calle.is_empty():
		return
	
	var distrito_polygon = get_district_polygon_by_hash(distrito_hash)
	if distrito_polygon.is_empty():
		return
	
	var distrito_data = stable_district_cache.get_stable_district(distrito_hash)
	if distrito_data.is_empty():
		var bounds = GeometryUtils.get_polygon_bounds(distrito_polygon)
		stable_district_cache.save_stable_district(distrito_hash, puntos_calle, {"bounds": bounds, "polygon": distrito_polygon})
	
	var curr_manzanas = VoronoiGenerator.generate_voronoi_for_district(PackedVector2Array(puntos_calle), distrito_polygon)
	
	for punto_calle in puntos_calle:
		var punto_hash = StabilityChecker.get_point_hash(punto_calle)
		var manzana_data = curr_manzanas.get(punto_hash, {})
		
		if manzana_data.has("vertices") and manzana_data.vertices.size() >= 3:
			var malla = generar_malla_punto(manzana_data.vertices, true)
			mesh_visibility_manager.show_meshes_for_point(punto_hash, malla)
			
			var punto_estable = StabilityChecker.is_street_point_stable(punto_calle, chunk_manager)
			if punto_estable:
				stable_district_cache.add_stable_block_to_district(distrito_hash, punto_hash, malla, punto_calle, manzana_data.vertices)
			else:
				mesh_visibility_manager.register_unstable_mesh(punto_hash, malla)

func aplicar_voronoi_por_distrito(mapa_distrito_puntos: Dictionary) -> Dictionary:
	var todas_manzanas = {}
	
	for distrito_hash in mapa_distrito_puntos:
		var puntos_distrito = mapa_distrito_puntos[distrito_hash]
		if puntos_distrito.size() < 3:
			continue
		
		var distrito_polygon = get_district_polygon_by_hash(distrito_hash)
		if distrito_polygon.is_empty():
			continue
		
		var manzanas_distrito = VoronoiGenerator.generate_voronoi_for_district(PackedVector2Array(puntos_distrito), distrito_polygon)
		
		for punto_hash in manzanas_distrito:
			todas_manzanas[punto_hash] = manzanas_distrito[punto_hash].get("vertices", [])
	
	return todas_manzanas

func aplicar_voronoi_distrito(distrito: Dictionary, puntos_calle: Array) -> Dictionary:
	if puntos_calle.size() < 3:
		return {}
	
	var distrito_bounds = GeometryUtils.get_polygon_bounds(distrito.vertices)
	var voronoi_cells = VoronoiGenerator.generate_voronoi(PackedVector2Array(puntos_calle), distrito_bounds)
	
	var resultado = {}
	for cell in voronoi_cells:
		var punto_hash = StabilityChecker.get_point_hash(cell.site)
		resultado[punto_hash] = cell.vertices
	
	return resultado

func generar_malla_punto(manzana_polygon: Array, is_stable: bool) -> Array:
	var padded_polygon = GeometryUtils.create_padded_polygon(manzana_polygon, block_padding)
	
	if padded_polygon.size() < 3:
		return []
	
	var lots = PolygonSubdivider.subdivide_polygon(padded_polygon, lot_size)
	var created_meshes = []
	var lot_center = GeometryUtils.get_polygon_center(padded_polygon)
	var distance_to_player = player_position.distance_to(lot_center)
	
	if distance_to_player <= mesh_generation_distance:
		for lot in lots:
			if lot.polygon.size() >= 3:
				var building = BuildingMeshGenerator.create_building(lot.polygon, lot_center, is_stable)
				if building:
					containers.buildings.add_child(building)
					created_meshes.append(building)
	
	return created_meshes

func generate_city_initial():
	update_player_position()
	current_avenue_chunk = chunk_manager.get_avenue_chunk_coord(player_position.x, player_position.y)
	current_street_chunk = chunk_manager.get_street_chunk_coord(player_position.x, player_position.y)
	update_avenidas()

func get_world_bounds() -> Rect2:
	var avenue_size = chunk_manager.avenue_chunk_size
	var render_dist = chunk_manager.avenue_render_distance
	var center = Vector2(
		current_avenue_chunk.x * avenue_size + avenue_size / 2,
		current_avenue_chunk.y * avenue_size + avenue_size / 2
	)
	var total_size = avenue_size * (render_dist * 2 + 1)
	return Rect2(center - Vector2(total_size/2, total_size/2), Vector2(total_size, total_size))

func get_district_polygon_by_hash(distrito_hash: String) -> PackedVector2Array:
	for distrito in current_districts:
		if chunk_manager.get_district_hash(distrito.site) == distrito_hash:
			return distrito.vertices
	
	return PackedVector2Array()

func get_semi_stable_blocks_info() -> Array:
	# Obtener todas las manzanas que están visibles pero no están en cache
	var semi_stable_blocks = []
	
	# Revisar el MeshVisibilityManager para encontrar manzanas visibles
	for punto_hash in mesh_visibility_manager.point_to_meshes:
		var meshes = mesh_visibility_manager.point_to_meshes[punto_hash]
		
		# Verificar si tiene mallas visibles
		var has_visible_meshes = false
		for mesh in meshes:
			if is_instance_valid(mesh) and mesh.visible:
				has_visible_meshes = true
				break
		
		if not has_visible_meshes:
			continue
		
		# Verificar si NO está en cache estable
		var is_in_stable_cache = false
		for distrito_hash in stable_district_cache.stable_districts:
			if stable_district_cache.district_has_point(distrito_hash, punto_hash):
				is_in_stable_cache = true
				break
		
		# Verificar si NO está en cache auxiliar
		var is_in_aux_cache = unstable_street_cache.has_cached_block(punto_hash)
		
		# Si no está en ningún cache pero está visible = semi-estable
		if not is_in_stable_cache and not is_in_aux_cache:
			# Necesitamos reconstruir el polígono para esta manzana semi-estable
			var polygon = reconstruct_polygon_for_point(punto_hash)
			if polygon.size() >= 3:
				semi_stable_blocks.append({
					"punto_hash": punto_hash,
					"polygon": polygon
				})
	
	return semi_stable_blocks

func reconstruct_polygon_for_point(punto_hash: String) -> PackedVector2Array:
	# Esta función necesita reconstruir el polígono basándose en el punto
	# Es costosa pero solo para debug
	
	# Reconstruir coordenadas del punto desde el hash
	var parts = punto_hash.split("_")
	if parts.size() < 3:
		return PackedVector2Array()
	
	var point = Vector2(float(parts[1]), float(parts[2]))
	
	# Encontrar en qué distrito está este punto
	for distrito in current_districts:
		if GeometryUtils.point_in_polygon(point, distrito.vertices):
			# Generar voronoi para este distrito y encontrar la celda del punto
			var assignment_result = chunk_manager.assign_street_points_to_districts([distrito], [point])
			var mapa_distrito_puntos = assignment_result[0]
			var distrito_hash = chunk_manager.get_district_hash(distrito.site)
			var puntos_distrito = mapa_distrito_puntos.get(distrito_hash, [])
			
			if puntos_distrito.size() >= 3:
				var distrito_polygon = distrito.vertices
				var manzanas_distrito = VoronoiGenerator.generate_voronoi_for_district(PackedVector2Array(puntos_distrito), distrito_polygon)
				
				var polygon_data = manzanas_distrito.get(punto_hash, {})
				return polygon_data.get("vertices", PackedVector2Array())
			break
	
	return PackedVector2Array()

func toggle_debug():
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

func toggle_debug_mode():
	# Función legacy - ahora usa cycle_debug_mode()
	cycle_debug_mode()

func force_regeneration():
	generation_in_progress = true
	chunk_manager.clear_district_assignments()
	mesh_visibility_manager.hide_all_unstable_meshes()
	unstable_street_cache.clear_cache()
	StabilityChecker.clear_stability_caches()
	update_avenidas()
	generation_in_progress = false

func _on_district_became_stable(distrito_hash: String):
	print("✅ Distrito se volvió estable: %s" % distrito_hash)

func _on_district_became_fully_stable(distrito_hash: String):
	print("🏆 Distrito completamente estable: %s" % distrito_hash)

func _on_cache_limit_reached(removed_count: int):
	print("⚠️ Límite de cache alcanzado, removidas %d manzanas" % removed_count)
