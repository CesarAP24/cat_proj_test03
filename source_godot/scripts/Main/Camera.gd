extends Camera3D

@export var objetivo_path: NodePath
@export var distancia: float = 200.0
@export var altura: float = 150.0
@export var angulo: float = 45.0
@export var sensibilidad_rotacion: float = 0.08
@export var invertir_x: bool = false
@export var invertir_y: bool = false
@export var zoom_min: float = 10.0
@export var zoom_max: float = 700.0
@export var zoom_speed: float = 0.2
@export var velocidad_suavizado: float = 10

# Variables para efectos visuales
@export_group("Efectos Visuales")
@export var mostrar_cursor_3d: bool = true
@export var radio_cursor: float = 1.0
@export var color_cursor: Color = Color(1, 1, 1, 0.7)
@export var radio_explosion_max: float = 2.5
@export var duracion_explosion: float = 0.8
@export var color_explosion: Color = Color(1, 1, 1, 1)
@export var particulas_por_explosion: int = 12

var rotacion_y = 0.0
var rotacion_x = 0.0
var clic_derecho_presionado = false

@onready var objetivo = get_node(objetivo_path)

# Sistema de efectos
var cursor_3d_mesh: MeshInstance3D
var explosiones_activas: Array = []
var particulas_activas: Array = []

# Clase para manejar explosiones individuales
class ExplosionEffect:
	var mesh: MeshInstance3D
	var tiempo_inicio: float
	var posicion: Vector3
	var normal: Vector3
	var radio_inicial: float
	var radio_final: float
	var duracion: float
	var color: Color
	var activa: bool = true
	
	func _init(pos: Vector3, surf_normal: Vector3, r_inicial: float, r_final: float, dur: float, col: Color, parent: Node):
		posicion = pos
		normal = surf_normal
		radio_inicial = r_inicial
		radio_final = r_final
		duracion = dur
		color = col
		tiempo_inicio = Time.get_ticks_msec() / 1000.0
		
		# Crear el mesh visual
		mesh = MeshInstance3D.new()
		var torus = TorusMesh.new()
		# Hacer el torus más delgado
		torus.inner_radius = r_inicial * 0.9
		torus.outer_radius = r_inicial
		mesh.mesh = torus
		
		# Material con transparencia
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.flags_transparent = true
		material.flags_unshaded = true
		material.no_depth_test = true
		mesh.material_override = material
		
		# Agregar a la escena primero
		parent.get_tree().current_scene.add_child(mesh)
		
		# Luego posicionar y orientar según la normal de la superficie
		mesh.global_position = posicion + normal * 0.1
		orientar_segun_normal(mesh, normal)
	
	func orientar_segun_normal(mesh_instance: MeshInstance3D, surf_normal: Vector3):
		# Crear una base ortonormal usando la normal como "up"
		var up_vector = surf_normal
		var forward_vector = Vector3.FORWARD
		
		# Si la normal es muy parecida al forward, usar otro vector de referencia
		if abs(up_vector.dot(forward_vector)) > 0.95:
			forward_vector = Vector3.RIGHT
		
		# Crear la base ortonormal
		var right_vector = forward_vector.cross(up_vector).normalized()
		forward_vector = up_vector.cross(right_vector).normalized()
		
		# Aplicar la orientación
		mesh_instance.global_transform.basis = Basis(right_vector, up_vector, forward_vector)
	
	func actualizar(delta: float) -> bool:
		var tiempo_transcurrido = (Time.get_ticks_msec() / 1000.0) - tiempo_inicio
		var progreso = tiempo_transcurrido / duracion
		
		if progreso >= 1.0:
			if mesh:
				mesh.queue_free()
			activa = false
			return false
		
		# Interpolar radio y transparencia
		var radio_actual = lerp(radio_inicial, radio_final, progreso)
		var alpha = 1.0 - (progreso * progreso)  # Fade out cuadrático
		
		# Actualizar el torus manteniendo la posición y orientación
		if mesh and mesh.mesh:
			var torus = mesh.mesh as TorusMesh
			# Hacer el torus más delgado
			torus.inner_radius = radio_actual * 0.9
			torus.outer_radius = radio_actual
			
			# Actualizar transparencia
			var material = mesh.material_override as StandardMaterial3D
			material.albedo_color.a = alpha * color.a
			
			# Mantener la posición y orientación durante toda la animación
			mesh.global_position = posicion + normal * 0.1
		
		return true

