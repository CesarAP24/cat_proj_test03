# CityGenerator.gd - Ultra optimizado y fluido con filtro de distancia
extends Node3D

@export_group("Generation")
@export var seed_string: String = "ciudad_elegante"
@export var density: float = 0.1
@export var chunk_size: int = 110
@export var render_distance: int = 9
@export var avenue_percent: float = 0.1

@export_group("Geometry")
@export var avenue_padding: float = 12.0
@export var block_padding: float = 10.0
@export var lot_size: int = 100
@export var stability_threshold: float = 0.5

@export_group("Mesh Generation")
@export var mesh_generation_distance: float = 200.0  

@export_group("Debug")
@export var show_debug_overlay: bool = true

var chunk_manager: ChunkManager
var cat_handler: Node3D
var player_pos: Vector2
var current_chunk: Vector2i
var last_params_hash: int
var generation_in_progress: bool = false

var containers: Dictionary = {}
var debug_canvas: CanvasLayer
var debug_control: DebugOverlay

var districts: Array = []
var blocks: Array = []
var lots: Array = []
var debug_data: Dictionary = {"points": [], "avenues": [], "chunks": []}

class DebugOverlay extends Control:
	var city: Node3D
	
	func _init(generator): 
		city = generator
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	func _draw():
		if not city or not city.show_debug_overlay: return
		var cam = get_viewport().get_camera_3d()
		if not cam: return
		
		var is_top_view = (-cam.global_transform.basis.z).angle_to(Vector3.DOWN) <= PI * 0.42
		if not is_top_view: 
			draw_info()
			return
		
		draw_chunks()
		draw_geometry_layers()
		draw_points()
		draw_mesh_distance_circle()  # Nueva función para mostrar el círculo de distancia
		draw_info()
	
	func draw_chunks():
		for line in city.debug_data.chunks:
			draw_line(line[0], line[1], Color.GRAY, 1.0)
	
	func draw_geometry_layers():
		var layers = [
			{"data": city.districts, "color": Color.YELLOW, "width": 4.0, "fill": Color(1,1,0,0.1)},
			{"data": city.blocks, "color": Color.WHITE, "width": 2.0, "fill": Color(0,1,0,0.1)},
			{"data": city.lots, "color": Color.CYAN, "width": 1.0, "fill": Color(0,1,1,0.05)}
		]
		
		for layer in layers:
			draw_polygon_layer(layer.data, layer.color, layer.width, layer.fill)
	
	func draw_polygon_layer(polygons: Array, color: Color, width: float, fill_color: Color):
		var cam = get_viewport().get_camera_3d()
		var viewport_size = get_viewport().get_visible_rect().size
		
		for poly_data in polygons:
			var vertices = poly_data.get("vertices", poly_data.get("polygon", []))
			if vertices.size() < 3: continue
			
			var screen_points = []
			var visible = true
			
			for vertex in vertices:
				var world_pos = Vector3(vertex.x, 0.2, vertex.y)
				if cam.to_local(world_pos).z > 0: 
					visible = false
					break
				
				var screen_pos = cam.unproject_position(world_pos)
				if screen_pos.x < -100 or screen_pos.x > viewport_size.x + 100 or screen_pos.y < -100 or screen_pos.y > viewport_size.y + 100:
					visible = false
					break
				screen_points.append(screen_pos)
			
			if visible and screen_points.size() >= 3:
				var bounds = get_bounds(screen_points)
				if bounds.size.x < viewport_size.x * 2 and bounds.size.y < viewport_size.y * 2:
					draw_colored_polygon(PackedVector2Array(screen_points), fill_color)
					for i in range(screen_points.size()):
						draw_line(screen_points[i], screen_points[(i + 1) % screen_points.size()], color, width)
					
					if poly_data.has("street_side"):
						var idx = poly_data.street_side
						draw_line(screen_points[idx], screen_points[(idx + 1) % screen_points.size()], Color.RED, 3.0)
	
	func draw_points():
		for pos in city.debug_data.points: draw_circle(pos, 3.0, Color.RED)
		for pos in city.debug_data.avenues: draw_circle(pos, 5.0, Color.BLUE)
	
	# Nueva función para mostrar el círculo de distancia de generación de mallas
	func draw_mesh_distance_circle():
		var cam = get_viewport().get_camera_3d()
		if not cam: return
		
		var player_pos_3d = Vector3(city.player_pos.x, 0, city.player_pos.y)
		var player_screen_pos = cam.unproject_position(player_pos_3d)
		
		# Calcular el radio en pantalla basado en la distancia real
		var edge_pos_3d = Vector3(city.player_pos.x + city.mesh_generation_distance, 0, city.player_pos.y)
		var edge_screen_pos = cam.unproject_position(edge_pos_3d)
		var screen_radius = player_screen_pos.distance_to(edge_screen_pos)
		
		# Dibujar círculo de distancia de generación de mallas
		if screen_radius > 0 and screen_radius < 2000:  # Solo dibujar si es visible y razonable
			draw_arc(player_screen_pos, screen_radius, 0, TAU, 64, Color.ORANGE, 2.0)
			draw_string(ThemeDB.fallback_font, player_screen_pos + Vector2(10, -10), 
						"Mesh Distance: %.0fm" % city.mesh_generation_distance, 
						HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.ORANGE)
	
	func draw_info():
		var meshes_generated = 0
		if city.containers.has("buildings"):
			meshes_generated = city.containers.buildings.get_child_count()
		
		var info = [
			"Pts:%d | Ave:%d | Dist:%d | Blk:%d | Lots:%d | Meshes:%d" % [
				city.debug_data.points.size(), city.debug_data.avenues.size(),
				city.districts.size(), city.blocks.size(), city.lots.size(), meshes_generated
			],
			"Player:(%.0f,%.0f) | Chunk:(%d,%d) | MeshDist:%.0fm" % [
				city.player_pos.x, city.player_pos.y, city.current_chunk.x, city.current_chunk.y, city.mesh_generation_distance
			]
		]
		for i in range(info.size()):
			draw_string(ThemeDB.fallback_font, Vector2(10, 30 + i * 20), info[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	
	func get_bounds(points: Array) -> Rect2:
		if points.is_empty(): return Rect2()
		var min_p = points[0]
		var max_p = points[0]
		for p in points:
			min_p = Vector2(min(min_p.x, p.x), min(min_p.y, p.y))
			max_p = Vector2(max(max_p.x, p.x), max(max_p.y, p.y))
		return Rect2(min_p, max_p - min_p)

func _ready():
	setup_containers()
	chunk_manager = ChunkManager.new()
	chunk_manager.stability_threshold = stability_threshold
	cat_handler = get_node("../../CityTest")
	
	debug_canvas = CanvasLayer.new()
	debug_canvas.layer = 100
	add_child(debug_canvas)
	debug_control = DebugOverlay.new(self)
	debug_canvas.add_child(debug_control)
	
	generate_city()

func setup_containers():
	for name in ["Districts", "Blocks", "Buildings"]:
		var container = Node3D.new()
		container.name = name
		add_child(container)
		containers[name.to_lower()] = container

func _process(_delta):
	update_player_position()
	if show_debug_overlay: 
		update_debug_realtime()
	if not generation_in_progress and needs_update():
		generation_in_progress = true
		call_deferred("generate_city_async")

func update_player_position():
	if cat_handler and cat_handler.has_method("obtener_centro"):
		var pos = cat_handler.obtener_centro()
		player_pos = Vector2(pos.x, pos.z)
	else:
		player_pos = Vector2.ZERO

func update_debug_realtime():
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	debug_data = {"points": [], "avenues": [], "chunks": []}
	var viewport_size = get_viewport().get_visible_rect().size
	var current_player_chunk = chunk_manager.get_chunk_coord(player_pos.x, player_pos.y, chunk_size)
	
	for dx in range(-render_distance, render_distance + 1):
		for dy in range(-render_distance, render_distance + 1):
			if max(abs(dx), abs(dy)) <= render_distance:
				var cx = current_player_chunk.x + dx
				var cy = current_player_chunk.y + dy
				
				# Chunk grid
				var corners_3d = [Vector3(cx * chunk_size, 0, cy * chunk_size), 
								  Vector3((cx + 1) * chunk_size, 0, cy * chunk_size), 
								  Vector3((cx + 1) * chunk_size, 0, (cy + 1) * chunk_size), 
								  Vector3(cx * chunk_size, 0, (cy + 1) * chunk_size)]
				var corners_2d = corners_3d.map(func(corner): return cam.unproject_position(corner))
				for i in range(4):
					debug_data.chunks.append([corners_2d[i], corners_2d[(i + 1) % 4]])
				
				# Points
				var chunk = chunk_manager.generate_chunk(cx, cy, seed_string, density, chunk_size)
				for point in chunk.points:
					var screen_pos = cam.unproject_position(Vector3(point.position.x, 5.0, point.position.y))
					if is_point_visible(screen_pos, viewport_size):
						var avenue_hash_str = "%s_avenue_%s" % [point.id, seed_string]
						var is_avenue = float(abs(avenue_hash_str.hash()) % 10000) / 10000.0 < avenue_percent
						debug_data["avenues" if is_avenue else "points"].append(screen_pos)
	
	if debug_control: debug_control.queue_redraw()

func is_point_visible(screen_pos: Vector2, viewport_size: Vector2) -> bool:
	return screen_pos.x >= -100 and screen_pos.x <= viewport_size.x + 100 and screen_pos.y >= -100 and screen_pos.y <= viewport_size.y + 100

func needs_update() -> bool:
	var params_hash = get_params().hash()
	var chunk = chunk_manager.get_chunk_coord(player_pos.x, player_pos.y, chunk_size)
	
	# Siempre actualizar si cambian los parámetros
	if last_params_hash != params_hash:
		last_params_hash = params_hash
		current_chunk = chunk
		print("🔄 Parámetros cambiaron - regenerando")
		return true
	
	# Siempre actualizar si cambia de chunk
	if current_chunk != chunk:
		print("🚶 Cambio de chunk: (%d,%d) → (%d,%d)" % [current_chunk.x, current_chunk.y, chunk.x, chunk.y])
		current_chunk = chunk
		return true
	
	return false

func get_params() -> Dictionary:
	return {
		"seed": seed_string, "density": density, "chunk_size": chunk_size,
		"render_distance": render_distance, "avenue_percent": avenue_percent,
		"avenue_padding": avenue_padding, "block_padding": block_padding,
		"lot_size": lot_size, "stability_threshold": stability_threshold,
		"mesh_generation_distance": mesh_generation_distance  # Incluir en el hash de parámetros
	}

func generate_city_async():
	generate_city()
	generation_in_progress = false

func generate_city():
	var chunks = chunk_manager.get_nearby_chunks(current_chunk, seed_string, density, chunk_size, render_distance)
	var all_points = chunks.map(func(chunk): return chunk.points).reduce(func(acc, points): acc.append_array(points); return acc, [])
	
	if all_points.size() >= 3: update_city_geometry_stable(all_points)

func update_city_geometry_stable(all_points: Array):
	clear_geometry()
	
	var avenue_points = all_points.filter(func(p): 
		var avenue_hash_str = "%s_avenue_%s" % [p.id, seed_string]
		return float(abs(avenue_hash_str.hash()) % 10000) / 10000.0 < avenue_percent
	)
	if avenue_points.size() < 3: return
	
	# Generar siempre - removemos el sistema de cache problemático por ahora
	districts = generate_voronoi(avenue_points.map(func(p): return p.position), get_bounds(all_points))
	
	for district in districts:
		district.padded_vertices = GeometryUtils.create_padded_polygon(district.vertices, avenue_padding)
		district.contained_points = []
		for point in all_points:
			if GeometryUtils.point_in_polygon(point.position, district.padded_vertices):
				district.contained_points.append(point.position)
	
	generate_blocks_and_lots_stable()
	create_buildings_with_distance_filter()  # Función modificada
	
	print("🏙️ Generados: %d distritos, %d manzanas, %d lotes" % [districts.size(), blocks.size(), lots.size()])

func generate_voronoi(sites: Array, bounds: Rect2) -> Array:
	return VoronoiGenerator.generate_voronoi(PackedVector2Array(sites), bounds)

func generate_blocks_and_lots_stable():
	blocks.clear()
	lots.clear()
	
	for district in districts:
		if district.contained_points.size() >= 3:
			var local_blocks = generate_voronoi(district.contained_points, GeometryUtils.get_polygon_bounds(district.padded_vertices))
			for block in local_blocks:
				var clipped = GeometryUtils.clip_polygon(block.vertices, district.padded_vertices)
				if clipped and clipped.size() >= 3:
					var padded = GeometryUtils.create_padded_polygon(clipped, block_padding)
					blocks.append({"site": block.site, "vertices": padded, "district": district.site})
					lots.append_array(PolygonSubdivider.subdivide_polygon(padded, lot_size))

# Nueva función con filtro de distancia
func create_buildings_with_distance_filter():
	var buildings_created = 0
	var buildings_skipped = 0
	
	for lot in lots:
		if lot.polygon.size() >= 3:
			var lot_center = GeometryUtils.get_polygon_center(lot.polygon)
			var distance_to_player = player_pos.distance_to(lot_center)
			
			# Solo generar la malla si está dentro de la distancia permitida
			if distance_to_player <= mesh_generation_distance:
				var building = BuildingMeshGenerator.create_building(lot.polygon, lot_center)
				if building: 
					containers.buildings.add_child(building)
					buildings_created += 1
			else:
				buildings_skipped += 1
	
	print("🏗️ Edificios: %d creados, %d omitidos por distancia (%.0fm)" % [buildings_created, buildings_skipped, mesh_generation_distance])

# Función auxiliar para cambiar la distancia de generación en tiempo real
func set_mesh_generation_distance(new_distance: float):
	mesh_generation_distance = new_distance
	print("📏 Nueva distancia de generación de mallas: %.0fm" % mesh_generation_distance)
	# Forzar regeneración
	last_params_hash = -1

func get_bounds(points: Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var positions = points.map(func(p): return p.position)
	return GeometryUtils.get_polygon_bounds(positions)

func clear_geometry():
	for container in containers.values():
		for child in container.get_children(): 
			child.queue_free()
	districts.clear()
	blocks.clear()
	lots.clear()
	print("🧹 Geometría limpiada")

func toggle_debug(): 
	show_debug_overlay = !show_debug_overlay
	print("Debug: ", "ON" if show_debug_overlay else "OFF")
