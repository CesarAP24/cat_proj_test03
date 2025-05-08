extends Node3D

# Constantes de configuración
const ESCALA = 0.05
const RADIO = 1

# Parámetros exportables
@export var VELOCIDAD_BASE_INICIAL = 1.2
@export var VELOCIDAD_BASE = VELOCIDAD_BASE_INICIAL
@export var VELOCIDAD_MOVIMIENTO = 0.9
@export var VELOCIDAD_ROTACION = 0.04
@export var DISTANCIA_ENTRE_PATAS = 12 * ESCALA
@export var LONGITUD_PASO = 180 * ESCALA
@export var UMBRAL_DISTANCIA = 150 * ESCALA    
@export var UMBRAL_PATAS_FRONT = 70 * ESCALA
@export var UMBRAL_PATAS_BACK = 100 * ESCALA
@export var ALTURA_PASO = 60 * ESCALA
@export var RANDOM_DISTANCE = 0.0
@export var MIN_HEIGHT_JUMP = 100 * ESCALA
@export var UMBRAL_DETECCION_SALTO = 270 * ESCALA
@export var MARGEN_SALTO_ADELANTE = 30 * ESCALA
@export var MOVEMENT_TARGET_SPEED = 2
@export var DEBUG = false	

# Variables de control para velocidades de salto
@export var VELOCIDAD_PREPARACION_SALTO = 0.7  # Velocidad durante la preparación (más baja = más lento)
@export var VELOCIDAD_EJECUCION_SALTO = 0.75    # Velocidad durante el salto (más baja = más lento)
@export var VELOCIDAD_ATERRIZAJE = 0.7         # Velocidad durante el aterrizaje (más baja = más lento)

# Estados del movimiento
enum Estado { PASO_1, PASO_2, PASO_3, PASO_4, PASO_5, SALTO_PREP, SALTO, ATERRIZAJE }

# Variables de control
var estado_actual = Estado.PASO_1
var direccion = Vector3(0, 0, 1)
var punto_objetivo = Vector3(0, 0, 0)
var tiempo = 0
var en_ciclo_salto = false
var posicion_obstaculo = Vector3()

# Diccionarios para tracking
var objetivos = {}
var patas = {}
var esferas = {}
var posiciones_iniciales = {}
var progreso_movimiento = {}

# Inicialización del sistema
func _ready():
	VELOCIDAD_BASE = VELOCIDAD_BASE_INICIAL
	inicializar()

# Configura las posiciones iniciales de las patas
func inicializar():
	objetivos = {
		"frontL": Vector3(200 * ESCALA + DISTANCIA_ENTRE_PATAS, 0, 300 * ESCALA),
		"frontR": Vector3(200 * ESCALA, 0, 300 * ESCALA),
		"backL": Vector3(200 * ESCALA + DISTANCIA_ENTRE_PATAS, 0, 200 * ESCALA),
		"backR": Vector3(200 * ESCALA, 0, 200 * ESCALA)
	}
	
	patas = objetivos.duplicate()
	
	for pata in patas.keys():
		progreso_movimiento[pata] = 1.0
		posiciones_iniciales[pata] = patas[pata]
	
	crear_representacion_visual()

# Crea elementos visuales para debugging
func crear_representacion_visual():
	
	if DEBUG:
		# Crear esferas para las patas
		for nombre in patas.keys():
			var esfera = MeshInstance3D.new()
			esfera.name = "pata_" + nombre
			esfera.mesh = SphereMesh.new()
			esfera.scale = Vector3(RADIO, RADIO, RADIO)
			esfera.material_override = crear_material(Color(0, 0, 1))
			add_child(esfera)
			esferas["pata_" + nombre] = esfera
		
		# En modo debug, crear visualizaciones adicionales
		for nombre in objetivos.keys():
			var esfera = MeshInstance3D.new()
			esfera.name = "objetivo_" + nombre
			esfera.mesh = SphereMesh.new()
			esfera.scale = Vector3(RADIO, RADIO, RADIO)
			esfera.material_override = crear_material(Color(0, 1, 0))
			add_child(esfera)
			esferas["objetivo_" + nombre] = esfera

		var objetivo_especial = MeshInstance3D.new()
		objetivo_especial.name = "punto_objetivo"
		objetivo_especial.mesh = SphereMesh.new()
		objetivo_especial.scale = Vector3(RADIO,RADIO,RADIO)
		objetivo_especial.material_override = crear_material(Color(1, 0, 0))
		add_child(objetivo_especial)
		esferas["punto_objetivo"] = objetivo_especial