# Clase para partículas individuales
class Particula:
	var mesh: MeshInstance3D
	var velocidad: Vector3
	var tiempo_vida: float
	var tiempo_vida_max: float
	var posicion: Vector3
	var activa: bool = true
	var color_inicial: Color
	
	func _init(pos: Vector3, vel: Vector3, vida: float, col: Color, parent: Node):
		posicion = pos
		velocidad = vel
		tiempo_vida_max = vida
		tiempo_vida = vida
		color_inicial = col
		
		# Crear mesh pequeño
		mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		mesh.mesh = sphere
		
		var material = StandardMaterial3D.new()
		material.albedo_color = color_inicial
		material.flags_transparent = true
		material.flags_unshaded = true
		material.no_depth_test = true
		mesh.material_override = material
		
		mesh.global_position = posicion
		parent.get_tree().current_scene.add_child(mesh)
	
	func actualizar(delta: float) -> bool:
		tiempo_vida -= delta
		
		if tiempo_vida <= 0:
			if mesh:
				mesh.queue_free()
			activa = false
			return false
		
		# Actualizar posición con gravedad
		velocidad.y -= 20.0 * delta  # Gravedad
		posicion += velocidad * delta
		mesh.position = posicion
		
		# Fade out
		var alpha = tiempo_vida / tiempo_vida_max
		var material = mesh.material_override as StandardMaterial3D
		material.albedo_color.a = alpha * color_inicial.a
		
		return true

func _ready():
	rotacion_y = 0.0
	rotacion_x = deg_to_rad(angulo)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Inicializar cursor 3D
	if mostrar_cursor_3d:
		inicializar_cursor_3d()

func inicializar_cursor_3d():
	cursor_3d_mesh = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = radio_cursor * 0.7
	torus.outer_radius = radio_cursor
	cursor_3d_mesh.mesh = torus
	
	# Material brillante
	var material = StandardMaterial3D.new()
	material.albedo_color = color_cursor
	material.flags_transparent = true
	material.flags_unshaded = true
	material.no_depth_test = true
	material.emission_enabled = true
	material.emission = Color(0.3, 0.3, 0.3)
	cursor_3d_mesh.material_override = material
	
	# Agregarlo a la escena principal
	get_tree().current_scene.add_child(cursor_3d_mesh)

func _input(event):
	# Handle right-click for camera rotation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			clic_derecho_presionado = event.pressed
			
			if clic_derecho_presionado:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				# Ocultar cursor 3D cuando rotamos cámara
				if cursor_3d_mesh:
					cursor_3d_mesh.visible = false
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				# Mostrar cursor 3D de nuevo
				if cursor_3d_mesh:
					cursor_3d_mesh.visible = true
		
		# Handle left-click for explosions
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Click izquierdo detectado")
			var resultado_raycast = hacer_raycast(event.position)
			
			if resultado_raycast:
				print("Raycast exitoso en: ", resultado_raycast.position)
				print("Normal de superficie: ", resultado_raycast.normal)
				
				# Crear explosión orientada en el punto de click
				crear_explosion_click(resultado_raycast.position, resultado_raycast.normal)
				
				# Mover target
				if objetivo and objetivo.has_method("set_target"):
					objetivo.set_target(resultado_raycast.position)
			else:
				print("Raycast falló - no hay colisión")
		
		# Handle mouse wheel for zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia = max(zoom_min, distancia - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia = min(zoom_max, distancia + zoom_speed)
	
	# Handle mouse motion for camera rotation
	elif event is InputEventMouseMotion and clic_derecho_presionado:
		var factor_x = -1.0 if invertir_x else 1.0
		var factor_y = -1.0 if invertir_y else 1.0
		
		rotacion_y += event.relative.x * sensibilidad_rotacion * 0.01 * factor_x
		rotacion_x += event.relative.y * sensibilidad_rotacion * 0.01 * factor_y
		
		rotacion_x = clamp(rotacion_x, 0.1, PI/2.0)
	
	# Actualizar cursor 3D con movimiento del mouse
	elif event is InputEventMouseMotion and not clic_derecho_presionado:
		actualizar_cursor_3d(event.position)

