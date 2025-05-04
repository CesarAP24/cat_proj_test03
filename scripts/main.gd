extends Spatial

# CONFIGURACIÓN PRINCIPAL
# ----------------------
# Constantes de tamaño y escala
const ESCALA = 0.05
const RADIO = 0.2

# Constantes de velocidad
const VELOCIDAD_BASE = 1
const VELOCIDAD_MOVIMIENTO = 1.1 * VELOCIDAD_BASE
const VELOCIDAD_ROTACION = 0.05 * VELOCIDAD_BASE

# Constantes de dimensiones y umbrales
const DISTANCIA_ENTRE_PATAS = 5 * ESCALA
const LONGITUD_PASO = 120 * ESCALA
const UMBRAL_DISTANCIA = 60 * ESCALA
const UMBRAL_PATAS = 40 * ESCALA
const ALTURA_PASO = 20* ESCALA

# Opciones de debug
const DEBUG = true

# Estados del movimiento
enum Estado { PASO_1, PASO_2, PASO_3, PASO_4, PASO_5 }

# VARIABLES DEL SISTEMA
# --------------------
# Variables de control
var estado_actual = Estado.PASO_1
var direccion = Vector3(0, 0, 1)
var punto_objetivo = Vector3(0, 0, 0)
var tiempo = 0

# Diccionarios para el trackeo de posiciones
var objetivos = {}
var patas = {}
var esferas = {}
var posiciones_iniciales = {}
var progreso_movimiento = {}

# FUNCIONES DE INICIALIZACIÓN
# --------------------------
func _ready():
	inicializar()

func inicializar():
	# Inicializar posiciones de objetivos
	objetivos = {
		"frontL": Vector3(200 * ESCALA + DISTANCIA_ENTRE_PATAS, 0, 300 * ESCALA),
		"frontR": Vector3(200 * ESCALA, 0, 300 * ESCALA),
		"backL": Vector3(200 * ESCALA + DISTANCIA_ENTRE_PATAS, 0, 200 * ESCALA),
		"backR": Vector3(200 * ESCALA, 0, 200 * ESCALA)
	}
	
	# Inicializar posiciones de patas
	patas = {
		"frontL": objetivos["frontL"],
		"frontR": objetivos["frontR"],
		"backL": objetivos["backL"],
		"backR": objetivos["backR"]
	}
	
	# Inicializar progreso de movimiento y posiciones iniciales
	for pata in patas.keys():
		progreso_movimiento[pata] = 1.0  # Inicialmente todas las patas están en su destino
		posiciones_iniciales[pata] = patas[pata]  # Guardar posición inicial
	
	crear_representacion_visual()

# FUNCIONES DE REPRESENTACIÓN VISUAL
# ---------------------------------
func crear_representacion_visual():
	# Crear esferas para las patas
	for nombre in patas.keys():
		var esfera = MeshInstance.new()
		esfera.name = "pata_" + nombre
		esfera.mesh = SphereMesh.new()
		esfera.scale = Vector3(RADIO, RADIO, RADIO)
		esfera.material_override = crear_material(Color(0, 0, 1))
		add_child(esfera)
		esferas["pata_" + nombre] = esfera
	
	# Crear esferas para objetivos (solo en modo debug)
	if DEBUG:
		for nombre in objetivos.keys():
			var esfera = MeshInstance.new()
			esfera.name = "objetivo_" + nombre
			esfera.mesh = SphereMesh.new()
			esfera.scale = Vector3(RADIO * 0.5, RADIO * 0.5, RADIO * 0.5)
			esfera.material_override = crear_material(Color(0, 1, 0))
			add_child(esfera)
			esferas["objetivo_" + nombre] = esfera

		# Crear esfera para el punto objetivo
		var objetivo_especial = MeshInstance.new()
		objetivo_especial.name = "punto_objetivo"
		objetivo_especial.mesh = SphereMesh.new()
		objetivo_especial.scale = Vector3(RADIO * 0.5, RADIO * 0.5, RADIO * 0.5)
		objetivo_especial.material_override = crear_material(Color(1, 0, 0))
		add_child(objetivo_especial)
		esferas["punto_objetivo"] = objetivo_especial

func crear_material(color):
	var mat = SpatialMaterial.new()
	mat.albedo_color = color
	return mat

# FUNCIONES DE ENTRADA Y PROCESO
# ----------------------------
func manejar_movimiento_objetivo():
	var velocidad_objetivo = 0.2*4
	punto_objetivo.y = obtener_centro().y+3
	if Input.is_key_pressed(KEY_W):
		punto_objetivo.z += velocidad_objetivo
	if Input.is_key_pressed(KEY_A):
		punto_objetivo.x += velocidad_objetivo
	if Input.is_key_pressed(KEY_S):
		punto_objetivo.z -= velocidad_objetivo
	if Input.is_key_pressed(KEY_D):
		punto_objetivo.x -= velocidad_objetivo