# Crea un material con el color especificado
func crear_material(color):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	return mat

# Maneja entrada para mover el objetivo
func manejar_movimiento_objetivo():
	var velocidad_objetivo = 0.2 * 2 * MOVEMENT_TARGET_SPEED
	punto_objetivo.y = obtener_centro().y + 3
	
	if Input.is_key_pressed(KEY_W): punto_objetivo.z += velocidad_objetivo
	if Input.is_key_pressed(KEY_A): punto_objetivo.x += velocidad_objetivo
	if Input.is_key_pressed(KEY_S): punto_objetivo.z -= velocidad_objetivo
	if Input.is_key_pressed(KEY_D): punto_objetivo.x -= velocidad_objetivo
	if Input.is_key_pressed(KEY_U): VELOCIDAD_BASE += 0.01
	if Input.is_key_pressed(KEY_J): VELOCIDAD_BASE -= 0.01
	
	# Controles para las velocidades de salto
	if Input.is_key_pressed(KEY_1): VELOCIDAD_PREPARACION_SALTO = max(0.1, VELOCIDAD_PREPARACION_SALTO - 0.01)
	if Input.is_key_pressed(KEY_2): VELOCIDAD_PREPARACION_SALTO = min(1.0, VELOCIDAD_PREPARACION_SALTO + 0.01)
	if Input.is_key_pressed(KEY_3): VELOCIDAD_EJECUCION_SALTO = max(0.1, VELOCIDAD_EJECUCION_SALTO - 0.01)
	if Input.is_key_pressed(KEY_4): VELOCIDAD_EJECUCION_SALTO = min(1.0, VELOCIDAD_EJECUCION_SALTO + 0.01)
	if Input.is_key_pressed(KEY_5): VELOCIDAD_ATERRIZAJE = max(0.1, VELOCIDAD_ATERRIZAJE - 0.01)
	if Input.is_key_pressed(KEY_6): VELOCIDAD_ATERRIZAJE = min(1.0, VELOCIDAD_ATERRIZAJE + 0.01)

# Establece un objetivo externo
func set_target(new_target):
	punto_objetivo = new_target

# Función principal de proceso
func _process(delta):
	actualizar_maquina_estados()
	mover_patas(delta)
	actualizar_representacion_visual()
	manejar_movimiento_objetivo()

# Gestiona las transiciones entre estados
func actualizar_maquina_estados():
	# Detectar salto si es necesario
	if debe_avanzar() and not en_ciclo_salto and es_necesario_saltar():
		en_ciclo_salto = true
		cambiar_estado(Estado.SALTO_PREP)
		return
	
	# Manejar estados de salto
	if en_ciclo_salto:
		match estado_actual:
			Estado.SALTO_PREP:
				if todas_patas_en_posicion(): cambiar_estado(Estado.SALTO)
			Estado.SALTO:
				if patas_delanteras_en_objetivo(): cambiar_estado(Estado.ATERRIZAJE)
			Estado.ATERRIZAJE:
				if patas_traseras_en_objetivo():
					en_ciclo_salto = false
					cambiar_estado(Estado.PASO_1)
		return
	
	# Estados de caminata normal
	if debe_avanzar() and (estado_actual == Estado.PASO_1 or estado_actual == Estado.PASO_5) and distancia(patas["frontL"], objetivos["frontL"]) < UMBRAL_PATAS_FRONT:
		cambiar_estado(Estado.PASO_2)
	elif distancia(patas["backR"], objetivos["backR"]) < UMBRAL_PATAS_BACK and estado_actual == Estado.PASO_2:
		cambiar_estado(Estado.PASO_3)
	elif debe_avanzar() and estado_actual == Estado.PASO_3 and distancia(patas["frontR"], objetivos["frontR"]) < UMBRAL_PATAS_FRONT:
		cambiar_estado(Estado.PASO_4)
	elif distancia(patas["backL"], objetivos["backL"]) < UMBRAL_PATAS_BACK and estado_actual == Estado.PASO_4:
		cambiar_estado(Estado.PASO_5)