func hacer_raycast(mouse_pos: Vector2) -> Dictionary:
	var from = project_ray_origin(mouse_pos)
	var to = from + project_ray_normal(mouse_pos) * 1000
	
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to
	
	var space_state = get_world_3d().direct_space_state
	return space_state.intersect_ray(ray_query)

func actualizar_cursor_3d(mouse_pos: Vector2):
	if not cursor_3d_mesh or not cursor_3d_mesh.visible or not cursor_3d_mesh.is_inside_tree():
		return
	
	var resultado = hacer_raycast(mouse_pos)
	
	if resultado:
		# Posicionar cursor ligeramente arriba del suelo
		var pos_cursor = resultado.position + resultado.normal * 0.1
		cursor_3d_mesh.global_position = pos_cursor
		
		# Orientar el cursor según la normal de la superficie
		orientar_cursor_segun_normal(resultado.normal)
		
		# Efecto de pulsación sutil
		var tiempo = Time.get_ticks_msec() / 1000.0
		var pulso = 1.0 + sin(tiempo * 4.0) * 0.1
		cursor_3d_mesh.scale = Vector3.ONE * pulso
		
		# Cambiar color según la superficie
		var material = cursor_3d_mesh.material_override as StandardMaterial3D
		if material:
			if resultado.collider and resultado.collider.is_in_group("suelo"):
				material.albedo_color = Color(0.3, 1.0, 0.3, 0.7)  # Verde para suelo válido
			else:
				material.albedo_color = Color(1.0, 0.3, 0.3, 0.7)  # Rojo para superficie inválida
	else:
		# Ocultar cursor si no hay colisión
		cursor_3d_mesh.visible = false

func orientar_cursor_segun_normal(normal: Vector3):
	var up_vector = normal
	var forward_vector = Vector3.FORWARD
	
	# Si la normal es muy parecida al forward, usar otro vector de referencia
	if abs(up_vector.dot(forward_vector)) > 0.95:
		forward_vector = Vector3.RIGHT
	
	# Crear la base ortonormal
	var right_vector = forward_vector.cross(up_vector).normalized()
	forward_vector = up_vector.cross(right_vector).normalized()
	
	# Verificar que el cursor aún esté en el árbol antes de cambiar su transform
	if cursor_3d_mesh.is_inside_tree():
		cursor_3d_mesh.global_transform.basis = Basis(right_vector, up_vector, forward_vector)

func crear_explosion_click(posicion: Vector3, normal: Vector3):
	print("Creando explosión en: ", posicion, " con normal: ", normal)
	
	# Crear el efecto de onda expansiva orientado según la normal
	var explosion = ExplosionEffect.new(
		posicion,  # Posición del click
		normal,    # Normal de la superficie
		1,       # Radio inicial
		radio_explosion_max,  # Radio final
		duracion_explosion,   # Duración
		color_explosion,      # Color
		self       # Parent node
	)
	explosiones_activas.append(explosion)
	
	# Crear partículas orientadas según la normal
	crear_particulas_explosion(posicion, normal)