func _process(delta):
	actualizar_maquina_estados()
	mover_patas(delta)
	actualizar_representacion_visual()
	manejar_movimiento_objetivo()

# MÁQUINA DE ESTADOS
# -----------------
func actualizar_maquina_estados():
	# Lógica de transición de estados basada en la posición de las patas
	if debe_avanzar() and (estado_actual == Estado.PASO_1 or estado_actual == Estado.PASO_5) and distancia(patas["frontL"], objetivos["frontL"]) < UMBRAL_PATAS/2:
		cambiar_estado(Estado.PASO_2)
	elif distancia(patas["backR"], objetivos["backR"]) < UMBRAL_PATAS and estado_actual == Estado.PASO_2:
		cambiar_estado(Estado.PASO_3)
	elif debe_avanzar() and estado_actual == Estado.PASO_3 and distancia(patas["frontR"], objetivos["frontR"]) < UMBRAL_PATAS/2:
		cambiar_estado(Estado.PASO_4)
	elif distancia(patas["backL"], objetivos["backL"]) < UMBRAL_PATAS and estado_actual == Estado.PASO_4:
		cambiar_estado(Estado.PASO_5)

func cambiar_estado(nuevo_estado):
	estado_actual = nuevo_estado
	
	match nuevo_estado:
		Estado.PASO_1:
			pass  # No hay acción específica para este estado
		
		Estado.PASO_2:
			# Mover pata trasera derecha
			objetivos["backR"] = objetivos["frontR"]
			posiciones_iniciales["backR"] = patas["backR"]
			progreso_movimiento["backR"] = 0.0
		
		Estado.PASO_3:
			# Mover pata delantera derecha
			objetivos["frontR"] = calcular_siguiente_posicion_delantera(false)
			posiciones_iniciales["frontR"] = patas["frontR"]
			progreso_movimiento["frontR"] = 0.0
		
		Estado.PASO_4:
			# Mover pata trasera izquierda
			objetivos["backL"] = objetivos["frontL"]
			posiciones_iniciales["backL"] = patas["backL"]
			progreso_movimiento["backL"] = 0.0
		
		Estado.PASO_5:
			# Mover pata delantera izquierda
			objetivos["frontL"] = calcular_siguiente_posicion_delantera(true)
			posiciones_iniciales["frontL"] = patas["frontL"]
			progreso_movimiento["frontL"] = 0.0

# FUNCIONES DE MOVIMIENTO
# ----------------------
func mover_patas(delta):
	tiempo += delta * VELOCIDAD_MOVIMIENTO * 5
	
	for nombre in patas.keys():
		# Solo procesar patas que están en movimiento
		if progreso_movimiento[nombre] < 1.0:
			# Actualizar progreso del movimiento
			progreso_movimiento[nombre] += VELOCIDAD_MOVIMIENTO * delta * 5
			if progreso_movimiento[nombre] > 1.0:
				progreso_movimiento[nombre] = 1.0
			
			# Obtener posiciones inicial y final
			var pos_inicial = posiciones_iniciales[nombre]
			var pos_final = objetivos[nombre]
			var progreso = progreso_movimiento[nombre]
			
			# Calcular posición con interpolación mejorada
			patas[nombre] = calcular_posicion_interpolada(pos_inicial, pos_final, progreso)
	
	# Actualizar la dirección hacia el objetivo
	if debe_avanzar():
		var dist = distancia(obtener_centro(), punto_objetivo)
		var factor_velocidad = 2/(0.2*dist)
		var velocidad_rot = VELOCIDAD_ROTACION * (1.0 + factor_velocidad)
		direccion = rotar_hacia(direccion, punto_objetivo, velocidad_rot)

func calcular_posicion_interpolada(pos_inicial, pos_final, progreso):
	# Crear vector de posición interpolada para X y Z
	var interpolacion_xz = pos_inicial.linear_interpolate(pos_final, progreso)
	
	# Calcular altura usando una curva parabólica en lugar de senoidal
	var altura_y = calcular_altura_parabola(pos_inicial, pos_final, progreso)
	
	# Aplicar la altura calculada
	interpolacion_xz.y = altura_y
	
	return interpolacion_xz

func calcular_altura_parabola(pos_inicial, pos_final, progreso):
	# Puntos de control para la curva parabólica
	var y_inicio = pos_inicial.y
	var y_fin = pos_final.y
	var altura_maxima = max(y_inicio, y_fin) + ALTURA_PASO
	
	# Fórmula de parábola: a*t^2 + b*t + c, donde t = progreso (0 a 1)
	var a = y_inicio + y_fin - 2 * altura_maxima
	var b = -2 * y_inicio + 2 * altura_maxima
	var c = y_inicio
	
	# Calcular punto en la parábola
	var altura = a * progreso * progreso + b * progreso + c
	
	return altura