# Establece un nuevo estado del movimiento
func cambiar_estado(nuevo_estado):
	estado_actual = nuevo_estado
	var ran_vec = Vector3(randf() * RANDOM_DISTANCE, 0, randf() * RANDOM_DISTANCE)
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	
	match nuevo_estado:
		Estado.PASO_1:
			pass  # No hay acción específica
		
		Estado.PASO_2:
			# Mover pata trasera derecha
			objetivos["backR"] = objetivos["frontR"]
			posiciones_iniciales["backR"] = patas["backR"]
			progreso_movimiento["backR"] = 0.0
		
		Estado.PASO_3:
			# Mover pata delantera derecha
			objetivos["frontR"] = calcular_siguiente_posicion_delantera(false) + ran_vec
			posiciones_iniciales["frontR"] = patas["frontR"]
			progreso_movimiento["frontR"] = 0.0
		
		Estado.PASO_4:
			# Mover pata trasera izquierda
			objetivos["backL"] = objetivos["frontL"]
			posiciones_iniciales["backL"] = patas["backL"]
			progreso_movimiento["backL"] = 0.0
		
		Estado.PASO_5:
			# Mover pata delantera izquierda
			objetivos["frontL"] = calcular_siguiente_posicion_delantera(true) + ran_vec
			posiciones_iniciales["frontL"] = patas["frontL"]
			progreso_movimiento["frontL"] = 0.0
			
		Estado.SALTO_PREP:
			# Preparar patas para el salto
			var pos_frontL = centro + dir_norm * (LONGITUD_PASO * 0.2)
			var pos_frontR = Vector3(pos_frontL)
			var pos_backL = centro - dir_norm * (LONGITUD_PASO * 0.2)
			var pos_backR = Vector3(pos_backL)
						
			# Ajustar posiciones lateralmente
			pos_frontL += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			pos_frontR += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			pos_backL += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			pos_backR += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.3)
			
			# Ajustar alturas
			for pos in [pos_frontL, pos_frontR, pos_backL, pos_backR]:
				pos.y = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
			
			# Actualizar objetivos
			objetivos["frontL"] = pos_frontL
			objetivos["frontR"] = pos_frontR
			objetivos["backL"] = pos_backL
			objetivos["backR"] = pos_backR
			
			for pata in patas.keys():
				posiciones_iniciales[pata] = patas[pata]
				progreso_movimiento[pata] = 0.0
		
		Estado.SALTO:
			# Mover patas delanteras al borde del obstáculo
			var borde_obstaculo = encontrar_borde_obstaculo()
			var pos_frontL = borde_obstaculo + dir_norm * MARGEN_SALTO_ADELANTE
			var pos_frontR = Vector3(pos_frontL)
			
			# Ajustar posiciones lateralmente
			pos_frontL += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			pos_frontR += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS * 0.5)
			
			# Ajustar altura
			pos_frontL.y = obtener_punto_mas_alto(pos_frontL.x, pos_frontL.z, "suelo").y
			pos_frontR.y = obtener_punto_mas_alto(pos_frontR.x, pos_frontR.z, "suelo").y
			
			objetivos["frontL"] = pos_frontL
			objetivos["frontR"] = pos_frontR
			
			posiciones_iniciales["frontL"] = patas["frontL"]
			posiciones_iniciales["frontR"] = patas["frontR"]
			progreso_movimiento["frontL"] = 0.0
			progreso_movimiento["frontR"] = 0.0
		
		Estado.ATERRIZAJE:
			# Mover patas traseras hacia las delanteras
			objetivos["backL"] = objetivos["frontL"] 
			objetivos["backR"] = objetivos["frontR"]
			
			posiciones_iniciales["backL"] = patas["backL"]
			posiciones_iniciales["backR"] = patas["backR"]
			progreso_movimiento["backL"] = 0.0
			progreso_movimiento["backR"] = 0.0

# Detecta si un obstáculo requiere salto
func es_necesario_saltar():
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	
	for dist in range(1, 15):
		var distancia_actual = UMBRAL_DETECCION_SALTO * dist / 15.0
		var punto_check = centro + dir_norm * distancia_actual
		punto_check.y = centro.y
		
		var altura_terreno = obtener_punto_mas_alto(punto_check.x, punto_check.z, "suelo").y
		var diferencia_altura = altura_terreno - centro.y
		
		if diferencia_altura > MIN_HEIGHT_JUMP && diferencia_altura < MIN_HEIGHT_JUMP * 3:
			posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
			return true
	
	return false

