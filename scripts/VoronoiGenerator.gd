# VoronoiGenerator.gd - Versión final que confía en el plugin activo
class_name VoronoiGenerator

# Ya no necesitamos preload, porque el plugin hace que "Delaunay" sea global.
# Asegúrate de que el plugin del addon esté "Activo" en la configuración del proyecto.
static func generate_voronoi(sites: PackedVector2Array, bounds: Rect2) -> Array:
	if sites.size() < 3:
		return []
	
	# La clase 'Delaunay' está disponible globalmente gracias al plugin
	var delaunay = Delaunay.new()
	
	# El addon que tienes usa add_point() y triangulate()
	for p in sites:
		delaunay.add_point(p)
	var triangles: Array = delaunay.triangulate()
	
	if triangles.is_empty():
		return []
		
	var voronoi_cells = {}
	var circumcenters = []
	for triangle in triangles:
		if triangle:
			circumcenters.append(get_circumcenter(triangle.a, triangle.b, triangle.c))
	
	for i in range(triangles.size()):
		var triangle = triangles[i]
		if triangle:
			var center = circumcenters[i]
			add_circumcenter_to_site(voronoi_cells, triangle.a, center)
			add_circumcenter_to_site(voronoi_cells, triangle.b, center)
			add_circumcenter_to_site(voronoi_cells, triangle.c, center)
	
	var final_results: Array[Dictionary] = []
	var bounds_polygon = PackedVector2Array([
		bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)
	])
	
	for site in voronoi_cells:
		var cell_points: Array = voronoi_cells[site]
		# Usamos una lambda para ordenar, que es más limpio en Godot 4
		cell_points.sort_custom(func(p1, p2): return site.angle_to_point(p1) < site.angle_to_point(p2))
		var polygon_to_clip = PackedVector2Array(cell_points)
		var clipped_polygon_array = Geometry2D.intersect_polygons(polygon_to_clip, bounds_polygon)
			
		if not clipped_polygon_array.is_empty():
			final_results.append({
				"site": site,
				"vertices": clipped_polygon_array[0]
			})
			
	return final_results

# --- Funciones de Ayuda (sin cambios) ---
static func add_circumcenter_to_site(cells: Dictionary, site: Vector2, center: Vector2) -> void:
	if not cells.has(site): 
		cells[site] = []
	cells[site].append(center)

static func get_circumcenter(p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	var d = 2 * (p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y))
	if abs(d) < 1e-7: 
		return (p1 + p2 + p3) / 3.0
	var p1_sq = p1.length_squared()
	var p2_sq = p2.length_squared()
	var p3_sq = p3.length_squared()
	var ux = (p1_sq * (p2.y - p3.y) + p2_sq * (p3.y - p1.y) + p3_sq * (p1.y - p2.y)) / d
	var uy = (p1_sq * (p3.x - p2.x) + p2_sq * (p1.x - p3.x) + p3_sq * (p2.x - p1.x)) / d
	return Vector2(ux, uy)