func crear_particulas_explosion(posicion: Vector3, normal: Vector3):
	# Crear un sistema de coordenadas local basado en la normal
	var up_vector = normal
	var right_vector = Vector3.RIGHT
	var forward_vector = Vector3.FORWARD
	
	# Si la normal es muy parecida al right, usar otro vector
	if abs(up_vector.dot(right_vector)) > 0.95:
		right_vector = Vector3.FORWARD
	
	# Crear base ortonormal
	right_vector = right_vector.cross(up_vector).normalized()
	forward_vector = up_vector.cross(right_vector).normalized()
	
	for i in range(particulas_por_explosion):
		# Crear velocidad en el plano perpendicular a la normal
		var angulo = randf() * TAU
		var fuerza_horizontal = randf_range(8.0, 15.0)
		var fuerza_vertical = randf_range(3.0, 8.0)
		
		# Combinar componentes horizontal y vertical
		var velocidad_local = Vector3(
			cos(angulo) * fuerza_horizontal,
			fuerza_vertical,
			sin(angulo) * fuerza_horizontal
		)
		
		# Transformar al espacio mundial usando la base ortonormal
		var velocidad_mundial = (
			right_vector * velocidad_local.x +
			up_vector * velocidad_local.y +
			forward_vector * velocidad_local.z
		)
		
		var vida = randf_range(0.5, 1.2)
		var color_particula = Color(
			randf_range(0.8, 1.0),
			randf_range(0.8, 1.0),
			randf_range(0.8, 1.0),
			1.0
		)
		
		var particula = Particula.new(
			posicion + normal * 0.5,  # Empezar ligeramente separado de la superficie
			velocidad_mundial,
			vida,
			color_particula,
			self
		)
		particulas_activas.append(particula)

func _process(delta):
	if not objetivo:
		return
	
	# Actualizar posición y rotación de cámara
	var center = objetivo.call("obtener_centro")
	
	var offset = Vector3()
	offset.x = sin(rotacion_y) * distancia * cos(rotacion_x)
	offset.y = sin(rotacion_x) * distancia
	offset.z = cos(rotacion_y) * distancia * cos(rotacion_x)
	
	# Suavizado de posición
	var target_position = center + offset
	var direction = target_position - global_transform.origin
	global_transform.origin += direction * delta * 5
	
	# Suavizado de rotación
	var target_transform = global_transform.looking_at(center, Vector3.UP)
	var current_quat = global_transform.basis.get_rotation_quaternion()
	var target_quat = target_transform.basis.get_rotation_quaternion()
	var new_quat = current_quat.slerp(target_quat, delta * velocidad_suavizado)
	global_transform.basis = Basis(new_quat)
	
	# Actualizar efectos visuales
	actualizar_explosiones(delta)
	actualizar_particulas(delta)
	
	# Actualizar cursor 3D si no estamos rotando
	if not clic_derecho_presionado and cursor_3d_mesh and cursor_3d_mesh.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		actualizar_cursor_3d(mouse_pos)

func actualizar_explosiones(delta: float):
	# Actualizar explosiones existentes y remover las terminadas
	for i in range(explosiones_activas.size() - 1, -1, -1):
		if not explosiones_activas[i].actualizar(delta):
			explosiones_activas.remove_at(i)

func actualizar_particulas(delta: float):
	# Actualizar partículas existentes y remover las terminadas
	for i in range(particulas_activas.size() - 1, -1, -1):
		if not particulas_activas[i].actualizar(delta):
			particulas_activas.remove_at(i)

# Funciones públicas para personalización
func cambiar_color_cursor(nuevo_color: Color):
	color_cursor = nuevo_color
	if cursor_3d_mesh and cursor_3d_mesh.material_override:
		var material = cursor_3d_mesh.material_override as StandardMaterial3D
		material.albedo_color = nuevo_color

func cambiar_radio_cursor(nuevo_radio: float):
	radio_cursor = nuevo_radio
	if cursor_3d_mesh and cursor_3d_mesh.mesh:
		var torus = cursor_3d_mesh.mesh as TorusMesh
		torus.inner_radius = nuevo_radio * 0.7
		torus.outer_radius = nuevo_radio

func activar_cursor_3d(activar: bool):
	mostrar_cursor_3d = activar
	if cursor_3d_mesh:
		cursor_3d_mesh.visible = activar and not clic_derecho_presionado