# Encuentra el borde preciso de un obstáculo
func encontrar_borde_obstaculo():
	var centro = obtener_centro()
	var dir_norm = direccion.normalized()
	
	if posicion_obstaculo == Vector3():
		for dist in range(1, 30):
			var distancia_actual = UMBRAL_DETECCION_SALTO * dist / 30.0
			var punto_check = centro + dir_norm * distancia_actual
			var altura_terreno = obtener_punto_mas_alto(punto_check.x, punto_check.z, "suelo").y
			
			if altura_terreno - centro.y > MIN_HEIGHT_JUMP:
				posicion_obstaculo = Vector3(punto_check.x, altura_terreno, punto_check.z)
				break
	
	# Búsqueda binaria para el borde
	var ultimo_punto_bajo = centro
	var primer_punto_alto = posicion_obstaculo
	
	for _i in range(10):
		var punto_medio = (ultimo_punto_bajo + primer_punto_alto) / 2
		var altura_medio = obtener_punto_mas_alto(punto_medio.x, punto_medio.z, "suelo").y
		
		if altura_medio - centro.y > MIN_HEIGHT_JUMP * 0.5:
			primer_punto_alto = punto_medio
		else:
			ultimo_punto_bajo = punto_medio
	
	var borde = ultimo_punto_bajo
	borde.y = obtener_punto_mas_alto(primer_punto_alto.x, primer_punto_alto.z, "suelo").y
	
	return borde

# Verificaciones de estado para las patas
func todas_patas_en_posicion():
	for pata in patas.keys():
		if progreso_movimiento[pata] < 0.9:
			return false
	return true

func patas_delanteras_en_objetivo():
	return progreso_movimiento["frontL"] >= 0.9 && progreso_movimiento["frontR"] >= 0.9

func patas_traseras_en_objetivo():
	return progreso_movimiento["backL"] >= 0.9 && progreso_movimiento["backR"] >= 0.9

# Función para suavizar el movimiento
func obtener_progreso_suave(x):
	return 1 / (1 + exp(-8 * (x - 0.5)))
# Añade esta variable a la sección de parámetros exportables
@export var VELOCIDAD_CAIDA = 2.0  # Velocidad a la que las patas caen en bajadas

# Modifica la función mover_patas() para manejar mejor las bajadas
func mover_patas(delta):
	tiempo += delta * VELOCIDAD_MOVIMIENTO * VELOCIDAD_BASE
	
	for nombre in patas.keys():
		if progreso_movimiento[nombre] < 1.0:
			# Seleccionar la velocidad adecuada según el estado actual
			var velocidad_actual = VELOCIDAD_MOVIMIENTO * VELOCIDAD_BASE
			
			if estado_actual == Estado.SALTO_PREP:
				velocidad_actual = VELOCIDAD_PREPARACION_SALTO * VELOCIDAD_BASE
			elif estado_actual == Estado.SALTO:
				velocidad_actual = VELOCIDAD_EJECUCION_SALTO * VELOCIDAD_BASE
			elif estado_actual == Estado.ATERRIZAJE:
				velocidad_actual = VELOCIDAD_ATERRIZAJE * VELOCIDAD_BASE
			
			# Aumentar la velocidad si es una bajada
			var diferencia_altura = objetivos[nombre].y - patas[nombre].y
			if diferencia_altura < -ALTURA_PASO * 0.5:  # Si es una bajada significativa
				velocidad_actual = max(velocidad_actual, VELOCIDAD_CAIDA)
			
			progreso_movimiento[nombre] += velocidad_actual * delta * 5
			progreso_movimiento[nombre] = min(progreso_movimiento[nombre], 1.0)
			
			var factor_altura = 1.0
			if estado_actual == Estado.SALTO && (nombre == "frontL" || nombre == "frontR"):
				factor_altura = 2.0
			elif estado_actual == Estado.ATERRIZAJE && (nombre == "backL" || nombre == "backR"):
				factor_altura = 1.2
			
			patas[nombre] = calcular_posicion_interpolada(
				posiciones_iniciales[nombre], 
				objetivos[nombre], 
				obtener_progreso_suave(progreso_movimiento[nombre]), 
				factor_altura
			)
			
			# Ajuste adicional para bajadas: atraer patas hacia el suelo
			if diferencia_altura < -ALTURA_PASO * 0.5:
				var altura_suelo = obtener_punto_mas_alto(patas[nombre].x, patas[nombre].z, "suelo").y
				if patas[nombre].y > altura_suelo:
					patas[nombre].y = lerp(patas[nombre].y, altura_suelo, delta * VELOCIDAD_CAIDA)
	
	if debe_avanzar() and not en_ciclo_salto:
		var dist = distancia(obtener_centro(), punto_objetivo)
		var factor_velocidad = 2/(0.2*dist)
		var velocidad_rot = VELOCIDAD_ROTACION * VELOCIDAD_BASE * (1.0 + factor_velocidad)
		direccion = rotar_hacia(direccion, punto_objetivo, velocidad_rot)