func actualizar_representacion_visual():
	# Actualizar posiciones de las esferas de las patas
	for nombre in patas.keys():
		esferas["pata_" + nombre].translation = patas[nombre]
	
	# Actualizar posiciones de las esferas de los objetivos (modo debug)
	if DEBUG:
		for nombre in objetivos.keys():
			esferas["objetivo_" + nombre].translation = objetivos[nombre]
		esferas["punto_objetivo"].translation = punto_objetivo

# FUNCIONES UTILITARIAS
# --------------------
# Modifica esta función para tener un comportamiento más estable cerca del objetivo
func debe_avanzar():
	var dist = distancia(obtener_centro(), punto_objetivo)
	
	# Añadir una zona de "descanso" donde el cuadrúpedo no se mueve
	# Usar un umbral más pequeño para detenerse completamente
	var umbral_descanso = UMBRAL_DISTANCIA * 0.5
	
	# Solo avanzar si estamos fuera del umbral de descanso
	return dist > umbral_descanso
	
func distancia(p1, p2):
	# Calcular distancia en el plano XZ (ignorando Y)
	var pa = Vector2(p1.x, p1.z)
	var pb = Vector2(p2.x, p2.z)
	return (pa - pb).length()

func obtener_direccion():
	return direccion
	
func obtener_vel_rot():
	return VELOCIDAD_ROTACION
	
func obtener_target():
	return punto_objetivo

func obtener_centro():
	# Calcular el centro del cuadrúpedo basado en las posiciones de las patas
	var posiciones = []
	for pos in patas.values():
		posiciones.append(pos)
	
	var suma = Vector3()
	for p in posiciones:
		var punto = p
		suma += punto
	
	return suma / posiciones.size()

func rotar_hacia(actual, objetivo, angulo_max):
	# Calcular rotación suave hacia el objetivo
	var centro = obtener_centro()
	var vector_deseado = (objetivo - centro).normalized()
	var angulo_actual = atan2(actual.z, actual.x)
	var angulo_objetivo = atan2(vector_deseado.z, vector_deseado.x)
	var delta = angulo_objetivo - angulo_actual
	
	# Normalizar el delta para evitar rotaciones largas
	delta = wrapf(delta, -PI, PI)
	
	# Calcular nuevo ángulo con límite de velocidad
	var nuevo_angulo = angulo_actual + clamp(delta, -angulo_max, angulo_max)
	
	# Devolver vector de dirección normalizado
	return Vector3(cos(nuevo_angulo), 0, sin(nuevo_angulo))
	
func calcular_siguiente_posicion_delantera(izquierda):
	# Calcular la próxima posición para una pata delantera
	var dir_norm = direccion.normalized()
	
	# Obtener el centro actual
	var centro = obtener_centro()
	
	# Calcular posición objetivo inicial
	var pos = centro + dir_norm * LONGITUD_PASO
	
	# Ajustar posición lateralmente según la pata (izquierda o derecha)
	if izquierda:
		pos += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	else:
		pos += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	# Obtener altura del terreno en la posición objetivo
	var altura_terreno = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
	
	# Calcular diferencia de altura
	var diferencia_altura = altura_terreno - centro.y
	
	# Si la diferencia de altura es significativa, ajustar la distancia horizontal
	if abs(diferencia_altura) > ALTURA_PASO * 0.5:
		# Reducir la longitud del paso basado en la pendiente
		var factor_pendiente = clamp(1.0 - abs(diferencia_altura) / (LONGITUD_PASO * 2), 0.3, 1.0)
		
		# Recalcular la posición con un paso más corto
		pos = centro + dir_norm * (LONGITUD_PASO * factor_pendiente)
		
		# Reajustar posición lateral
		if izquierda:
			pos += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
		else:
			pos += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	# Ajustar altura según el terreno
	pos.y = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
	
	return pos
	
func obtener_patas():
	return patas

func obtener_punto_mas_alto(x, z, grupo_nombre):
	# Raycast para detectar altura del terreno
	var origen = Vector3(x, obtener_centro().y+30, z)  # Rayo desde arriba
	var destino = Vector3(x, -1000, z)  # Hacia abajo
	
	# Obtener espacio de la escena
	var espacio_estado = get_world().direct_space_state
	
	# Realizar el raycast
	var resultado = espacio_estado.intersect_ray(origen, destino)
	
	# Verificar resultado
	if resultado and resultado.has("collider"):
		var objeto_colision = resultado["collider"]
		
		# Verificar si pertenece al grupo especificado
		if objeto_colision.is_in_group(grupo_nombre):
			return resultado["position"]
	
	# Si no hay colisión, devolver altura por defecto
	return Vector3(x, 0, z)