# Calcula la posición intermedia durante el movimiento
func calcular_posicion_interpolada(pos_inicial, pos_final, progreso, factor_altura = 1.0):
	var interpolacion_xz = pos_inicial.lerp(pos_final, progreso)
	interpolacion_xz.y = calcular_altura_parabola(pos_inicial, pos_final, progreso, factor_altura)
	return interpolacion_xz

# Calcula la altura durante el movimiento usando una parábola
func calcular_altura_parabola(pos_inicial, pos_final, progreso, factor_altura = 1.0):
	var y_inicio = pos_inicial.y
	var y_fin = pos_final.y
	var altura_maxima = max(y_inicio, y_fin) + (ALTURA_PASO * factor_altura)
	
	var a = y_inicio + y_fin - 2 * altura_maxima
	var b = -2 * y_inicio + 2 * altura_maxima
	var c = y_inicio
	
	return a * progreso * progreso + b * progreso + c

# Actualiza las posiciones visuales
func actualizar_representacion_visual():
	if DEBUG:
		for nombre in patas.keys():
			esferas["pata_" + nombre].position = patas[nombre]
	
		for nombre in objetivos.keys():
			esferas["objetivo_" + nombre].position = objetivos[nombre]
		esferas["punto_objetivo"].position = punto_objetivo

# Determina si el cuadrúpedo debe avanzar
func debe_avanzar():
	var dist = distancia(obtener_centro(), punto_objetivo)
	var umbral_descanso = UMBRAL_DISTANCIA * 0.5
	return dist > umbral_descanso
	
# Calcula distancia ignorando componente Y
func distancia(p1, p2):
	var pa = Vector2(p1.x, p1.z)
	var pb = Vector2(p2.x, p2.z)
	return (pa - pb).length()

# Getters para acceder desde otros scripts
func obtener_direccion():
	return direccion
	
func obtener_vel_rot():
	return VELOCIDAD_ROTACION * VELOCIDAD_BASE
	
func obtener_target():
	return punto_objetivo

# Calcula el centro del cuadrúpedo
func obtener_centro():
	var suma = Vector3()
	for pos in patas.values():
		suma += pos
	return suma / patas.size()

# Rota suavemente hacia un objetivo
func rotar_hacia(actual, objetivo, angulo_max):
	var centro = obtener_centro()
	var vector_deseado = (objetivo - centro).normalized()
	var angulo_actual = atan2(actual.z, actual.x)
	var angulo_objetivo = atan2(vector_deseado.z, vector_deseado.x)
	var delta = wrapf(angulo_objetivo - angulo_actual, -PI, PI)
	var nuevo_angulo = angulo_actual + clamp(delta, -angulo_max, angulo_max)
	return Vector3(cos(nuevo_angulo), 0, sin(nuevo_angulo))
	
# Calcula la siguiente posición para una pata delantera
func calcular_siguiente_posicion_delantera(izquierda):
	var dir_norm = direccion.normalized()
	var centro = obtener_centro()
	var factor_paso = max(min(VELOCIDAD_BASE / 1.2, 1.2), 1)
	
	var pos = centro + dir_norm * LONGITUD_PASO * factor_paso
	
	if izquierda:
		pos += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	else:
		pos += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	var altura_terreno = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
	var diferencia_altura = altura_terreno - centro.y
	
	if abs(diferencia_altura) > ALTURA_PASO * 0.5:
		var factor_pendiente = clamp(1.0 - abs(diferencia_altura) / (LONGITUD_PASO * factor_paso * 2), 0.3, 1.0)
		pos = centro + dir_norm * (LONGITUD_PASO * factor_paso * factor_pendiente)
		
		if izquierda:
			pos += Vector3(direccion.z, 0, -direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
		else:
			pos += Vector3(-direccion.z, 0, direccion.x) * (DISTANCIA_ENTRE_PATAS / 2)
	
	pos.y = obtener_punto_mas_alto(pos.x, pos.z, "suelo").y
	return pos
	
func obtener_patas():
	return patas

# Realiza un raycast para detectar la altura del terreno
func obtener_punto_mas_alto(x, z, grupo_nombre):
	var origen = Vector3(x, obtener_centro().y + 30, z)
	var destino = Vector3(x, -1000, z)
	
	var espacio_estado = get_world_3d().direct_space_state
	var parametros_ray = PhysicsRayQueryParameters3D.new()
	parametros_ray.from = origen
	parametros_ray.to = destino
	
	var resultado = espacio_estado.intersect_ray(parametros_ray)
	
	if resultado and resultado.has("collider"):
		var objeto_colision = resultado["collider"]
		if objeto_colision.is_in_group(grupo_nombre):
			return resultado["position"]
	
	return Vector3(x, 0, z)
